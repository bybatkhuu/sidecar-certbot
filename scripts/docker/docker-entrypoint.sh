#!/bin/bash
set -euo pipefail


echo -e "INFO: Running certbot docker-entrypoint.sh...\n"

# CERTBOT_EMAIL=${CERTBOT_EMAIL:-user@example.com}
# CERTBOT_DOMAINS=${CERTBOT_DOMAINS:-example.com,*.example.com}


main()
{
	if [ -z "${CERTBOT_EMAIL}" ]; then
		echo "ERROR: 'CERTBOT_EMAIL' environment variable is not set."
		exit 1
	fi

	if [ -z "${CERTBOT_DOMAINS}" ]; then
		echo "ERROR: 'CERTBOT_DOMAINS' environment variable is not set."
		exit 1
	fi

	if [ ! -d "/var/www/.well-known/acme-challenge" ]; then
		mkdir -vp /var/www/.well-known/acme-challenge || exit 2
	fi

	echo -e "INFO: Setting permissions..."
	/usr/local/bin/certbot-permissions.sh

	if [ -d "/root/.secrets/certbot" ]; then
		chown -R 1000:${GROUP} /root/.secrets/certbot || exit 2
		find /root/.secrets/certbot -type d -exec chmod 770 {} + || exit 2
		find /root/.secrets/certbot -type f -exec chmod 660 {} + || exit 2
		find /root/.secrets/certbot -type d -exec chmod ug+s {} + || exit 2
	fi

	if [ -d "/root/.aws" ]; then
		chown -R 1000:${GROUP} /root/.aws || exit 2
		find /root/.aws -type d -exec chmod 770 {} + || exit 2
		find /root/.aws -type f -exec chmod 660 {} + || exit 2
		find /root/.aws -type d -exec chmod ug+s {} + || exit 2
	fi
	echo -e "SUCCESS: Done.\n"

	## Default values:
	_CERTBOT_NEW="--standalone"
	_CERTBOT_RENEW="--webroot -w /var/www"
	_CERTBOT_STAGING="--staging"
	_DISABLE_RENEW=false

	_DNS_PARAM=""
	_PIP_DNS=""

	## Parsing input:
	for _INPUT in "${@:-}"; do
		case ${_INPUT} in
			"")
				shift;;

			-s=* | --server=*)
				_SERVER="${_INPUT#*=}"
				if [ "${_SERVER}" = "production" ]; then
					_CERTBOT_STAGING=""
				elif [ "${_SERVER}" = "staging" ]; then
					_CERTBOT_STAGING="--staging"
				else
					echo "ERROR: Invalid server '${_SERVER}'."
					exit 1
				fi
				shift;;

			-n=* | --new=*)
				_NEW="${_INPUT#*=}"
				if [ "${_NEW}" = "standalone" ]; then
					_CERTBOT_NEW="--standalone"
				elif [ "${_NEW}" = "webroot" ]; then
					_CERTBOT_NEW="--webroot -w /var/www"
				fi
				shift;;

			-r=* | --renew=*)
				_RENEW="${_INPUT#*=}"
				if [ "${_RENEW}" = "standalone" ]; then
					_CERTBOT_RENEW="--standalone"
				elif [ "${_RENEW}" = "webroot" ]; then
					_CERTBOT_RENEW="--webroot -w /var/www"
				fi
				shift;;

			-d=* | --dns=*)
				_DNS="${_INPUT#*=}"
				if [ "${_DNS}" = "route53" ]; then
					if [ -z "${AWS_ACCESS_KEY_ID}" ] || [ -z "${AWS_SECRET_ACCESS_KEY}" ]; then
						if [ ! -f "/root/.aws/config" ]; then
							echo "ERROR: '/root/.aws/config' file is not found."
							exit 1
						fi
					fi
					_CERTBOT_NEW="--dns-route53"
					_CERTBOT_RENEW="--dns-route53"

				elif [ "${_DNS}" = "godaddy" ]; then
					if [ ! -f "/root/.secrets/certbot/${_DNS}.ini" ]; then
						echo "ERROR: '/root/.secrets/certbot/${_DNS}.ini' file is not found."
						exit 1
					fi
					_CERTBOT_NEW="--authenticator dns-${_DNS} --dns-${_DNS}-credentials /root/.secrets/certbot/${_DNS}.ini"
					_CERTBOT_RENEW="--authenticator dns-${_DNS} --dns-${_DNS}-credentials /root/.secrets/certbot/${_DNS}.ini"

				elif [ "${_DNS}" = "google" ]; then
					if [ ! -f "/root/.secrets/certbot/${_DNS}.json" ]; then
						echo "ERROR: '/root/.secrets/certbot/${_DNS}.json' file is not found."
						exit 1
					fi
					_CERTBOT_NEW="--dns-${_DNS} --dns-${_DNS}-credentials /root/.secrets/certbot/${_DNS}.json"
					_CERTBOT_RENEW="--dns-${_DNS} --dns-${_DNS}-credentials /root/.secrets/certbot/${_DNS}.json"

				elif [ "${_DNS}" = "cloudflare" ] || [ "${_DNS}" = "digitalocean" ]; then
					if [ ! -f "/root/.secrets/certbot/${_DNS}.ini" ]; then
						echo "ERROR: '/root/.secrets/certbot/${_DNS}.ini' file is not found."
						exit 1
					fi
					_CERTBOT_NEW="--dns-${_DNS} --dns-${_DNS}-credentials /root/.secrets/certbot/${_DNS}.ini"
					_CERTBOT_RENEW="--dns-${_DNS} --dns-${_DNS}-credentials /root/.secrets/certbot/${_DNS}.ini"

				else
					echo "ERROR: Unsupported DNS plugin -> ${_DNS}"
					exit 1
				fi

				_PIP_DNS="certbot-dns-${_DNS}"
				if [ "${_DNS}" != "cloudflare" ]; then
					echo "INFO: Installing certbot DNS plugin -> ${_DNS}..."
					pip install --timeout 60 --no-cache-dir ${_PIP_DNS} || exit 2
					pip cache purge || exit 2
					echo -e "SUCCESS: Done.\n"
				fi
				shift;;

			-D | --disable-renew)
				_DISABLE_RENEW=true
				shift;;

			-b | --bash | bash | /bin/bash)
				shift
				if [ -z "${@:-}" ]; then
					echo "INFO: Starting bash..."
					/bin/bash
				else
					echo "INFO: Executing command -> ${@}"
					/bin/bash -c "${@}" || exit 2
				fi
				exit 0;;
			*)
				echo "ERROR: Failed to parsing input -> ${@}"
				echo "USAGE: ${0} -s=*, --server=* [staging | production] | -n=*, --new=* [standalone | webroot] | -r=*, --renew=* [standalone | webroot] | -d=*, --dns=* [cloudflare | digitalocean | google | route53 | godaddy] | -D, --disable-renew | -b, --bash, bash, /bin/bash"
				exit 1;;
		esac
	done

	echo "INFO: Obtaining certificates..."
	certbot certonly -n --agree-tos --keep --max-log-backups 50 ${_CERTBOT_STAGING} ${_CERTBOT_NEW} -m ${CERTBOT_EMAIL} -d ${CERTBOT_DOMAINS} || exit 2
	echo -e "SUCCESS: Done.\n"

	/usr/local/bin/certbot-permissions.sh

	if [ ${_DISABLE_RENEW} != true ]; then
		echo "INFO: Adding cron jobs..."
		echo -e "\n0 1 1 * * root /usr/local/bin/pip install --timeout 60 --no-cache-dir --upgrade certbot ${_PIP_DNS} >> /var/log/cron.pip.log 2>&1" >> /etc/crontab || exit 2
		echo "0 2 * * 1 root /usr/local/bin/python -c 'import random; import time; time.sleep(random.random() * 3600)' && certbot renew -n --keep --max-log-backups 50 ${_CERTBOT_STAGING} ${_CERTBOT_RENEW} >> /var/log/cron.certbot.log 2>&1 && /usr/local/bin/certbot-permissions.sh" >> /etc/crontab || exit 2

		cron || exit 2
		echo -e "SUCCESS: Done.\n"

		/bin/bash
	fi

	exit 0
}

main "${@:-}"
