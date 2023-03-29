#!/bin/bash
set -euo pipefail

## --- Base --- ##
# Getting path of this script file:
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
_PROJECT_DIR="$(cd "${_SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd)"
cd "${_PROJECT_DIR}" || exit 2

# Loading base script:
source ${_SCRIPT_DIR}/base.sh

exitIfNoDocker

# Loading .env file:
if [ -f ".env" ]; then
	source .env
fi
## --- Base --- ##


## --- Variables --- ##
# Load from envrionment variables:
# BASE_IMAGE
IMG_NAMESCAPE=${IMG_NAMESCAPE:-}
IMG_REPO=${IMG_REPO:-certbot}
IMG_VERSION=${IMG_VERSION:-$(cat version.txt)}
IMG_SUBTAG=${IMG_SUBTAG:-}
IMG_PLATFORM=${IMG_PLATFORM:-$(uname -m)}

IMG_ARGS="${IMG_ARGS:-}"

# Flags:
_IS_CROSS_COMPILE=false
_IS_PUSH_IMAGES=false
_IS_CLEAN_IMAGES=false

# Calculated variables:
_IMG_NAME=${IMG_NAMESCAPE}/${IMG_REPO}
_IMG_FULLNAME=${_IMG_NAME}:${IMG_VERSION}${IMG_SUBTAG}
_IMG_LATEST_FULLNAME=${_IMG_NAME}:latest${IMG_SUBTAG}
## --- Variables --- ##


## --- Functions --- ##
_buildImages()
{
	echoInfo "Building image (${IMG_PLATFORM}): ${_IMG_FULLNAME}"
	docker build \
		${IMG_ARGS} \
		--progress plain \
		--platform ${IMG_PLATFORM} \
		-t ${_IMG_FULLNAME} \
		-t ${_IMG_LATEST_FULLNAME} \
		-t ${_IMG_FULLNAME}-${IMG_PLATFORM#linux/*} \
		-t ${_IMG_LATEST_FULLNAME}-${IMG_PLATFORM#linux/*} \
		. || exit 2
	echoOk "Done."
}

_crossBuildPush()
{
	if [ -z "$(docker buildx ls | grep new_builder)" ]; then
		echoInfo "Creating new builder..."
		docker buildx create --driver docker-container --bootstrap --use --name new_builder || exit 2
		echoOk "Done."
	fi

	echoInfo "Cross building images (linux/amd64, linux/arm64): ${_IMG_FULLNAME}"
	docker buildx build \
		${IMG_ARGS} \
		--progress plain \
		--platform linux/amd64,linux/arm64 \
		--cache-from=type=registry,ref=${_IMG_NAME}:cache-latest \
		--cache-to=type=registry,ref=${_IMG_NAME}:cache-latest,mode=max \
		-t ${_IMG_FULLNAME} \
		-t ${_IMG_LATEST_FULLNAME} \
		--push \
		. || exit 2
	echoOk "Done."

	echoInfo "Removing new builder..."
	docker buildx rm new_builder || exit 2
	echoOk "Done."
}

_removeCaches()
{
	echoInfo "Removing leftover cache images..."
	docker rmi -f $(docker images --filter "dangling=true" -q --no-trunc) 2> /dev/null || true
	echoOk "Done."
}

_pushImages()
{
	echoInfo "Pushing images..."
	docker push ${_IMG_FULLNAME} || exit 2
	docker push ${_IMG_LATEST_FULLNAME} || exit 2
	docker push ${_IMG_FULLNAME}-${IMG_PLATFORM#linux/*} || exit 2
	docker push ${_IMG_LATEST_FULLNAME}-${IMG_PLATFORM#linux/*} || exit 2
	echoOk "Done."
}

_cleanImages()
{
	echoInfo "Cleaning images..."
	docker rmi -f ${_IMG_FULLNAME} || exit 2
	# docker rmi -f ${_IMG_LATEST_FULLNAME} || exit 2
	docker rmi -f ${_IMG_FULLNAME}-${IMG_PLATFORM#linux/*} || exit 2
	docker rmi -f ${_IMG_LATEST_FULLNAME}-${IMG_PLATFORM#linux/*} || exit 2
	echoOk "Done."
}
## --- Functions --- ##


## --- Main --- ##
main()
{
	## --- Menu arguments --- ##
	if [ ! -z "${1:-}" ]; then
		for _input in "${@:-}"; do
			case ${_input} in
				-p=* | --platform=*)
					IMG_PLATFORM="${_input#*=}"
					shift;;
				-u | --push-images)
					_IS_PUSH_IMAGES=true
					shift;;
				-c | --clean-images)
					_IS_CLEAN_IMAGES=true
					shift;;
				-x | --cross-compile)
					_IS_CROSS_COMPILE=true
					shift;;
				-b=* | --base-image=*)
					BASE_IMAGE="${_input#*=}"
					shift;;
				-n=* | --namespace=*)
					IMG_NAMESCAPE="${_input#*=}"
					shift;;
				-r=* | --repo=*)
					IMG_REPO="${_input#*=}"
					shift;;
				-v=* | --version=*)
					IMG_VERSION="${_input#*=}"
					shift;;
				-s=* | --subtag=*)
					IMG_SUBTAG="${_input#*=}"
					shift;;
				*)
					echoError "Failed to parsing input -> ${_input}"
					echoInfo "USAGE: ${0}  -p=*, --platform=* [amd64 | arm64] | -u, --push-images | -c, --clean-images | -x, --cross-compile | -b=*, --base-image=* | -n=*, --namespace=* | -r=*, --repo=* | -v=*, --version=* | -s=*, --subtag=*"
					exit 1;;
			esac
		done
	fi
	## --- Menu arguments --- ##


	if [ -z "${IMG_NAMESCAPE:-}" ]; then
		echoError "Required 'IMG_NAMESCAPE' environment variable or '--namespace=' argument for image namespace!"
		exit 1
	fi

	## --- Init arguments --- ##
	if [ ! -z "${BASE_IMAGE:-}" ]; then
		IMG_ARGS="${IMG_ARGS} --build-arg BASE_IMAGE=${BASE_IMAGE}"
	fi

	_IMG_NAME=${IMG_NAMESCAPE}/${IMG_REPO}
	_IMG_FULLNAME=${_IMG_NAME}:${IMG_VERSION}${IMG_SUBTAG}
	_IMG_LATEST_FULLNAME=${_IMG_NAME}:latest${IMG_SUBTAG}

	if [ "${IMG_PLATFORM}" = "x86_64" ] || [ "${IMG_PLATFORM}" = "amd64" ] || [ "${IMG_PLATFORM}" = "linux/amd64" ]; then
		IMG_PLATFORM="linux/amd64"
	elif [ "${IMG_PLATFORM}" = "aarch64" ] || [ "${IMG_PLATFORM}" = "arm64" ] || [ "${IMG_PLATFORM}" = "linux/arm64" ]; then
		IMG_PLATFORM="linux/arm64"
	else
		echoError "Unsupported platform: ${IMG_PLATFORM}"
		exit 2
	fi
	## --- Init arguments --- ##


	## --- Tasks --- ##
	if [ ${_IS_CROSS_COMPILE} == false ]; then
		_buildImages
	else
		_crossBuildPush
	fi

	_removeCaches

	if [ ${_IS_PUSH_IMAGES} == true ] && [ ${_IS_CROSS_COMPILE} == false ]; then
		_pushImages

		if  [ ${_IS_CLEAN_IMAGES} == true ]; then
			_cleanImages
		fi
	fi
	## --- Tasks --- ##
}

main "${@:-}"
## --- Main --- ##
