#!/bin/bash
set -euo pipefail


echo "[INFO]: Running certbot-permissions.sh..."

UID=${UID:-1000}
GID=${GID:-11000}

chown -Rc "www-data:${GID}" /var/www/.well-known || exit 2
find /var/www/.well-known /var/log/letsencrypt -type d -exec chmod 775 {} + || exit 2
find /var/www/.well-known /var/log/letsencrypt -type f -exec chmod 664 {} + || exit 2
find /var/www/.well-known /var/log/letsencrypt -type d -exec chmod +s {} + || exit 2

chown -Rc "${UID}:${GID}" /etc/letsencrypt /var/lib/letsencrypt /var/log/letsencrypt || exit 2
find /etc/letsencrypt /var/lib/letsencrypt -type d -exec chmod 770 {} + || exit 2
find /etc/letsencrypt /var/lib/letsencrypt -type f -exec chmod 660 {} + || exit 2
find /etc/letsencrypt /var/lib/letsencrypt -type d -exec chmod ug+s {} + || exit 2
echo -e "[OK]: Done.\n"
