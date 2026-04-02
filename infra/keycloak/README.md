# Keycloak Bootstrap

Keycloak is bootstrapped by the one-shot `keycloak-bootstrap` service.

The bootstrap script creates:

- realm: `vrp-platform`
- realm roles
- sample users
- per-app OAuth2 Proxy clients
- realm login theme `petrofin`

The bootstrap is environment-driven and avoids hardcoding client secrets into tracked files.

Custom theme files live under [`../keycloak/themes`](themes) and must be present in the
running Keycloak container for the `petrofin` login theme to render correctly in both local
and production environments.

Main file:

- [bootstrap.sh](bootstrap/bootstrap.sh)
