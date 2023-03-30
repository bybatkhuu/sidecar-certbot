# Sidecar Certbot

This is a certbot docker image that can be used as a sidecar or standalone container to automatically obtain and renew TLS/SSL certificates from Let's Encrypt.

## Features

- Let's Encrypt - <https://letsencrypt.org>
- Certbot - <https://certbot.eff.org>
- TLS/SSL certificates
- Automatic certificate obtain
- Automatic certificate renewal (checks every week)
- DNS challenges **[recommended]**:
    - Cloudflare DNS
    - DigitalOcean DNS
    - GoDaddy DNS
    - AWS Route53
    - Google Cloud DNS
- HTTP challenges:
    - Standalone
    - Webroot
- Sidecar or standalone mode
- Multiple domains per certificate
- Subdomains:
    - Multiple subdomains per domain/certificate
    - Wildcard subdomains (only DNS challenges)
- Docker and docker-compose

---

## Getting started

### 1. Prerequisites

- **Server** with **public IP address**
- Buy or register **domain name**
- **[RECOMMENDED]** DNS provider **API token/credentials** (required for **DNS challenges** and **wildcard subdomains**):
    - Cloudflare - <https://dash.cloudflare.com/profile/api-tokens>
    - DigitalOcean - <https://cloud.digitalocean.com/account/api/tokens>
    - GoDaddy - <https://developer.godaddy.com/keys>
    - AWS Route53 - <https://docs.aws.amazon.com/general/latest/gr/aws-sec-cred-types.html#access-keys-and-secret-access-keys>
    - Google Cloud DNS - <https://cloud.google.com/docs/authentication/getting-started>
- Install **docker** and **docker-compose** in **server** - <https://docs.docker.com/engine/install>

For **development**:

- Install **git** - <https://git-scm.com/downloads>
- Setup an **SSH key** - <https://docs.github.com/en/github/authenticating-to-github/connecting-to-github-with-ssh>

### 2. Download or clone the repository

**2.1.** Prepare projects directory (if not exists) in your **server** with **public IP address**:

```sh
# Create projects directory:
mkdir -pv ~/workspaces/projects

# Enter into projects directory:
cd ~/workspaces/projects

# Set to downloaded version:
export _VERSION=[VERSION]
# For example:
export _VERSION=1.0.0
```

**2.2.** Follow one of the below options **[A]** or **[B]**:

**A.** Download source code from releases page:

- Releases - <https://github.com/[REPO_OWNER]/sidecar.certbot/releases>

```sh
# Move downloaded archive file to current projects directory:
mv -v ~/Downloads/sidecar.certbot-${_VERSION}.zip .

# Extract downloaded archive file:
unzip sidecar.certbot-${_VERSION}.zip

# Remove downloaded archive file:
rm -v sidecar.certbot-${_VERSION}.zip

# Rename extracted directory into project name:
mv -v sidecar.certbot-${_VERSION} sidecar.certbot && cd sidecar.certbot
```

**B.** Or clone the repository (git + ssh key):

```sh
git clone git@github.com:${_REPO_OWNER}/sidecar.certbot.git && cd sidecar.certbot
```

### 3. Configure environment

**TIP:** Skip this step, if you've already configured environment.

**3.1.** Configure **`.env`** file:

**IMPORTANT:** Please, check **[environment variables](#environment-variables)**!

```sh
# Copy .env.example file into .env file:
cp -v .env.example .env

# Edit environment variables to fit in your environment:
nano .env
```

**3.2.** Configure **`docker-compose.override.yml`** file:

**IMPORTANT:** Please, check **[sidecar.certbot arguments](#arguments)**!

```sh
# Set environment:
export _ENV=[ENV]
# For example for development environment:
export _ENV=dev

# Copy docker-compose.override.[ENV].yml into docker-compose.override.yml file:
cp -v ./templates/docker-compose/docker-compose.override.${_ENV}.yml docker-compose.override.yml

# Edit docker-compose.override.yml file to fit in your environment:
nano docker-compose.override.yml
```

**3.3.** Validate docker compose configuration:

**NOTICE:** If you get an error or warning, check your configuration files (**`.env`** or **`docker-compose.override.yml`**).

```sh
./certbot-compose.sh validate

# Or:
docker compose config
```

### 4. Run docker compose

```sh
./certbot-compose.sh start -l

# Or:
docker compose up -d && docker compose logs -f --tail 100
```

### 5. Check certificates

```sh
./certbot-compose.sh certs

# Or check certificates in container:
docker compose exec certbot certbot certificates

# Or check certificates in host:
ls -alhF ./volumes/storage/certbot/ssl

# Or check certificates in host with tree:
tree -alFC --dirsfirst -L 5 ./volumes/storage/certbot/ssl
```

### 6. Stop docker compose

```sh
./certbot-compose.sh stop

# Or:
docker compose down
```

:thumbsup: :sparkles:

---

## Environment Variables

You can use the following environment variables to configure:

[**`.env.example`**](.env.example)

```sh
## Docker image namespace:
IMG_NAMESCAPE=username

## Email address for Let's Encrypt domain registration:
CERTBOT_EMAIL=user@email.com

## Domain names to obtain certificates:
CERTBOT_DOMAINS="example.com,www.example.com"

## DNS propagation timeout (in seconds):
CERTBOT_DNS_TIMEOUT=30
```

## Arguments

You can use the following arguments to configure:

```txt
-s=, --server=[staging | production]
    Let's Encrypt server. Default: staging.
-n=, --new=[standalone | webroot]
    Obtain option for new certificates. Default: standalone.
-r=, --renew=[webroot | standalone]
    Renew option for existing certificates. Default: webroot.
-d=, --dns=[cloudflare | route53 | google | godaddy | digitalocean]
    Use DNS challenge instead of HTTP challenge.
-D, --disable-renew
    Disable automatic renewal of certificates.
-b, --bash, bash, /bin/bash
    Run only bash shell.
```

For example as in **`docker-compose.override.yml`** file:

```yml
    command: ["--server=production"]
    command: ["--server=production", "--renew=standalone"]
    command: ["--new=webroot", "--disable-renew"]
    command: ["--server=production", "--dns=cloudflare"]
    command: ["--dns=digitalocean"]
    command: ["--dns=route53"]
    command: ["--dns=google"]
    command: ["--dns=godaddy"]
    command: ["/bin/bash"]
```

## Documentation

- [Build docker image](docs/docker-build.md)
- [Certbot examples](docs/certbot-examples.md)

## Roadmap

- Add GitHub action for auto-update CHANGELOG.md file.
- Add more DNS providers.
- Add more documentation.

---

## References

- Certbot - <https://certbot.eff.org>
- Certbot documentation - <https://eff-certbot.readthedocs.io/en/stable>
- Let's Encrypt - <https://letsencrypt.org>
- Let's Encrypt documentation - <https://letsencrypt.org/docs>
