#!/bin/bash
set -euo pipefail


chown -Rc www-data:${GROUP} /var/www/.well-known || exit 2
find /var/www/.well-known /var/log/letsencrypt -type d -exec chmod -c 775 {} + || exit 2
find /var/www/.well-known /var/log/letsencrypt -type f -exec chmod -c 664 {} + || exit 2
find /var/www/.well-known /var/log/letsencrypt -type d -exec chmod -c +s {} + || exit 2

chown -Rc 1000:${GROUP} /etc/letsencrypt /var/lib/letsencrypt /var/log/letsencrypt || exit 2
find /etc/letsencrypt /var/lib/letsencrypt -type d -exec chmod -c 770 {} + || exit 2
find /etc/letsencrypt /var/lib/letsencrypt -type f -exec chmod -c 660 {} + || exit 2
find /etc/letsencrypt /var/lib/letsencrypt -type d -exec chmod -c ug+s {} + || exit 2
