# SPBU Integration

## Summary

The local `spbu-frontend`, `spbu-backend`, and `spbu-db` services in [`docker-compose.local.yml`](../docker-compose.local.yml) now build the real SPBU Master Data application from `../SPBU_Network_Masterdata/spbu-network-mvp` instead of serving placeholder containers.

The public route stays the same:

- `http://spbu.localhost:8088`

The auth flow stays the same:

- Browser -> Traefik -> `oauth2-proxy-spbu` -> `spbu-frontend`
- Login delegated to Keycloak at `http://auth.localhost:8088`

The cross-app navigation now stays platform-oriented:

- Portal -> SPBU uses the portal launcher card target from `NEXT_PUBLIC_SPBU_URL`
- SPBU -> Portal uses the SPBU header link `Back to Portal`
- the SPBU frontend sends that link to `/portal`, and Nginx redirects it to `PORTAL_URL`

The logout flow now mirrors the Truck pattern:

- Browser -> `spbu-frontend` logout link -> `GET /api/auth/logout-redirect`
- `spbu-backend` reads the upstream `Authorization: Bearer <id_token>` header from `oauth2-proxy-spbu`
- `spbu-backend` builds the Keycloak RP-initiated logout URL with `id_token_hint`
- browser is redirected to `/oauth2/sign_out?rd=<keycloak logout url>`
- `oauth2-proxy-spbu` clears its own session and forwards to Keycloak logout
- Keycloak ends the SSO session and redirects back to `http://spbu.localhost:8088/oauth2/sign_in`

The SPBU backend stays private on the Docker network:

- `spbu-backend:8000`

The SPBU database also stays private on the Docker network:

- `spbu-db:5432`

## Detected App Structure

Repository layout in `../SPBU_Network_Masterdata/spbu-network-mvp`:

- `frontend/`: React 18 + TypeScript + Vite frontend served by Nginx
- `backend/`: FastAPI backend with direct psycopg2 access
- `db/init/001_init.sql`: database bootstrap SQL for the SPBU schema
- `samples/`: sample Excel upload input

Detected runtime details:

- Frontend container port: `80`
- Backend container port: `8000`
- Frontend browser API base: `/api`
- Frontend upstream API target: configurable through `SPBU_API_UPSTREAM`
- Backend database: PostGIS database provided inside this compose stack as `spbu-db`
- Backend auxiliary dependencies: none detected beyond the database

## What Changed

- `spbu-frontend` now builds from `../SPBU_Network_Masterdata/spbu-network-mvp/frontend/Dockerfile`
- `spbu-backend` now builds from `../SPBU_Network_Masterdata/spbu-network-mvp/backend/Dockerfile`
- `spbu-db` now runs as an internal PostGIS container and initializes from `../SPBU_Network_Masterdata/spbu-network-mvp/db/init`
- `oauth2-proxy-spbu` still fronts `spbu.localhost` and now waits for the real frontend healthcheck
- the frontend Nginx config now proxies `/api` to `SPBU_API_UPSTREAM`, which is set in infra to `http://spbu-backend:8000`
- the frontend Nginx config also redirects `/portal` to `PORTAL_URL`, which is set in infra to `http://portal.localhost:8088`
- the frontend no longer bakes `localhost` as its API base during image build
- SPBU logout now uses a backend-assisted handoff so Keycloak receives an `id_token_hint`
- `oauth2-proxy-spbu` now whitelists the Keycloak host in `OAUTH2_PROXY_WHITELIST_DOMAINS` so `/oauth2/sign_out?rd=...` can redirect to the Keycloak logout endpoint

## SPBU Runtime Environment

The local compose stack injects these values into the SPBU services:

- `DATABASE_URL=postgresql+psycopg2://<SPBU_DB_USER>:<SPBU_DB_PASSWORD>@spbu-db:5432/<SPBU_DB_NAME>`
- `SPBU_API_UPSTREAM=http://spbu-backend:8000`
- `PORTAL_URL=http://portal.localhost:8088`
- `CORS_ORIGINS=http://spbu.localhost:8088`
- `SPBU_PUBLIC_BASE_URL=http://spbu.localhost:8088`
- `SPBU_AUTH_LOGOUT_URL=http://auth.localhost:8088/realms/vrp-platform/protocol/openid-connect/logout`
- `SPBU_OAUTH_CLIENT_ID=oauth2-proxy-spbu`

Relevant `.env` values:

```dotenv
SPBU_DB_PORT=5432
SPBU_DB_NAME=spbu_master_data
SPBU_DB_USER=spbu
SPBU_DB_PASSWORD=replace-me
```

## Logout Flow

The SPBU app still does not implement native OIDC in the frontend. Logout is handled at the infra boundary with a small backend handoff so the current phase-1 auth model stays intact.

Runtime behavior:

- the SPBU UI logout button points to `/api/auth/logout-redirect`
- `spbu-backend` expects `oauth2-proxy-spbu` to pass through `Authorization`
- `spbu-backend` converts that token into a Keycloak logout URL using:
  - `SPBU_AUTH_LOGOUT_URL`
  - `SPBU_PUBLIC_BASE_URL`
  - `SPBU_OAUTH_CLIENT_ID`
- the backend redirects the browser to `/oauth2/sign_out?rd=<encoded keycloak logout url>`
- `oauth2-proxy-spbu` clears the SPBU session cookie
- Keycloak receives `id_token_hint` and completes RP-initiated logout

This is why the compose wiring must preserve:

- `OAUTH2_PROXY_PASS_AUTHORIZATION_HEADER=true`
- `OAUTH2_PROXY_SET_AUTHORIZATION_HEADER=true`
- `OAUTH2_PROXY_WHITELIST_DOMAINS=.${SPBU_HOST},${KEYCLOAK_HOST}${PLATFORM_PUBLIC_PORT_SUFFIX}`

## Portal Navigation

The SPBU header now exposes a `Back to Portal` action without adding client-side OIDC or hardcoded public URLs into the React bundle.

Runtime behavior:

- the header button links to `/portal`
- Nginx resolves `/portal` with `return 302 ${PORTAL_URL}`
- infra sets `PORTAL_URL=${PLATFORM_PUBLIC_SCHEME}://${PORTAL_HOST}${PLATFORM_PUBLIC_PORT_SUFFIX}`

This keeps the SPBU frontend runtime-configurable for local development now and VPS hostnames later.

## Assumptions

- `../SPBU_Network_Masterdata/spbu-network-mvp` is available next to `vrp_infa`
- the SPBU app should keep using infra-managed auth through `oauth2-proxy-spbu`
- the SPBU backend should not be published directly on a host port
- the SPBU app should keep using the internal `spbu-db` PostGIS service for its database state

## Rebuild and Run

From `vrp_infa`:

```bash
docker compose --env-file .env -f docker-compose.local.yml build spbu-frontend spbu-backend
docker compose --env-file .env -f docker-compose.local.yml up -d spbu-db spbu-backend spbu-frontend oauth2-proxy-spbu
docker compose --env-file .env -f docker-compose.local.yml ps
```

For a full stack recreate:

```bash
docker compose --env-file .env -f docker-compose.local.yml down --remove-orphans
docker compose --env-file .env -f docker-compose.local.yml up -d --build
```

## Local Validation

1. Open `http://auth.localhost:8088` and confirm Keycloak is reachable.
2. Open `http://spbu.localhost:8088`.
3. Confirm you are redirected to Keycloak.
4. Sign in with a sample user such as `sarah.spbu` using `KEYCLOAK_SAMPLE_PASSWORD` from `.env`.
5. Confirm you are redirected back to the SPBU app.
6. Confirm the graph UI loads without browser console errors.
7. Confirm browser XHR requests go to `/api/...` on the same browser origin and return `200` responses.
8. Click `Back to Portal` in the SPBU header and confirm the browser returns to `http://portal.localhost:8088`.
9. Return to `http://spbu.localhost:8088`, click `Logout`, and confirm the browser lands on the Keycloak login screen for client `oauth2-proxy-spbu`.
10. Open `http://spbu.localhost:8088` again and confirm you are asked to log in again instead of being returned directly to the graph UI.
11. Confirm `docker compose --env-file .env -f docker-compose.local.yml logs spbu-backend` shows no startup failures.

Optional API checks from the infra repo:

```bash
docker compose --env-file .env -f docker-compose.local.yml exec spbu-backend python -c "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8000/health').read().decode())"
docker compose --env-file .env -f docker-compose.local.yml exec spbu-frontend wget -q -O - http://127.0.0.1/
docker compose --env-file .env -f docker-compose.local.yml logs spbu-backend | rg "logout"
```

## Rollback

To roll back to the placeholders:

1. In [`docker-compose.local.yml`](../docker-compose.local.yml), change `oauth2-proxy-spbu` back to depend only on `keycloak-bootstrap` if desired.
2. Replace `spbu-frontend` with the old placeholder Nginx service.
3. Replace `spbu-backend` with the old `hashicorp/http-echo` placeholder.
4. Recreate the SPBU-related services:

```bash
docker compose --env-file .env -f docker-compose.local.yml up -d --force-recreate spbu-frontend spbu-backend oauth2-proxy-spbu
```

If you want to discard the integration entirely, revert the modified files in git and bring the stack up again.
