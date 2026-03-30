# VPS Migration

## Goal

The local stack is intentionally designed so the same repository can evolve into a single-VPS deployment later, without redesigning the platform.

Target assumption:

- one Ubuntu VPS
- Docker Engine with Compose
- public DNS records
- HTTPS terminated at Traefik

## What Changes on a VPS

### Domains

Local hosts:

- `portal.localhost`
- `auth.localhost`
- `truck.localhost`
- `spbu.localhost`
- `dispatch.localhost`

VPS hosts typically become:

- `portal.example.com`
- `auth.example.com`
- `truck.example.com`
- `spbu.example.com`
- `dispatch.example.com`

### HTTPS

Local mode stays on HTTP by design.

On a VPS:

- enable Traefik `websecure`
- enable TLS routers
- attach a Let’s Encrypt resolver
- set `OAUTH2_PROXY_COOKIE_SECURE=true`
- change redirect URLs from `http://...` to `https://...`

The repository includes [docker-compose.prod.example.yml](../docker-compose.prod.example.yml) and [infra/traefik/traefik.prod.example.yml](../infra/traefik/traefik.prod.example.yml) as the starting point.

### DNS

Create public DNS records for each hostname and point them at the VPS IP address.

Example:

- `portal.example.com -> VPS_IP`
- `auth.example.com -> VPS_IP`
- `truck.example.com -> VPS_IP`
- `spbu.example.com -> VPS_IP`
- `dispatch.example.com -> VPS_IP`

### Environment Changes

Update `.env` values:

```dotenv
PLATFORM_PUBLIC_SCHEME=https
PLATFORM_PUBLIC_PORT_SUFFIX=
PORTAL_HOST=portal.example.com
KEYCLOAK_HOST=auth.example.com
KEYCLOAK_INTERNAL_URL=https://auth.example.com
TRUCK_HOST=truck.example.com
SPBU_HOST=spbu.example.com
DISPATCH_HOST=dispatch.example.com
DOMAIN=example.com
ACME_EMAIL=ops@example.com
```

In local mode, `KEYCLOAK_INTERNAL_URL` can stay on an internal Docker hostname such as `http://auth.localhost`. On a VPS, the internal and public Keycloak URL will usually be the same HTTPS hostname.

Also rotate:

- `KEYCLOAK_ADMIN_PASSWORD`
- `KEYCLOAK_DB_PASSWORD`
- `OAUTH2_PROXY_CLIENT_SECRET`
- `OAUTH2_PROXY_COOKIE_SECRET`
- any sample-user credentials before exposing the system outside local networks

## Let’s Encrypt

The production example uses Traefik ACME storage and a TLS cert resolver.

Before using it:

1. confirm DNS is live
2. open ports `80` and `443`
3. set a valid `ACME_EMAIL`
4. persist the Let’s Encrypt storage volume

## Security Hardening Checklist

- Do not keep sample users enabled in a public environment.
- Change all bootstrap credentials.
- Restrict the Traefik dashboard or disable it entirely.
- Consider moving Keycloak off `start-dev` and onto explicit production settings.
- Add backups for the Keycloak PostgreSQL database.
- Consider firewall rules so only Traefik is internet-facing.
- Add image pinning and a patching cadence.
- Add monitoring and log shipping before production traffic.

## Migration Path

Recommended order:

1. Move the local hostnames to real DNS names.
2. Switch Traefik to HTTPS.
3. Keep OAuth2 Proxy in place during the first VPS rollout.
4. Swap placeholders for real app images or builds.
5. Migrate apps to native OIDC later, one at a time.

This keeps the first VPS deployment simple and reduces the number of moving parts changed at once.
