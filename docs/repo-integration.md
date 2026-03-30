# Repository Integration

## Scope

This repository is the platform shell. The business applications stay in their own repositories:

- Truck Master Data
  Example local checkout: `../truck_master_data`
- SPBU Master Data
  Example local checkout: `../SPBU_Network_Masterdata`
- VRP Dispatch
  Example local checkout: `../vrp_planner`

This repo keeps placeholders so the platform layer can be developed before those apps are pulled into the same local workflow.

## Current Placeholder Mapping

| Final target | Current placeholder service | Exposure |
| --- | --- | --- |
| Portal | `portal` | Routed by Traefik |
| Truck UI | `truck-frontend` | Routed by Traefik |
| Truck API | `truck-backend` | Private only |
| SPBU UI | `spbu-frontend` | Routed by Traefik |
| SPBU API | `spbu-backend` | Private only |
| Dispatch UI | `dispatch-frontend` | Routed by Traefik |
| Dispatch API | `dispatch-backend` | Private only |

## Integration Mode A: Build from a Local Repo Path

Use this when you want the infra repository to build and run the real application container from a checked-out local repository.

Example strategy:

1. Replace the placeholder service with a `build:` block.
2. Point `context:` at the actual repository path.
3. Keep the same service name so the Traefik labels and network expectations stay stable.

Example for the Truck frontend:

```yaml
truck-frontend:
  build:
    context: ../truck_master_data
    dockerfile: Dockerfile
  networks:
    - edge
  labels:
    - traefik.enable=true
    - traefik.http.routers.truck.rule=Host(`${TRUCK_HOST}`)
    - traefik.http.routers.truck.entrypoints=web
    - traefik.http.routers.truck.middlewares=platform-security@file,oauth-truck@file
    - traefik.http.services.truck-frontend.loadbalancer.server.port=3000
```

Benefits:

- Traefik config does not need to change
- OAuth2 Proxy routing does not need to change
- The placeholder can be swapped with minimal blast radius

## Integration Mode B: Proxy to an Already Running Local App

Use this when the application is already running on the host, for example:

- Truck backend on `http://localhost:8002`
- SPBU backend on `http://localhost:8000`
- Dispatch backend on `http://localhost:8080`

This mode is useful while application teams keep their current local workflow unchanged.

Recommended pattern:

1. Keep Traefik in this repo as the platform entrypoint.
2. Replace the placeholder container with a tiny bridge container or file-provider route that forwards to `host.docker.internal`.
3. Keep the public hostnames stable.

Example service bridge:

```yaml
truck-frontend:
  image: nginx:1.27-alpine
  extra_hosts:
    - host.docker.internal:host-gateway
```

For Traefik, the cleaner long-term option is usually a small file-provider service definition that points to `http://host.docker.internal:3002` or a dedicated bridge container.

## Recommended Integration Order

1. Replace frontends first while keeping backend placeholders internal.
2. Confirm SSO flow still works through OAuth2 Proxy.
3. Replace the matching backend service next.
4. Add app-specific environment variables only after the container swap is stable.

This keeps the platform shell stable while each app is onboarded.

## Future Native OIDC per App

When an app is ready to handle OIDC itself:

1. Create a native app client in Keycloak.
2. Remove the app-specific OAuth2 Proxy instance and Traefik forward-auth middleware for that app.
3. Keep the same routed hostname.
4. Pass identity and role handling directly into the application.

That lets migration happen one app at a time instead of as a platform-wide cutover.
