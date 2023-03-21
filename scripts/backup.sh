#!/bin/bash
set -euo pipefail

## --- Base --- ##
# Getting path of this script file:
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
_PROJECT_DIR="$(cd "${_SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd)"
cd "${_PROJECT_DIR}" || exit 2

# Loading base script:
source ${_SCRIPT_DIR}/base.sh

# Loading .env file:
if [ -f ".env" ]; then
	source .env
fi
## --- Base --- ##


## --- Variables --- ##
# Load from envrionment variables:
BACKUPS_DIR="${BACKUPS_DIR:-./volumes/storage/certbot/backups}"
## --- Variables --- ##


## --- Main --- ##
main()
{
	echoInfo "Creating backups of 'ssl' and 'logs'..."
	if [ ! -d "${BACKUPS_DIR}" ]; then
		mkdir -pv ${BACKUPS_DIR} || exit 2
	fi

	tar -czpvf ${BACKUPS_DIR}/ssl.$(date -u '+%y%m%d_%H%M%S').tar.gz -C ./volumes/storage/certbot ./ssl || exit 2
	tar -czpvf ${BACKUPS_DIR}/logs.$(date -u '+%y%m%d_%H%M%S').tar.gz -C ./volumes/storage/certbot ./logs || exit 2
	echoOk "Done."
}

main "${@:-}"
## --- Main --- ##
