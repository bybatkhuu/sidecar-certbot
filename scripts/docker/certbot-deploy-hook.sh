#!/bin/bash
set -euo pipefail


echo "INFO: Running certbot-deploy-hook.sh..."
if ls /etc/letsencrypt/live/deploy_hook.*.pem >/dev/null 2>&1; then
	rm -rfv /etc/letsencrypt/live/deploy_hook.*.pem || exit 2
fi

if [ ! -d "/etc/letsencrypt/live" ]; then
	mkdir -pv "/etc/letsencrypt/live" || exit 2
fi

if [ ! -d "/var/log/letsencrypt" ]; then
	mkdir -pv "/var/log/letsencrypt" || exit 2
fi

echo "deployed_dtime: $(date '+%Y-%m-%dT%H:%M:%S%z')" > "/etc/letsencrypt/live/deploy_hook.$(date -u '+%y%m%d_%H%M%S').pem" || exit 2
echo "deployed_dtime: $(date '+%Y-%m-%dT%H:%M:%S%z')" >> "/var/log/letsencrypt/deploy_hook.log" || exit 2
echo -e "SUCCESS: Done.\n"
