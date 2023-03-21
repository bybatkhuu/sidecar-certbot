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
# BUILD_BASE_IMAGE
BUILD_IMG_NAMESCAPE=${BUILD_IMG_NAMESCAPE:-voiceprint}
BUILD_IMG_REPO=${BUILD_IMG_REPO:-certbot}
BUILD_IMG_VERSION=${BUILD_IMG_VERSION:-$(cat version.txt)}
BUILD_IMG_SUBTAG=${BUILD_IMG_SUBTAG:-}
BUILD_IMG_PLATFORM=${BUILD_IMG_PLATFORM:-$(uname -m)}

BUILD_IMG_ARGS="${BUILD_IMG_ARGS:-}"

# Flags:
_IS_CROSS_COMPILE=false
_IS_PUSH_IMAGES=false
_IS_CLEAN_IMAGES=false

# Calculated variables:
_BUILD_IMG_NAME=${BUILD_IMG_NAMESCAPE}/${BUILD_IMG_REPO}
_BUILD_IMG_FULLNAME=${_BUILD_IMG_NAME}:${BUILD_IMG_VERSION}${BUILD_IMG_SUBTAG}
_BUILD_IMG_LATEST_FULLNAME=${_BUILD_IMG_NAME}:latest${BUILD_IMG_SUBTAG}
## --- Variables --- ##


## --- Functions --- ##
_buildImages()
{
	echoInfo "Building image (${BUILD_IMG_PLATFORM}): ${_BUILD_IMG_FULLNAME}"
	docker build \
		${BUILD_IMG_ARGS} \
		--progress plain \
		--platform ${BUILD_IMG_PLATFORM} \
		-t ${_BUILD_IMG_FULLNAME} \
		-t ${_BUILD_IMG_LATEST_FULLNAME} \
		-t ${_BUILD_IMG_FULLNAME}-${BUILD_IMG_PLATFORM#linux/*} \
		-t ${_BUILD_IMG_LATEST_FULLNAME}-${BUILD_IMG_PLATFORM#linux/*} \
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

	echoInfo "Cross building images (linux/amd64, linux/arm64): ${_BUILD_IMG_FULLNAME}"
	docker buildx build \
		${BUILD_IMG_ARGS} \
		--progress plain \
		--platform linux/amd64,linux/arm64 \
		--cache-from=type=registry,ref=${_BUILD_IMG_NAME}:cache-latest \
		--cache-to=type=registry,ref=${_BUILD_IMG_NAME}:cache-latest,mode=max \
		-t ${_BUILD_IMG_FULLNAME} \
		-t ${_BUILD_IMG_LATEST_FULLNAME} \
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
	docker push ${_BUILD_IMG_FULLNAME} || exit 2
	docker push ${_BUILD_IMG_LATEST_FULLNAME} || exit 2
	docker push ${_BUILD_IMG_FULLNAME}-${BUILD_IMG_PLATFORM#linux/*} || exit 2
	docker push ${_BUILD_IMG_LATEST_FULLNAME}-${BUILD_IMG_PLATFORM#linux/*} || exit 2
	echoOk "Done."
}

_cleanImages()
{
	echoInfo "Cleaning images..."
	docker rmi -f ${_BUILD_IMG_FULLNAME} || exit 2
	# docker rmi -f ${_BUILD_IMG_LATEST_FULLNAME} || exit 2
	docker rmi -f ${_BUILD_IMG_FULLNAME}-${BUILD_IMG_PLATFORM#linux/*} || exit 2
	docker rmi -f ${_BUILD_IMG_LATEST_FULLNAME}-${BUILD_IMG_PLATFORM#linux/*} || exit 2
	echoOk "Done."
}
## --- Functions --- ##


## --- Main --- ##
main()
{
	## --- Menu arguments --- ##
	if [ ! -z "${1:-}" ]; then
		for _INPUT in "${@:-}"; do
			case ${_INPUT} in
				-p=* | --platform=*)
					BUILD_IMG_PLATFORM="${_INPUT#*=}"
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
					BUILD_BASE_IMAGE="${_INPUT#*=}"
					shift;;
				-n=* | --namespace=*)
					BUILD_IMG_NAMESCAPE="${_INPUT#*=}"
					shift;;
				-r=* | --repo=*)
					BUILD_IMG_REPO="${_INPUT#*=}"
					shift;;
				-v=* | --version=*)
					BUILD_IMG_VERSION="${_INPUT#*=}"
					shift;;
				-s=* | --subtag=*)
					BUILD_IMG_SUBTAG="${_INPUT#*=}"
					shift;;
				*)
					echoError "Failed to parsing input -> ${_INPUT}"
					echoInfo "USAGE: ${0}  -p=*, --platform=* [amd64 | arm64] | -u, --push-images | -c, --clean-images | -x, --cross-compile | -b=*, --base-image=* | -n=*, --namespace=* | -r=*, --repo=* | -v=*, --version=* | -s=*, --subtag=*"
					exit 1;;
			esac
		done
	fi
	## --- Menu arguments --- ##


	## --- Init arguments --- ##
	if [ ! -z "${BUILD_BASE_IMAGE:-}" ]; then
		BUILD_IMG_ARGS="${BUILD_IMG_ARGS} --build-arg BASE_IMAGE=${BUILD_BASE_IMAGE}"
	fi

	_BUILD_IMG_NAME=${BUILD_IMG_NAMESCAPE}/${BUILD_IMG_REPO}
	_BUILD_IMG_FULLNAME=${_BUILD_IMG_NAME}:${BUILD_IMG_VERSION}${BUILD_IMG_SUBTAG}
	_BUILD_IMG_LATEST_FULLNAME=${_BUILD_IMG_NAME}:latest${BUILD_IMG_SUBTAG}

	if [ "${BUILD_IMG_PLATFORM}" = "x86_64" ] || [ "${BUILD_IMG_PLATFORM}" = "amd64" ] || [ "${BUILD_IMG_PLATFORM}" = "linux/amd64" ]; then
		BUILD_IMG_PLATFORM="linux/amd64"
	elif [ "${BUILD_IMG_PLATFORM}" = "aarch64" ] || [ "${BUILD_IMG_PLATFORM}" = "arm64" ] || [ "${BUILD_IMG_PLATFORM}" = "linux/arm64" ]; then
		BUILD_IMG_PLATFORM="linux/arm64"
	else
		echoError "Unsupported platform: ${BUILD_IMG_PLATFORM}"
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
