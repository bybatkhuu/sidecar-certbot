#!/bin/bash
set -euo pipefail


## --- Base --- ##
# Getting path of this script file:
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
_PROJECT_DIR="$(cd "${_SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd)"
cd "${_PROJECT_DIR}" || exit 2

# Loading base script:
source ${_SCRIPT_DIR}/base.sh

exitIfNoGit

# Loading .env file:
if [ -f ".env" ]; then
	source .env
fi
## --- Base --- ##


## --- Variables --- ##
# Load from envrionment variables:
VERSION_FILENAME=${VERSION_FILENAME:-version.txt}
## --- Variables --- ##


## --- Main --- ##
main()
{
	echoInfo "Checking version..."
	_OLD_VERSION=""
	if [ ! -z "${VERSION_FILENAME}" ] && [ -f "${VERSION_FILENAME}" ]; then

		echoInfo "Found version file: '${VERSION_FILENAME}'"
		_OLD_VERSION=$(cat ${VERSION_FILENAME}) || exit 2

	# Check if there are any tags matching the pattern "v*.*.*-*":
	elif [ ! -z "$(git tag -l 'v*.*.*-*')" ]; then

		echoInfo "Found version tag."
		# Get the most recent tag which matches the pattern "v*.*.*-*":
		_TAG=$(git describe --tags --match "v*.*.*-*" --abbrev=0) || exit 2

		# Strip the leading "v" character from the tag name (if present)
		_OLD_VERSION=${_TAG#v}
	else
		echoWarn "Not found any version tags or file, using initial version."
		_OLD_VERSION="0.0.0-$(date -u '+%y%m%d')"
	fi
	echoOk "Old version: '${_OLD_VERSION}'"


	# Split the version string into its components:
	_MAJOR=$(echo $_OLD_VERSION | cut -d. -f1)
	_MINOR=$(echo $_OLD_VERSION | cut -d. -f2)
	_PATCH=$(echo $_OLD_VERSION | cut -d. -f3 | cut -d- -f1)


	# Checking bump type is empty:
	_BUMP_TYPE=${1:-}
	if [ -z "${_BUMP_TYPE:-}" ]; then
		# Default to a patch bump:
		# _BUMP_TYPE="patch"

		echoError "Bump type is empty!"
		exit 1
	fi

	# Determine the new version based on the type of bump:
	if [ "${_BUMP_TYPE}" == "major" ]; then
		NEW_VERSION="$((_MAJOR + 1)).0.0-$(date -u '+%y%m%d')"
	elif [ "${_BUMP_TYPE}" == "minor" ]; then
		NEW_VERSION="${_MAJOR}.$((_MINOR + 1)).0-$(date -u '+%y%m%d')"
	elif [ "${_BUMP_TYPE}" == "patch" ]; then
		NEW_VERSION="${_MAJOR}.${_MINOR}.$((_PATCH + 1))-$(date -u '+%y%m%d')"
	else
		echoError "Bump type '${_BUMP_TYPE}' is invalid, should be: 'major', 'minor', 'patch'!"
		exit 1
	fi

	if git rev-parse "v${NEW_VERSION}" >/dev/null 2>&1; then
		echoError "'v${NEW_VERSION}' tag is already exists."
		exit 1
	else
		echoInfo "Bumping version to '${NEW_VERSION}'..."
		if [ ! -z "${VERSION_FILENAME}" ] && [ -f "${VERSION_FILENAME}" ]; then
			# Update the version file with the new version:
			echo ${NEW_VERSION} > ${VERSION_FILENAME} || exit 2

			# Commit the updated version file:
			git add ${VERSION_FILENAME} || exit 2
			git commit -m ":bookmark: Bump version to ${NEW_VERSION}." || exit 2
			git push || exit 2
		fi

		git tag "v${NEW_VERSION}" || exit 2
		git push origin "v${NEW_VERSION}" || exit 2

		echoOk "New version: '${NEW_VERSION}'"
	fi
}

main "${@:-}"
## --- Main --- ##
