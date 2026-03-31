# vrp-infra

Local-first infrastructure repository for a multi-app VRP platform. It provides the shared platform layer around the business applications, and the local compose stack now builds the real portal app from the sibling `vrp_portal` repository:

- Traefik as the HTTP entrypoint and reverse proxy
- Keycloak as the central identity provider
- PostgreSQL for Keycloak state
- OAuth2 Proxy as a pragmatic phase-1 SSO layer for web apps
- Docker Compose for local orchestration
- Local integration of the real portal app plus replaceable placeholder services for 3 application domains

## Architecture Summary

Phase 1 keeps local development simple:

- `Traefik` receives all browser traffic on local hostnames such as `portal.localhost` and `auth.localhost`.
- `Keycloak` owns users, roles, realm configuration, and OAuth clients.
- `OAuth2 Proxy` is deployed once per routed web app host. Each instance fronts one app hostname, delegates login to Keycloak, and proxies the authenticated request to the matching frontend.
- `portal`, `truck-frontend`, `spbu-frontend`, and `dispatch-frontend` are exposed through Traefik.
- `portal` is built from `../vrp_portal` and runs as a production Next.js container on the private Docker network.
- `truck-backend`, `spbu-backend`, and `dispatch-backend` stay on the private Docker network by default.

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
│   │   ├── dispatch-frontend
│   │   │   └── index.html
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
   - `http://dispatch.localhost`
   - `http://localhost:8081/dashboard/` for the Traefik dashboard by default

   If your local `.env` uses another port, for example `TRAEFIK_HTTP_PORT=8088` and `PLATFORM_PUBLIC_PORT_SUFFIX=:8088`, open the same hostnames with that port attached:

   - `http://portal.localhost:8088`
   - `http://auth.localhost:8088`
   - `http://truck.localhost:8088`
   - `http://spbu.localhost:8088`
   - `http://dispatch.localhost:8088`

4. Log in with a sample Keycloak user after bootstrap completes.

   For the local HTTP setup, use a regular browser window for Keycloak. Private or incognito mode can break the admin console because the browser may block the cookie and storage checks Keycloak performs during startup.

   Sample usernames are created automatically:

   - `alice.admin`
   - `olivia.ops`
   - `tom.truck`
   - `sarah.spbu`
   - `david.dispatch`
   - `victor.viewer`

   The shared sample password is stored in `.env` as `KEYCLOAK_SAMPLE_PASSWORD`.

## Local Routing Modes

Default mode uses `*.localhost` and does not need `/etc/hosts` changes:

- `portal.localhost`
- `auth.localhost`
- `truck.localhost`
- `spbu.localhost`
- `dispatch.localhost`

Alternate mode uses a hosts file and a custom local domain:

- `portal.vrp.local`
- `auth.vrp.local`
- `truck.vrp.local`
- `spbu.vrp.local`
- `dispatch.vrp.local`

Switch modes by editing `.env`. See [docs/local-setup.md](docs/local-setup.md).

The hostnames above describe the routing names. Your actual browser URL also depends on `TRAEFIK_HTTP_PORT`:

- with `TRAEFIK_HTTP_PORT=80`, use `http://portal.localhost`
- with `TRAEFIK_HTTP_PORT=8088`, use `http://portal.localhost:8088`

If you change `TRAEFIK_HTTP_PORT` away from `80`, also set `PLATFORM_PUBLIC_PORT_SUFFIX`, for example `:8088`, so Keycloak and OAuth2 Proxy generate correct callback URLs.

Also keep `KEYCLOAK_INTERNAL_URL` on the internal Docker address, for example `http://auth.localhost`. Containers should use the internal Traefik port `80` even when the host publishes Traefik on another port such as `8088`.

## Replacing Placeholders Later

The remaining placeholder services are intentionally named after the target platform services:

- `truck-frontend`
- `truck-backend`
- `spbu-frontend`
- `spbu-backend`
- `dispatch-frontend`
- `dispatch-backend`

The portal service is already wired to the real `vrp_portal` repo. The other placeholders can still be swapped later in two supported ways:

- Replace a placeholder service with `build:` or `image:` from a real app repo
- Keep the real app running outside this stack and point Traefik or a bridge service at the existing local port

See [docs/repo-integration.md](docs/repo-integration.md).
See [docs/portal-integration.md](docs/portal-integration.md) for the concrete portal wiring, rebuild flow, header expectations, and rollback steps.

## Documentation

- [Local architecture](docs/architecture-local.md)
- [Local setup](docs/local-setup.md)
- [Repository integration](docs/repo-integration.md)
- [Portal integration](docs/portal-integration.md)
- [VPS migration](docs/vps-migration.md)

## Known Limitations

- Local mode is HTTP only by design.
- OAuth2 Proxy is implemented per app hostname to avoid cookie-domain edge cases during local development.
- The backend placeholders are internal-only and do not model real application APIs yet.
- The production compose file is an example path, not a production-hardened deployment.
