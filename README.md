# vrp-infra

Local-first infrastructure repository for a multi-app VRP platform. It provides the shared platform layer around the business applications, and the local compose stack now builds the real portal app from the sibling `vrp_portal` repository:

- Traefik as the HTTP entrypoint and reverse proxy
- Keycloak as the central identity provider
- PostgreSQL for Keycloak state
- OAuth2 Proxy as a pragmatic phase-1 SSO layer for web apps
- Docker Compose for local orchestration
- Local integration of the real portal, truck, SPBU, and planner application runtimes from sibling repositories

## Architecture Summary

Phase 1 keeps local development simple:

- `Traefik` receives all browser traffic on local hostnames such as `portal.localhost` and `auth.localhost`.
- `Keycloak` owns users, roles, realm configuration, and OAuth clients.
- `OAuth2 Proxy` is deployed once per routed web app host. Each instance fronts one app hostname, delegates login to Keycloak, and proxies the authenticated request to the matching frontend.
- `portal`, `truck-frontend`, `spbu-frontend`, and `planner-frontend` are exposed through Traefik.
- `portal` is built from `../vrp_portal` and runs as a production Next.js container on the private Docker network.
- `truck-backend`, `spbu-backend`, `planner-backend`, and their databases stay on the private Docker network by default.

This is intentionally local-first and HTTP-only. The production path is documented, but the main implementation optimizes for fast local setup.

## Project Tree

```text
.
├── .env.example
├── Makefile
├── README.md
├── docker-compose.local.yml
├── docker-compose.prod.example.yml
├── docs
│   ├── architecture-local.md
│   ├── local-setup.md
│   ├── repo-integration.md
│   └── vps-migration.md
├── infra
│   ├── keycloak
│   │   ├── README.md
│   │   └── bootstrap
│   │       └── bootstrap.sh
│   ├── oauth2-proxy
│   │   └── README.md
│   ├── placeholders
│   │   ├── portal
│   │   │   └── index.html
│   │   ├── shared
│   │   │   └── style.css
│   │   ├── spbu-frontend
│   │   │   └── index.html
│   │   └── truck-frontend
│   │       └── index.html
│   └── traefik
│       ├── dynamic
│       │   └── middlewares.yml
│       ├── traefik.prod.example.yml
│       └── traefik.yml
└── scripts
    ├── init-env.sh
    ├── logs.sh
    ├── reset-local.sh
    ├── show-urls.sh
    └── start-local.sh
```

## Quick Start

1. Create a local environment file.

   ```bash
   make init-env
   ```

2. Start the local stack.

   ```bash
   make up
   ```

3. Open the routed endpoints.

   These are the default browser URLs when `TRAEFIK_HTTP_PORT=80` and `PLATFORM_PUBLIC_PORT_SUFFIX=`:

   - `http://portal.localhost`
   - `http://auth.localhost`
   - `http://truck.localhost`
   - `http://spbu.localhost`
   - `http://planner.localhost`
   - `http://localhost:8081/dashboard/` for the Traefik dashboard by default

   If your local `.env` uses another port, for example `TRAEFIK_HTTP_PORT=8088` and `PLATFORM_PUBLIC_PORT_SUFFIX=:8088`, open the same hostnames with that port attached:

   - `http://portal.localhost:8088`
   - `http://auth.localhost:8088`
   - `http://truck.localhost:8088`
   - `http://spbu.localhost:8088`
   - `http://planner.localhost:8088`

4. Log in with a sample Keycloak user after bootstrap completes.

   For the local HTTP setup, use a regular browser window for Keycloak. Private or incognito mode can break the admin console because the browser may block the cookie and storage checks Keycloak performs during startup.

   Sample usernames are created automatically:

   - `alice.admin`
   - `olivia.ops`
   - `tom.truck`
   - `sarah.spbu`
   - `paula.planner`
   - `victor.viewer`

   The shared sample password is stored in `.env` as `KEYCLOAK_SAMPLE_PASSWORD`.

## Local Routing Modes

Default mode uses `*.localhost` and does not need `/etc/hosts` changes:

- `portal.localhost`
- `auth.localhost`
- `truck.localhost`
- `spbu.localhost`
- `planner.localhost`

Alternate mode uses a hosts file and a custom local domain:

- `portal.vrp.local`
- `auth.vrp.local`
- `truck.vrp.local`
- `spbu.vrp.local`
- `planner.vrp.local`

Switch modes by editing `.env`. See [docs/local-setup.md](docs/local-setup.md).

The hostnames above describe the routing names. Your actual browser URL also depends on `TRAEFIK_HTTP_PORT`:

- with `TRAEFIK_HTTP_PORT=80`, use `http://portal.localhost`
- with `TRAEFIK_HTTP_PORT=8088`, use `http://portal.localhost:8088`

If you change `TRAEFIK_HTTP_PORT` away from `80`, also set `PLATFORM_PUBLIC_PORT_SUFFIX`, for example `:8088`, so Keycloak and OAuth2 Proxy generate correct callback URLs.

Also keep `KEYCLOAK_INTERNAL_URL` on the internal Docker address, for example `http://auth.localhost`. Containers should use the internal Traefik port `80` even when the host publishes Traefik on another port such as `8088`.

## Integrated Runtime Model

The intended local workflow is now:

- source code lives in sibling repositories such as `../vrp_portal`, `../truck_master_data`, `../SPBU_Network_Masterdata/spbu-network-mvp`, and `../vrp_planner`
- runtime services live in this repo's `docker-compose.local.yml`
- browser access goes only through routed platform hosts such as `portal.localhost:8088` and `planner.localhost:8088`
- frontend-to-backend and backend-to-database traffic uses Docker service names, not `localhost`

See [docs/repo-integration.md](docs/repo-integration.md), [docs/portal-integration.md](docs/portal-integration.md), [docs/spbu-integration.md](docs/spbu-integration.md), and [docs/planner-integration.md](docs/planner-integration.md).

## Documentation

- [Local architecture](docs/architecture-local.md)
- [Local setup](docs/local-setup.md)
- [Repository integration](docs/repo-integration.md)
- [Portal integration](docs/portal-integration.md)
- [SPBU integration](docs/spbu-integration.md)
- [Planner integration](docs/planner-integration.md)
- [VPS migration](docs/vps-migration.md)

## Known Limitations

- Local mode is HTTP only by design.
- OAuth2 Proxy is implemented per app hostname to avoid cookie-domain edge cases during local development.
- OAuth2 Proxy is still the auth boundary for all application frontends in local mode.
- The production compose file is an example path, not a production-hardened deployment.
