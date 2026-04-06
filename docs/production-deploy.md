# Production Deploy

This document prepares the single-server production path for:

- `vrp_infa`
- `vrp_portal`
- `SPBU_Network_Masterdata`
- `truck_master_data`

## Architecture Decision

Use **Traefik** as the only host-level reverse proxy on ports `80/443`.

Do not install or enable host-level Nginx for this stack:

- Traefik already terminates TLS and routes by hostname.
- `truck-frontend`, `spbu-frontend`, and the dispatch placeholder already use Nginx inside their own containers.
- Running Nginx on the host would add an unnecessary extra proxy layer and compete for ports `80/443`.

## Files Added For Production

- `docker-compose.prod.yml`
  Real production stack that builds the portal, truck, and SPBU apps from sibling repositories.
- `.env.prod.example`
  Production environment template.
- `scripts/bootstrap-host.sh`
  Installs Docker Engine, Docker Compose plugin, UFW, and fail2ban, then prepares runtime directories.
- `scripts/deploy-production.sh`
  Validates and deploys the production compose stack.
- `scripts/install-systemd.sh`
  Installs the provided `systemd` unit for auto-start.
- `infra/systemd/vrp-platform.service`
  Boot-time compose unit.

## Before You Deploy

1. Point public DNS records to this server:
   - `portal.example.com`
   - `auth.example.com`
   - `truck.example.com`
   - `spbu.example.com`
   - `dispatch.example.com`
2. Confirm ports `80/tcp` and `443/tcp` are reachable from the internet.
3. Decide whether SSH should stay open to all addresses or only a restricted CIDR.
4. Replace every sample secret in `.env.prod`.

## Bootstrap Host

Run as root:

```bash
cd /home/ferdeh/vrp-workspace/vrp_infa
sudo SSH_PORT=22 SSH_ALLOW_CIDR=0.0.0.0/0 DEPLOY_USER=ferdeh ./scripts/bootstrap-host.sh
```

If you already know your office or bastion CIDR, replace `SSH_ALLOW_CIDR=0.0.0.0/0` with that range before enabling UFW.

What the script does:

- installs Docker Engine and Docker Compose plugin from Docker's official Ubuntu repository
- installs and enables UFW
- allows only `SSH`, `80/tcp`, and `443/tcp`
- installs and enables fail2ban for `sshd`
- prepares `.runtime/traefik/acme.json` with safe permissions

## Prepare Environment

```bash
cd /home/ferdeh/vrp-workspace/vrp_infa
cp .env.prod.example .env.prod
```

Minimum values to change:

- `PORTAL_HOST`
- `KEYCLOAK_HOST`
- `TRUCK_HOST`
- `SPBU_HOST`
- `DISPATCH_HOST`
- `ACME_EMAIL`
- `KEYCLOAK_ADMIN_PASSWORD`
- `KEYCLOAK_DB_PASSWORD`
- `OAUTH2_PROXY_CLIENT_SECRET`
- `OAUTH2_PROXY_COOKIE_SECRET`
- `TRUCK_DB_PASSWORD`
- `SPBU_DB_PASSWORD`

Production notes:

- `KEYCLOAK_SAMPLE_PASSWORD` should be rotated or the sample users removed before go-live.
- `dispatch` is still a placeholder service in this stack.
- SPBU and Truck stay private behind Traefik and `oauth2-proxy`.

## Install Auto-Start

Run as root:

```bash
cd /home/ferdeh/vrp-workspace/vrp_infa
sudo ./scripts/install-systemd.sh
```

## Deploy

Run as the deployment user after `.env.prod` is ready:

```bash
cd /home/ferdeh/vrp-workspace/vrp_infa
./scripts/deploy-production.sh
```

If the current shell has not picked up the `docker` group after bootstrap, log out and log back in first.

## Useful Operations

```bash
docker compose --env-file .env.prod -f docker-compose.prod.yml ps
docker compose --env-file .env.prod -f docker-compose.prod.yml logs -f traefik keycloak portal truck-backend spbu-backend
docker compose --env-file .env.prod -f docker-compose.prod.yml pull
docker compose --env-file .env.prod -f docker-compose.prod.yml up -d --build
systemctl status vrp-platform.service
```

## Current Limitation On This Server Session

The current shell user does not have non-interactive `sudo` access, so the host-level changes have been prepared but not applied from this session:

- Docker installation
- firewall activation
- fail2ban activation
- `systemd` installation

Once `sudo` is available, the scripts above are ready to run on this server.
