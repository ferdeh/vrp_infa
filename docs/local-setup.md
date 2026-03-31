# Local Setup

## Prerequisites

- Docker Desktop or Docker Engine with Compose v2
- A free local HTTP port, default `80`
- A free local Traefik dashboard port, default `8081`
- A shell with `make` and `openssl`

## Local Routing Modes

### Mode 1: `*.localhost`

This is the default and requires no hosts file edits.

Configured defaults:

- `portal.localhost`
- `auth.localhost`
- `truck.localhost`
- `spbu.localhost`
- `dispatch.localhost`

These are the default hostnames. When `TRAEFIK_HTTP_PORT=80`, open them without a port. If you override the port, for example `TRAEFIK_HTTP_PORT=8088`, open the same hostnames with `:8088` appended.

Keep these values in `.env`:

```dotenv
PLATFORM_USE_HOSTS_FILE=false
PLATFORM_LOCAL_DOMAIN=localhost
PLATFORM_BASE_DOMAIN=localhost
PLATFORM_PUBLIC_SCHEME=http
PLATFORM_PUBLIC_PORT_SUFFIX=
PORTAL_HOST=portal.localhost
KEYCLOAK_HOST=auth.localhost
KEYCLOAK_INTERNAL_URL=http://auth.localhost
TRUCK_HOST=truck.localhost
SPBU_HOST=spbu.localhost
DISPATCH_HOST=dispatch.localhost
```

### Mode 2: hosts file with `*.vrp.local`

Use this if you want a more production-like local domain or if your browser behaves poorly with local subdomain cookies.

Set `.env` like this:

```dotenv
PLATFORM_USE_HOSTS_FILE=true
PLATFORM_LOCAL_DOMAIN=vrp.local
PLATFORM_BASE_DOMAIN=vrp.local
PLATFORM_PUBLIC_SCHEME=http
PLATFORM_PUBLIC_PORT_SUFFIX=
PORTAL_HOST=portal.vrp.local
KEYCLOAK_HOST=auth.vrp.local
KEYCLOAK_INTERNAL_URL=http://auth.vrp.local
TRUCK_HOST=truck.vrp.local
SPBU_HOST=spbu.vrp.local
DISPATCH_HOST=dispatch.vrp.local
```

Add these entries to `/etc/hosts`:

```text
127.0.0.1 portal.vrp.local
127.0.0.1 auth.vrp.local
127.0.0.1 truck.vrp.local
127.0.0.1 spbu.vrp.local
127.0.0.1 dispatch.vrp.local
```

## Initial Setup

1. Generate a working `.env`.

   ```bash
   make init-env
   ```

2. Review the generated `.env` and update hostnames or ports if needed.

3. Start the stack.

   ```bash
   make up
   ```

4. Watch logs if the first bootstrap takes time.

   ```bash
   make logs
   ```

## What Starts

The local compose stack starts:

- Traefik
- PostgreSQL for Keycloak
- Keycloak
- Keycloak bootstrap job
- 4 OAuth2 Proxy instances
- 4 routed frontend placeholders
- 3 backend placeholders on the private network

## Local Test Checklist

### Traefik

- Open `http://localhost:8081/dashboard/`
- Confirm routers for `portal`, `truck`, `spbu`, `dispatch`, and `keycloak` exist

### Keycloak

- Use a regular browser window for the admin console. Avoid private or incognito mode in the local HTTP setup because Keycloak's admin console depends on cookie and storage checks during startup.
- Open `http://auth.localhost` or the alternate host you configured
- If `.env` sets `TRAEFIK_HTTP_PORT` to a non-default value such as `8088`, include that port in the browser URL, for example `http://auth.localhost:8088`
- Sign in to the admin console with `KEYCLOAK_ADMIN` and `KEYCLOAK_ADMIN_PASSWORD`
- Confirm the realm `vrp-platform` exists
- Confirm the realm roles were created

### OAuth2 Proxy

- Open `http://portal.localhost`
- If `.env` sets `TRAEFIK_HTTP_PORT` to a non-default value such as `8088`, include that port in the browser URL, for example `http://portal.localhost:8088`
- You should be redirected to Keycloak if you do not have a session
- Log in with one of the sample users created by the bootstrap job
- After login, you should land on the protected portal app
- Open `http://portal.localhost:8088/profile` when you want to confirm the forwarded auth headers and normalized user context

### Placeholder services

- `http://truck.localhost`
- `http://spbu.localhost`
- `http://dispatch.localhost`

If `.env` uses another Traefik port, open the same hostnames with that port attached, for example `http://truck.localhost:8088`.

Each frontend placeholder page confirms:

- the routed hostname
- the local auth pattern
- the intended backend service name that will be swapped later

## Useful Commands

```bash
make up
make down
make restart
make logs
make ps
make urls
make reset
```

## Troubleshooting

### Port 80 is already in use

Change `TRAEFIK_HTTP_PORT` in `.env`, for example:

```dotenv
TRAEFIK_HTTP_PORT=8088
PLATFORM_PUBLIC_PORT_SUFFIX=:8088
KEYCLOAK_INTERNAL_URL=http://auth.localhost
```

Then open the URLs with the port attached, for example `http://portal.localhost:8088`.

Keep `KEYCLOAK_INTERNAL_URL` on the internal Docker hostname without `:8088`. The host port suffix is for browsers and redirect URLs, not for container-to-container OIDC discovery.

### Keycloak admin console shows "Something went wrong"

In the local HTTP setup, the Keycloak admin console can fail to initialize if the browser blocks cookies or site storage for `auth.localhost`.

Try this in order:

```text
1. Use a normal browser window, not private/incognito mode.
2. Clear site data for auth.localhost and portal.localhost.
3. Allow cookies for auth.localhost:8088 if the browser is blocking them.
4. Temporarily disable privacy or ad-blocking extensions for auth.localhost:8088.
5. Reload http://auth.localhost:8088/admin/
```

If the admin console still fails, test in another browser profile before changing the stack configuration.

### Keycloak bootstrap did not finish

Inspect the bootstrap container:

```bash
docker compose --env-file .env -f docker-compose.local.yml logs keycloak-bootstrap
```

Rerun it if needed:

```bash
make bootstrap-keycloak
```

### OAuth2 Proxy login loops

Check:

- that `KEYCLOAK_HOST` matches the routed auth hostname
- that `KEYCLOAK_INTERNAL_URL` points at the internal Docker hostname for Keycloak discovery
- that the client secret in `.env` is unchanged after the clients were already created
- that your chosen hostname mode matches your browser URL

If you changed auth secrets after the first run, run:

```bash
make reset
make up
```

### `*.localhost` cookies behave unexpectedly

Switch to hosts-file mode with `*.vrp.local`. That is the intended fallback for local environments that are stricter about cookie handling.
