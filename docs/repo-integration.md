# Repository Integration

## Scope

This repository is the platform shell. The business applications stay in their own repositories:

- Truck Master Data
  Example local checkout: `../truck_master_data`
- SPBU Master Data
  Example local checkout: `../SPBU_Network_Masterdata`
- VRP Planner
  Example local checkout: `../vrp_planner`

This repo is the runtime shell for the platform. The application repositories stay source-code-only, while the actual local runtime is orchestrated from this compose stack. The portal, truck, SPBU, and planner apps are all built from sibling repositories in local compose.

## Current Runtime Mapping

| Final target | Current placeholder service | Exposure |
| --- | --- | --- |
| Portal | `portal` | Routed by Traefik, built from `../vrp_portal` |
| Truck UI | `truck-frontend` | Routed by Traefik, built from `../truck_master_data/web` |
| Truck API | `truck-backend` | Private only |
| SPBU UI | `spbu-frontend` | Routed by Traefik, built from `../SPBU_Network_Masterdata/spbu-network-mvp/frontend` |
| SPBU API | `spbu-backend` | Private only |
| Planner UI | `planner-frontend` | Routed by Traefik, built from `../vrp_planner/frontend` |
| Planner API | `planner-backend` | Private only |
| Planner DB | `planner-db` | Private only |

## Integration Mode A: Build from a Local Repo Path

Use this when you want the infra repository to build and run the real application container from a checked-out local repository.

Example strategy:

1. Replace the placeholder service with a `build:` block.
2. Point `context:` at the actual repository path.
3. Keep the same service name so the Traefik labels and network expectations stay stable.

Concrete example for the portal:

```yaml
portal:
  build:
    context: ../vrp_portal
    dockerfile: Dockerfile
  environment:
    PORT: "3000"
    PORTAL_AUTH_MODE: headers
  networks:
    - private
```

Benefits:

- Traefik config does not need to change
- OAuth2 Proxy routing does not need to change
- The placeholder can be swapped with minimal blast radius
- The service name `portal` stays stable for `oauth2-proxy-portal`

## Standalone App Repos

Standalone execution inside app repositories is now considered secondary only. The recommended local runtime is always the integrated platform in `vrp_infa`, so browser access stays behind Traefik, OAuth2 Proxy, and Keycloak, and container-to-container calls stay on Docker service names.

## Recommended Integration Order

1. Build the real frontend and backend from the sibling app repository.
2. Keep the public hostname and `oauth2-proxy-*` service name stable.
3. Keep backend and databases private on the Docker network.
4. Prefer same-origin `/api` forwarding from frontend containers to backend containers.

## Future Native OIDC per App

When an app is ready to handle OIDC itself:

1. Create a native app client in Keycloak.
2. Remove the app-specific OAuth2 Proxy instance and Traefik forward-auth middleware for that app.
3. Keep the same routed hostname.
4. Pass identity and role handling directly into the application.

That lets migration happen one app at a time instead of as a platform-wide cutover.
