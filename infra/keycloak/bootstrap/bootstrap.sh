#!/usr/bin/env bash
set -euo pipefail

KEYCLOAK_SERVER_URL="http://keycloak:8080"
ROLE_NAMES=(
  admin
  ops
  masterdata_truck
  masterdata_spbu
  planner_user
  vrp_user
  viewer
)
LOGIN_THEME_NAME="petrofin"

log() {
  printf '[keycloak-bootstrap] %s\n' "$1"
}

require_env() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    log "missing required environment variable: ${name}"
    exit 1
  fi
}

realm_exists() {
  /opt/keycloak/bin/kcadm.sh get "realms/${KEYCLOAK_REALM}" >/dev/null 2>&1
}

role_exists() {
  local role_name="$1"
  /opt/keycloak/bin/kcadm.sh get "roles/${role_name}" -r "${KEYCLOAK_REALM}" >/dev/null 2>&1
}

user_exists() {
  local username="$1"
  [ -n "$(get_user_internal_id "${username}")" ]
}

get_user_internal_id() {
  local username="$1"

  /opt/keycloak/bin/kcadm.sh get "users?exact=true&username=${username}&max=1" \
    -r "${KEYCLOAK_REALM}" \
    --fields id,username \
    | grep -oE '"id"[[:space:]]*:[[:space:]]*"[^"]+"' \
    | head -n 1 \
    | sed -E 's/"id"[[:space:]]*:[[:space:]]*"([^"]+)"/\1/' \
    || true
}

client_id_exists() {
  [ -n "$(get_client_internal_id "$1")" ]
}

get_client_internal_id() {
  local client_id="$1"

  /opt/keycloak/bin/kcadm.sh get "clients?clientId=${client_id}&max=1" \
    -r "${KEYCLOAK_REALM}" \
    --fields id,clientId \
    | grep -oE '"id"[[:space:]]*:[[:space:]]*"[^"]+"' \
    | head -n 1 \
    | sed -E 's/"id"[[:space:]]*:[[:space:]]*"([^"]+)"/\1/' \
    || true
}

wait_for_keycloak() {
  log "waiting for Keycloak at ${KEYCLOAK_SERVER_URL}"
  until /opt/keycloak/bin/kcadm.sh config credentials \
    --server "${KEYCLOAK_SERVER_URL}" \
    --realm master \
    --user "${KEYCLOAK_ADMIN}" \
    --password "${KEYCLOAK_ADMIN_PASSWORD}" >/dev/null 2>&1; do
    sleep 5
  done
}

create_realm() {
  if realm_exists; then
    log "realm ${KEYCLOAK_REALM} already exists"
    return
  fi

  log "creating realm ${KEYCLOAK_REALM}"
  /opt/keycloak/bin/kcadm.sh create realms \
    -s realm="${KEYCLOAK_REALM}" \
    -s enabled=true \
    -s displayName="VRP Platform" \
    -s loginTheme="${LOGIN_THEME_NAME}"
}

configure_realm_theme() {
  log "applying login theme ${LOGIN_THEME_NAME} to realm ${KEYCLOAK_REALM}"
  /opt/keycloak/bin/kcadm.sh update "realms/${KEYCLOAK_REALM}" \
    -s loginTheme="${LOGIN_THEME_NAME}" \
    -s displayName="VRP Platform"
}

sync_realm_settings() {
  local display_name="${KEYCLOAK_DISPLAY_NAME:-VRP Petrofin Platform}"
  local display_name_html="${KEYCLOAK_DISPLAY_NAME_HTML:-VRP <span>Petrofin Platform</span>}"
  local login_theme="${KEYCLOAK_LOGIN_THEME:-petrofin}"

  log "syncing realm presentation settings"
  /opt/keycloak/bin/kcadm.sh update "realms/${KEYCLOAK_REALM}" \
    -s displayName="${display_name}" \
    -s "displayNameHtml=${display_name_html}" \
    -s loginTheme="${login_theme}"
}

create_roles() {
  for role_name in "${ROLE_NAMES[@]}"; do
    if role_exists "${role_name}"; then
      log "role ${role_name} already exists"
      continue
    fi

    log "creating role ${role_name}"
    /opt/keycloak/bin/kcadm.sh create roles -r "${KEYCLOAK_REALM}" -s name="${role_name}"
  done
}

create_user() {
  local username="$1"
  local email="$2"
  local first_name="$3"
  local last_name="$4"

  if user_exists "${username}"; then
    log "user ${username} already exists"
    return
  fi

  log "creating user ${username}"
  /opt/keycloak/bin/kcadm.sh create users -r "${KEYCLOAK_REALM}" \
    -s username="${username}" \
    -s enabled=true \
    -s email="${email}" \
    -s firstName="${first_name}" \
    -s lastName="${last_name}" \
    -s emailVerified=true

  /opt/keycloak/bin/kcadm.sh set-password \
    -r "${KEYCLOAK_REALM}" \
    --username "${username}" \
    --new-password "${KEYCLOAK_SAMPLE_PASSWORD}"
}

assign_roles() {
  local username="$1"
  shift
  local roles=("$@")
  local user_id

  if [ "${#roles[@]}" -eq 0 ]; then
    return
  fi

  user_id="$(get_user_internal_id "${username}")"

  if [ -z "${user_id}" ]; then
    log "cannot assign roles to ${username}: user not found"
    exit 1
  fi

  log "ensuring roles for ${username}: ${roles[*]}"
  for role_name in "${roles[@]}"; do
    /opt/keycloak/bin/kcadm.sh add-roles \
      -r "${KEYCLOAK_REALM}" \
      --uid "${user_id}" \
      --rolename "${role_name}" >/dev/null 2>&1 || true
  done
}

write_client_file() {
  local client_id="$1"
  local root_url="$2"
  local output_file="$3"
  local redirect_url="${root_url}/oauth2/callback"
  local logout_redirect_url="${root_url}/oauth2/sign_in"

  cat > "${output_file}" <<EOF
{
  "clientId": "${client_id}",
  "name": "${client_id}",
  "enabled": true,
  "protocol": "openid-connect",
  "publicClient": false,
  "standardFlowEnabled": true,
  "directAccessGrantsEnabled": false,
  "serviceAccountsEnabled": false,
  "frontchannelLogout": true,
  "attributes": {
    "pkce.code.challenge.method": "S256",
    "post.logout.redirect.uris": "${logout_redirect_url}"
  },
  "secret": "${OAUTH2_PROXY_CLIENT_SECRET}",
  "redirectUris": [
    "${redirect_url}",
    "${logout_redirect_url}"
  ],
  "webOrigins": [
    "${root_url}"
  ],
  "rootUrl": "${root_url}",
  "baseUrl": "${root_url}"
}
EOF
}

create_client() {
  local client_id="$1"
  local root_url="$2"
  local client_file
  local existing_id

  client_file="$(mktemp)"
  write_client_file "${client_id}" "${root_url}" "${client_file}"

  existing_id="$(get_client_internal_id "${client_id}")"

  if [ -n "${existing_id}" ]; then
    log "updating client ${client_id}"
    /opt/keycloak/bin/kcadm.sh update "clients/${existing_id}" -r "${KEYCLOAK_REALM}" -f "${client_file}"
  else
    log "creating client ${client_id}"
    /opt/keycloak/bin/kcadm.sh create clients -r "${KEYCLOAK_REALM}" -f "${client_file}"
  fi

  rm -f "${client_file}"

  if ! client_id_exists "${client_id}"; then
    log "client ${client_id} was not found after bootstrap"
    exit 1
  fi

  log "client ${client_id} is ready"
}

main() {
  require_env KEYCLOAK_REALM
  require_env PLATFORM_PUBLIC_SCHEME
  require_env KEYCLOAK_ADMIN
  require_env KEYCLOAK_ADMIN_PASSWORD
  require_env KEYCLOAK_SAMPLE_PASSWORD
  require_env OAUTH2_PROXY_CLIENT_ID
  require_env OAUTH2_PROXY_CLIENT_SECRET
  require_env PORTAL_HOST
  require_env TRUCK_HOST
  require_env SPBU_HOST
  require_env PLANNER_HOST

  wait_for_keycloak
  create_realm
  sync_realm_settings
  create_roles

  create_user "alice.admin" "alice.admin@local.vrp" "Alice" "Admin"
  create_user "olivia.ops" "olivia.ops@local.vrp" "Olivia" "Ops"
  create_user "tom.truck" "tom.truck@local.vrp" "Tom" "Truck"
  create_user "sarah.spbu" "sarah.spbu@local.vrp" "Sarah" "SPBU"
  create_user "paula.planner" "paula.planner@local.vrp" "Paula" "Planner"
  create_user "victor.viewer" "victor.viewer@local.vrp" "Victor" "Viewer"

  assign_roles "alice.admin" admin ops vrp_user
  assign_roles "olivia.ops" ops vrp_user
  assign_roles "tom.truck" masterdata_truck vrp_user
  assign_roles "sarah.spbu" masterdata_spbu vrp_user
  assign_roles "paula.planner" planner_user
  assign_roles "victor.viewer" viewer

  create_client "${OAUTH2_PROXY_CLIENT_ID}-portal" "${PLATFORM_PUBLIC_SCHEME}://${PORTAL_HOST}${PLATFORM_PUBLIC_PORT_SUFFIX}"
  create_client "${OAUTH2_PROXY_CLIENT_ID}-truck" "${PLATFORM_PUBLIC_SCHEME}://${TRUCK_HOST}${PLATFORM_PUBLIC_PORT_SUFFIX}"
  create_client "${OAUTH2_PROXY_CLIENT_ID}-spbu" "${PLATFORM_PUBLIC_SCHEME}://${SPBU_HOST}${PLATFORM_PUBLIC_PORT_SUFFIX}"
  create_client "${OAUTH2_PROXY_CLIENT_ID}-planner" "${PLATFORM_PUBLIC_SCHEME}://${PLANNER_HOST}${PLATFORM_PUBLIC_PORT_SUFFIX}"

  log "bootstrap complete"
}

main "$@"
