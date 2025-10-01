# Sidecar Certbot

[![MIT License](https://img.shields.io/badge/License-MIT-green.svg)](https://choosealicense.com/licenses/mit/)
[![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/bybatkhuu/sidecar-certbot/2.build-publish.yml?logo=GitHub)](https://github.com/bybatkhuu/sidecar-certbot/actions/workflows/2.build-publish.yml)
[![GitHub release (latest SemVer)](https://img.shields.io/github/v/release/bybatkhuu/sidecar-certbot?logo=GitHub)](https://github.com/bybatkhuu/sidecar-certbot/releases)
[![Docker Image Version](https://img.shields.io/docker/v/bybatkhuu/certbot?sort=semver&logo=docker)](https://hub.docker.com/r/bybatkhuu/certbot/tags)
[![Docker Image Size](https://img.shields.io/docker/image-size/bybatkhuu/certbot?sort=semver&logo=docker)](https://hub.docker.com/r/bybatkhuu/certbot/tags)

This is a certbot docker image that can be used as a sidecar or standalone container to automatically obtain and renew TLS/SSL certificates from Let's Encrypt.

## ✨ Features

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

## 🐤 Getting Started

### 1. 🚧 Prerequisites

- Prepare **server/PC** with **public IP address**
- Buy or register **domain name**
- **[RECOMMENDED]** DNS provider **API token/credentials** (required for **DNS challenges** and **wildcard subdomains**):
    - Cloudflare:
        - API tokens - <https://dash.cloudflare.com/profile/api-tokens>
        - certbot-dns-cloudflare - <https://certbot-dns-cloudflare.readthedocs.io/en/stable>
    - DigitalOcean:
        - API tokens - <https://cloud.digitalocean.com/account/api/tokens>
        - certbot-dns-digitalocean - <https://certbot-dns-digitalocean.readthedocs.io/en/stable>
    - GoDaddy:
        - API keys - <https://developer.godaddy.com/keys>
        - certbot-dns-godaddy - <https://github.com/miigotu/certbot-dns-godaddy>
    - AWS Route53:
        - AWS access keys - <https://docs.aws.amazon.com/general/latest/gr/aws-sec-cred-types.html>
        - certbot-dns-route53 - <https://certbot-dns-route53.readthedocs.io/en/stable>
    - Google Cloud DNS:
        - GCP credentials/service accounts - <https://cloud.google.com/iam/docs/service-accounts-create>
        - certbot-dns-google - <https://certbot-dns-google.readthedocs.io/en/stable>
- Install [**docker** and **docker compose**](https://docs.docker.com/engine/install) in **server**
    - Docker image: [**bybatkhuu/certbot**](https://hub.docker.com/r/bybatkhuu/certbot)

For **DEVELOPMENT**:

- Install [**git**](https://git-scm.com/downloads)
- Setup an [**SSH key**](https://docs.github.com/en/github/authenticating-to-github/connecting-to-github-with-ssh)

### 2. 📥 Download or clone the repository

**2.1.** Prepare projects directory (if not exists) in your **server** with **public IP address**:

```sh
# Create projects directory:
mkdir -pv ~/workspaces/projects

# Enter into projects directory:
cd ~/workspaces/projects
```

**2.2.** Follow one of the below options **[A]**, **[B]** or **[C]**:

**A.** Clone the repository:

```sh
git clone https://github.com/bybatkhuu/sidecar-certbot.git && \
    cd sidecar-certbot
```

**OPTION B.** Clone the repository (for **DEVELOPMENT**: git + ssh key):

```sh
git clone git@github.com:bybatkhuu/sidecar-certbot.git && \
    cd sidecar-certbot
```

**OPTION C.** Download source code from **[releases](https://github.com/bybatkhuu/sidecar-certbot/releases)** page.

### 3. 🛠 Configure the environment

[TIP] Skip this step, if you've already configured environment!

#### 3.1. 🌎 Configure **`.env`** (environment variables) file

**[IMPORTANT]** Please, check **[environment variables](#-environment-variables)** section for more details.

```sh
# Copy .env.example file into .env file:
cp -v .env.example .env

# Edit environment variables to fit in your environment:
nano .env
```

#### 3.2. 🎺 Configure **`compose.override.yml`** file

[TIP] Skip this step, if you want run with default configuration!

You can use below template **`compose.override.yml`** files for different environments:

- **DEVELOPMENT**: [**`compose.override.dev.yml`**](./templates/compose/compose.override.dev.yml)
- **PRODUCTION/STAGING**: [**`compose.override.prod.yml`**](./templates/compose/compose.override.prod.yml)

```sh
# Copy 'compose.override.[ENV].yml' file to 'compose.override.yml' file:
cp -v ./templates/compose/compose.override.[ENV].yml ./compose.override.yml
# For example, DEVELOPMENT environment:
cp -v ./templates/compose/compose.override.dev.yml ./compose.override.yml
# For example, STAGING or PRODUCTION environment:
cp -v ./templates/compose/compose.override.prod.yml ./compose.override.yml

# Edit 'compose.override.yml' file to fit in your environment:
nano ./compose.override.yml
```

#### 3.3. ✅ Check docker compose configuration is valid

**[WARNING]** If you get an error or warning, check your configuration files (**`.env`** or **`compose.override.yml`**).

```sh
./compose.sh validate
# Or:
docker compose config
```

### 4. 🚀 Start docker compose

**[CAUTION]**:

- If ports are conflicting, you should change ports from [**3. step**](#3--configure-the-environment).
- If container names are conflicting, you should change project directory name (from **`sidecar-certbot`** to something else, e.g: `prod.sidecar-certbot`) from [**2.2. step**](#2--download-or-clone-the-repository).

```sh
./compose.sh start -l
# Or:
docker compose up -d --remove-orphans --force-recreate && \
    docker compose logs -f --tail 100
```

### 5. 🔐 Check certificates

```sh
./compose.sh certs
# Or check certificates in container:
docker compose exec certbot certbot certificates
# Or check certificates in host:
ls -alhF ./volumes/storage/certbot/ssl
# Or check certificates in host with tree:
tree ./volumes/storage/certbot/ssl
```

### 7. 🪂 Stop docker compose

```sh
./compose.sh stop
# Or:
docker compose down --remove-orphans
```

👍

---

## ⚙️ Configuration

### 🌎 Environment Variables

You can use the following environment variables to configure:

[**`.env.example`**](./.env.example):

```sh
## --- CERTBOT configs --- ##
## Email address for Let's Encrypt domain registration:
CERTBOT_EMAIL=user@email.com

## Domain names to obtain certificates:
CERTBOT_DOMAINS="example.com,www.example.com"

## DNS propagation timeout (in seconds):
CERTBOT_DNS_TIMEOUT=30


## -- Docker configs -- ##
# CERTBOT_PORT=80 # port for bridge network and standalone mode
```

### 🐳 Docker container command arguments

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

For example as in [**`compose.override.yml`**](./templates/compose/compose.override.dev.yml) file:

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

---

## 📚 Documentation

- [Build docker image](./docs/docker-build.md)
- [Certbot examples](./docs/certbot-examples.md)

### 🛤 Roadmap

- Add more DNS providers.
- Add more documentation.

---

## 📑 References

- Certbot - <https://certbot.eff.org>
- Certbot documentation - <https://eff-certbot.readthedocs.io/en/stable>
- Let's Encrypt - <https://letsencrypt.org>
- Let's Encrypt documentation - <https://letsencrypt.org/docs>
- Docker - <https://docs.docker.com>
- Docker Compose - <https://docs.docker.com/compose>
