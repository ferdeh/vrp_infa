# Planner Integration

## Summary

The local `planner-frontend`, `planner-backend`, and `planner-db` services in [`docker-compose.local.yml`](../docker-compose.local.yml) now run the real VRP Planner application from `../vrp_planner`.

The public route is:

- `http://planner.localhost:8088`

The auth flow stays platform-owned:

- Browser -> Traefik -> `oauth2-proxy-planner` -> `planner-frontend`
- Login delegated to Keycloak at `http://auth.localhost:8088`

The planner repo is now treated as source code only for the primary local workflow:

- browser traffic should use `planner.localhost:8088`
- runtime services should be started from `vrp_infa`
- internal traffic uses `planner-backend`, `planner-db`, `truck-backend`, and `spbu-backend`

## Runtime Topology

- `planner-frontend`: built from `../vrp_planner/frontend`
- `planner-backend`: built from `../vrp_planner/backend`
- `planner-db`: internal PostgreSQL for planner state
- `oauth2-proxy-planner`: auth front for `planner.localhost`

Planner service connections:

- frontend -> backend: `http://planner-backend:8080`
- backend -> database: `postgresql+psycopg2://<PLANNER_DB_USER>:<PLANNER_DB_PASSWORD>@planner-db:5432/<PLANNER_DB_NAME>`
- backend -> SPBU master data: `http://spbu-backend:8000`
- backend -> Truck master data: `http://truck-backend:8000`

## What Changed

- the old `dispatch` placeholder host and services were replaced with `planner` naming
- the frontend now uses same-origin requests and lets Nginx proxy `/api` to `planner-backend`
- the frontend exposes `Back to Portal` through `/portal`
- the frontend exposes `Logout` through `/api/v1/auth/logout-redirect`
- the backend now has a proxy-assisted logout handoff for Keycloak RP-initiated logout
- the backend now defaults to internal Docker service names instead of `host.docker.internal`
- the planner database now runs inside `vrp_infa` as `planner-db`

## Runtime Environment

Key infra variables:

```dotenv
PLANNER_HOST=planner.localhost
PLANNER_DB_PORT=5432
PLANNER_DB_NAME=vrp_planner
PLANNER_DB_USER=planner
PLANNER_DB_PASSWORD=replace-me
```

Planner container env values injected from infra:

- `PLANNER_API_UPSTREAM=http://planner-backend:8080`
- `PORTAL_URL=http://portal.localhost:8088`
- `DATABASE_URL=postgresql+psycopg2://<PLANNER_DB_USER>:<PLANNER_DB_PASSWORD>@planner-db:5432/<PLANNER_DB_NAME>`
- `MASTER_DATA_API_BASE_URL=http://spbu-backend:8000`
- `TRUCK_MASTER_DATA_API_BASE_URL=http://truck-backend:8000`
- `CORS_ORIGINS=http://planner.localhost:8088`
- `PLANNER_PUBLIC_BASE_URL=http://planner.localhost:8088`
- `PLANNER_AUTH_LOGOUT_URL=http://auth.localhost:8088/realms/vrp-platform/protocol/openid-connect/logout`
- `PLANNER_OAUTH_CLIENT_ID=oauth2-proxy-planner`

## Portal and Role Wiring

- portal launcher target uses `NEXT_PUBLIC_PLANNER_URL`
- launcher visibility is resolved through `planner_user`, plus `admin` and `ops`
- Keycloak bootstrap now creates:
  - realm role `planner_user`
  - sample user `paula.planner`
  - client `oauth2-proxy-planner`

## Rebuild and Run

From `vrp_infa`:

```bash
docker compose --env-file .env -f docker-compose.local.yml build planner-backend planner-frontend portal
docker compose --env-file .env -f docker-compose.local.yml up -d planner-db planner-backend planner-frontend oauth2-proxy-planner portal
docker compose --env-file .env -f docker-compose.local.yml ps
```

For a full recreate:

```bash
docker compose --env-file .env -f docker-compose.local.yml down --remove-orphans
docker compose --env-file .env -f docker-compose.local.yml up -d --build
```

## Validation

1. Open `http://planner.localhost:8088`.
2. Confirm redirect to Keycloak when no session exists.
3. Sign in with `paula.planner` and `KEYCLOAK_SAMPLE_PASSWORD`.
4. Confirm the real planner UI loads instead of the placeholder.
5. Confirm browser API requests go to `/api/v1/...` on the same origin.
6. Confirm planner can load depots, SPBU, trucks, and save planner state.
7. Click `Back to Portal` and confirm the browser returns to `http://portal.localhost:8088`.
8. Click `Logout` and confirm the next visit requires a fresh login.

## Rollback

1. Revert the planner-related changes in `docker-compose.local.yml`, `.env`, `.env.example`, and Keycloak bootstrap.
2. Restore the old `dispatch` placeholder services if you explicitly want the previous scaffold back.
3. Recreate the affected services:

```bash
docker compose --env-file .env -f docker-compose.local.yml up -d --force-recreate planner-db planner-backend planner-frontend oauth2-proxy-planner portal
```
