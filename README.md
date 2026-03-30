# vrp-infra

Local-first infrastructure repository for a multi-app VRP platform. This repository does not build the business applications yet. It provides the shared platform layer around them:

- Traefik as the HTTP entrypoint and reverse proxy
- Keycloak as the central identity provider
- PostgreSQL for Keycloak state
- OAuth2 Proxy as a pragmatic phase-1 SSO layer for web apps
- Docker Compose for local orchestration
- Replaceable placeholder services for the portal and 3 application domains

## Architecture Summary

Phase 1 keeps local development simple:

- `Traefik` receives all browser traffic on local hostnames such as `portal.localhost` and `auth.localhost`.
- `Keycloak` owns users, roles, realm configuration, and OAuth clients.
- `OAuth2 Proxy` is deployed once per routed web app host. Each instance protects one app hostname and delegates login to Keycloak.
- `portal`, `truck-frontend`, `spbu-frontend`, and `dispatch-frontend` are exposed through Traefik.
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

   - `http://portal.localhost`
   - `http://auth.localhost`
   - `http://truck.localhost`
   - `http://spbu.localhost`
   - `http://dispatch.localhost`
   - `http://localhost:8081/dashboard/` for the Traefik dashboard by default

4. Log in with a sample Keycloak user after bootstrap completes.

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

If you change `TRAEFIK_HTTP_PORT` away from `80`, also set `PLATFORM_PUBLIC_PORT_SUFFIX`, for example `:8088`, so Keycloak and OAuth2 Proxy generate correct callback URLs.

## Replacing Placeholders Later

The placeholder services are intentionally named after the target platform services:

- `portal`
- `truck-frontend`
- `truck-backend`
- `spbu-frontend`
- `spbu-backend`
- `dispatch-frontend`
- `dispatch-backend`

You can swap them later in two supported ways:

- Replace a placeholder service with `build:` or `image:` from a real app repo
- Keep the real app running outside this stack and point Traefik or a bridge service at the existing local port

See [docs/repo-integration.md](docs/repo-integration.md).

## Documentation

- [Local architecture](docs/architecture-local.md)
- [Local setup](docs/local-setup.md)
- [Repository integration](docs/repo-integration.md)
- [VPS migration](docs/vps-migration.md)

## Known Limitations

- Local mode is HTTP only by design.
- OAuth2 Proxy is implemented per app hostname to avoid cookie-domain edge cases during local development.
- The backend placeholders are internal-only and do not model real application APIs yet.
- The production compose file is an example path, not a production-hardened deployment.
