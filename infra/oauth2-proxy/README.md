# OAuth2 Proxy Layout

This repository uses one OAuth2 Proxy instance per protected web hostname:

- `oauth2-proxy-portal`
- `oauth2-proxy-truck`
- `oauth2-proxy-spbu`
- `oauth2-proxy-dispatch`

Why:

- local cookie behavior is easier to reason about
- each app can later diverge in policy if needed
- the removal path is simple when an app gains native OIDC support

In phase 1, OAuth2 Proxy acts only as the web access gate. It does not replace future native OIDC support inside the applications.
