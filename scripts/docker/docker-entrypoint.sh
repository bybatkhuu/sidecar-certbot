#!/bin/bash
set -euo pipefail


echo "[INFO]: Running 'certbot' docker-entrypoint.sh..."

# CERTBOT_EMAIL=${CERTBOT_EMAIL:-user@example.com}
# CERTBOT_DOMAINS=${CERTBOT_DOMAINS:-example.com,*.example.com}
CERTBOT_DNS_TIMEOUT=${CERTBOT_DNS_TIMEOUT:-30}


main()
{
	if [ -z "${CERTBOT_EMAIL}" ]; then
		echo "[ERROR]: 'CERTBOT_EMAIL' environment variable is not set!"
		exit 1
	fi

	if [ -z "${CERTBOT_DOMAINS}" ]; then
		echo "[ERROR]: 'CERTBOT_DOMAINS' environment variable is not set!"
		exit 1
	fi

	if [ ! -d "/var/www/.well-known/acme-challenge" ]; then
		mkdir -pv /var/www/.well-known/acme-challenge || exit 2
	fi


	/usr/local/bin/certbot-permissions.sh

	if [ -d "/root/.secrets/certbot" ]; then
		chown -Rc "1000:${GROUP}" /root/.secrets/certbot || exit 2
		find /root/.secrets/certbot -type d -exec chmod -c 770 {} + || exit 2
		find /root/.secrets/certbot -type f -exec chmod -c 660 {} + || exit 2
		find /root/.secrets/certbot -type d -exec chmod -c ug+s {} + || exit 2
	fi

	if [ -d "/root/.aws" ]; then
		chown -Rc "1000:${GROUP}" /root/.aws || exit 2
		find /root/.aws -type d -exec chmod -c 770 {} + || exit 2
		find /root/.aws -type f -exec chmod -c 660 {} + || exit 2
		find /root/.aws -type d -exec chmod -c ug+s {} + || exit 2
	fi


	## Default values:
	_certbot_new="--standalone"
	_certbot_renew="--webroot -w /var/www"
	_certbot_staging="--staging"
	_disable_renew=false

	_pip_dns=""

	## Parsing input:
	for _input in "${@:-}"; do
		case ${_input} in
			"")
				shift;;

			-s=* | --server=*)
				_server="${_input#*=}"
				if [ "${_server}" = "production" ]; then
					_certbot_staging=""
				elif [ "${_server}" = "staging" ]; then
					_certbot_staging="--staging"
				else
					echo "[ERROR]: Invalid server '${_server}'!"
					exit 1
				fi
				shift;;

			-n=* | --new=*)
				_new="${_input#*=}"
				if [ "${_new}" = "standalone" ]; then
					_certbot_new="--standalone"
				elif [ "${_new}" = "webroot" ]; then
					_certbot_new="--webroot -w /var/www"
				fi
				shift;;

			-r=* | --renew=*)
				_renew="${_input#*=}"
				if [ "${_renew}" = "standalone" ]; then
					_certbot_renew="--standalone"
				elif [ "${_renew}" = "webroot" ]; then
					_certbot_renew="--webroot -w /var/www"
				fi
				shift;;

			-d=* | --dns=*)
				_dns="${_input#*=}"
				if [ "${_dns}" = "route53" ]; then
					if [ -z "${AWS_ACCESS_KEY_ID}" ] || [ -z "${AWS_SECRET_ACCESS_KEY}" ]; then
						if [ ! -f "/root/.aws/config" ]; then
							echo "[ERROR]: '/root/.aws/config' file is not found!"
							exit 1
						fi
					fi
					_certbot_new="--dns-${_dns} --dns-${_dns}-propagation-seconds ${CERTBOT_DNS_TIMEOUT}"
					_certbot_renew="${_certbot_new}"

				elif [ "${_dns}" = "godaddy" ]; then
					if [ ! -f "/root/.secrets/certbot/${_dns}.ini" ]; then
						echo "[ERROR]: '/root/.secrets/certbot/${_dns}.ini' file is not found!"
						exit 1
					fi
					_certbot_new="--authenticator dns-${_dns} --dns-${_dns}-credentials /root/.secrets/certbot/${_dns}.ini --dns-${_dns}-propagation-seconds ${CERTBOT_DNS_TIMEOUT}"
					_certbot_renew="${_certbot_new}"

				elif [ "${_dns}" = "google" ]; then
					if [ ! -f "/root/.secrets/certbot/${_dns}.json" ]; then
						echo "[ERROR]: '/root/.secrets/certbot/${_dns}.json' file is not found!"
						exit 1
					fi
					_certbot_new="--dns-${_dns} --dns-${_dns}-credentials /root/.secrets/certbot/${_dns}.json --dns-${_dns}-propagation-seconds ${CERTBOT_DNS_TIMEOUT}"
					_certbot_renew="${_certbot_new}"

				elif [ "${_dns}" = "cloudflare" ] || [ "${_dns}" = "digitalocean" ]; then
					if [ ! -f "/root/.secrets/certbot/${_dns}.ini" ]; then
						echo "[ERROR]: '/root/.secrets/certbot/${_dns}.ini' file is not found!"
						exit 1
					fi
					_certbot_new="--dns-${_dns} --dns-${_dns}-credentials /root/.secrets/certbot/${_dns}.ini --dns-${_dns}-propagation-seconds ${CERTBOT_DNS_TIMEOUT}"
					_certbot_renew="${_certbot_new}"

				else
					echo "[ERROR]: Unsupported DNS plugin -> ${_dns}!"
					exit 1
				fi

				_pip_dns="certbot-dns-${_dns}"
				if [ "${_dns}" != "cloudflare" ]; then
					echo "[INFO]: Installing certbot DNS plugin -> ${_dns}..."
					pip install --timeout 60 --no-cache-dir --root-user-action ignore "${_pip_dns}" || exit 2
					pip cache purge || exit 2
					echo -e "[OK]: Done.\n"
				fi
				shift;;

			-D | --disable-renew)
				_disable_renew=true
				shift;;

			-b | --bash | bash | /bin/bash)
				shift
				if [ -z "${*:-}" ]; then
					echo "[INFO]: Starting bash..."
					/bin/bash
				else
					echo "[INFO]: Executing command -> ${*}"
					exec /bin/bash -c "${@}" || exit 2
				fi
				exit 0;;
			*)
				echo "[ERROR]: Failed to parse input -> ${*}!"
				echo "[INFO]: USAGE: ${0} -s=*, --server=* [staging | production] | -n=*, --new=* [standalone | webroot] | -r=*, --renew=* [standalone | webroot] | -d=*, --dns=* [cloudflare | digitalocean | google | route53 | godaddy] | -D, --disable-renew | -b, --bash, bash, /bin/bash"
				exit 1;;
		esac
	done

	echo "[INFO]: Upgrading certbot..."
	pip install --timeout 60 --no-cache-dir --root-user-action ignore --upgrade certbot || exit 2
	pip cache purge || exit 2
	echo -e "[OK]: Done.\n"

	echo "[INFO]: Obtaining certificates..."
	echo "[INFO]: Certbot email -> '${CERTBOT_EMAIL}'"
	echo "[INFO]: Certbot server -> '${_certbot_staging:-production}'"
	# shellcheck disable=SC2086
	certbot certonly -n --agree-tos --keep --expand --max-log-backups 10 --deploy-hook "/usr/local/bin/certbot-deploy-hook.sh" ${_certbot_staging} ${_certbot_new} -m "${CERTBOT_EMAIL}" -d "${CERTBOT_DOMAINS}" || exit 2
	echo -e "[OK]: Done.\n"

	/usr/local/bin/certbot-permissions.sh

	if [ ${_disable_renew} != true ]; then
		echo "[INFO]: Adding cron jobs..."
		echo -e "\n0 1 1 * * root /usr/local/bin/pip install --timeout 60 --no-cache-dir --root-user-action ignore --upgrade certbot ${_pip_dns} >> /var/log/cron.pip.log 2>&1" >> /etc/crontab || exit 2
		echo "0 2 * * 1 root /usr/local/bin/python -c 'import random; import time; time.sleep(random.random() * 3600)' && certbot renew -n --keep --max-log-backups 10 --deploy-hook '/usr/local/bin/certbot-deploy-hook.sh' ${_certbot_staging} ${_certbot_renew} >> /var/log/cron.certbot.log 2>&1 && /usr/local/bin/certbot-permissions.sh" >> /etc/crontab || exit 2
		echo -e "[OK]: Done.\n"

		echo "[INFO]: Starting cron..."
		exec tini -- cron -f || exit 2

		# exec /bin/bash
	fi

	exit 0
}

main "${@:-}"
