# Keycloak Bootstrap

Keycloak is bootstrapped by the one-shot `keycloak-bootstrap` service.

The bootstrap script creates:

- realm: `vrp-platform`
- realm roles
- sample users
- per-app OAuth2 Proxy clients

The bootstrap is environment-driven and avoids hardcoding client secrets into tracked files.

Main file:

- [bootstrap.sh](bootstrap/bootstrap.sh)
