# Portal Integration

## Summary

The local `portal` service in [`docker-compose.local.yml`](../docker-compose.local.yml) now builds the real Next.js app from `../vrp_portal` instead of serving the static placeholder from `infra/placeholders/portal`.

The public route stays the same:

- `http://portal.localhost:8088`

The auth flow stays the same:

- Browser -> Traefik -> `oauth2-proxy-portal` -> `portal`
- Login delegated to Keycloak at `http://auth.localhost:8088`

## What Changed

- `portal` now builds from `../vrp_portal/Dockerfile`
- the app listens on container port `3000`
- `oauth2-proxy-portal` now proxies to `http://portal:3000`
- the portal container gets the required runtime environment variables
- proxy header forwarding is explicit with `OAUTH2_PROXY_PASS_USER_HEADERS=true`

## Portal Runtime Environment

The local compose stack injects these values into the `portal` container:

- `NEXT_PUBLIC_APP_NAME=VRP Petrofin Portal`
- `NEXT_PUBLIC_PORTAL_BASE_URL=http://portal.localhost:8088`
- `NEXT_PUBLIC_TRUCK_URL=http://truck.localhost:8088`
- `NEXT_PUBLIC_SPBU_URL=http://spbu.localhost:8088`
- `NEXT_PUBLIC_PLANNER_URL=http://planner.localhost:8088`
- `NEXT_PUBLIC_LOGOUT_URL=http://auth.localhost:8088/realms/vrp-platform/protocol/openid-connect/logout`
- `PORTAL_AUTH_MODE=headers`

Those URLs come from the existing `.env` values:

```dotenv
TRAEFIK_HTTP_PORT=8088
PLATFORM_PUBLIC_PORT_SUFFIX=:8088
PLATFORM_PUBLIC_SCHEME=http
PORTAL_HOST=portal.localhost
KEYCLOAK_HOST=auth.localhost
TRUCK_HOST=truck.localhost
SPBU_HOST=spbu.localhost
PLANNER_HOST=planner.localhost
```

## Rebuild and Run

From `vrp_infa`:

```bash
docker compose --env-file .env -f docker-compose.local.yml build portal
docker compose --env-file .env -f docker-compose.local.yml up -d --build
docker compose --env-file .env -f docker-compose.local.yml ps
```

If you want the clean restart path instead:

```bash
docker compose --env-file .env -f docker-compose.local.yml down --remove-orphans
docker compose --env-file .env -f docker-compose.local.yml up -d --build
```

## Login Flow Validation

1. Open a normal browser window. Do not use private or incognito mode for the local HTTP Keycloak flow.
2. Open `http://auth.localhost:8088/admin/` and confirm the admin console is reachable.
3. Sign in to the admin console with `KEYCLOAK_ADMIN` and `KEYCLOAK_ADMIN_PASSWORD` from `.env` if you need to inspect realms or clients.
4. Open `http://portal.localhost:8088`.
5. Confirm you are redirected to Keycloak.
6. Sign in with one of the sample users, for example `alice.admin`, using the password stored in `.env` as `KEYCLOAK_SAMPLE_PASSWORD`.
7. Confirm you are redirected back to the portal app.
8. Open `http://portal.localhost:8088/profile`.
9. Confirm the page shows:
   - `authMode` as `headers`
   - `authSource` as `headers`
   - a populated normalized user
   - forwarded header entries in the debug section

## Expected Auth Headers at the Portal App

Traefik forwards the browser request to `oauth2-proxy-portal`, and OAuth2 Proxy forwards the authenticated request to the `portal` container.

The portal app already supports these upstream identity headers:

- `x-forwarded-user`
- `x-forwarded-email`
- `x-forwarded-preferred-username`
- `x-auth-request-user`
- `x-auth-request-email`
- `x-auth-request-groups`
- `authorization`

The current OAuth2 Proxy settings are intended to make these available upstream:

- `OAUTH2_PROXY_PASS_USER_HEADERS=true`
- `OAUTH2_PROXY_SET_XAUTHREQUEST=true`
- `OAUTH2_PROXY_PASS_AUTHORIZATION_HEADER=true`
- `OAUTH2_PROXY_SET_AUTHORIZATION_HEADER=true`

This keeps the portal on header-based auth without adding native OIDC into the app.

## Browser Note For Local HTTP

The local stack is intentionally HTTP-only. Keycloak's admin console performs cookie and storage checks during startup, so private browsing modes or aggressive cookie blocking can cause the browser UI to show a generic `Something went wrong` error even when the server-side route is healthy.

If that happens:

- use a normal browser window
- clear site data for `auth.localhost` and `portal.localhost`
- allow cookies for `auth.localhost:8088`
- temporarily disable privacy-blocking extensions for the local hostnames

## Rollback

To roll back to the static placeholder:

1. In [`docker-compose.local.yml`](../docker-compose.local.yml), change `oauth2-proxy-portal` back to `OAUTH2_PROXY_UPSTREAMS: http://portal:80`.
2. Replace the `portal` service with the old placeholder definition:

```yaml
portal:
  image: nginx:1.27-alpine
  volumes:
    - ./infra/placeholders/portal:/usr/share/nginx/html:ro
  networks:
    - private
  restart: unless-stopped
```

3. Recreate the two affected services:

```bash
docker compose --env-file .env -f docker-compose.local.yml up -d --force-recreate portal oauth2-proxy-portal
```

If you want to discard the integration changes completely, revert the modified files in git and bring the stack up again.
