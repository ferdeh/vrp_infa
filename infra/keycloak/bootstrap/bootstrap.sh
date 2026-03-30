#!/usr/bin/env bash
set -euo pipefail

KEYCLOAK_SERVER_URL="http://keycloak:8080"
ROLE_NAMES=(
  admin
  ops
  masterdata_truck
  masterdata_spbu
  dispatcher
  vrp_user
  viewer
)

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
  /opt/keycloak/bin/kcadm.sh get users -r "${KEYCLOAK_REALM}" -q "username=${username}" | grep -Eq "\"username\"[[:space:]]*:[[:space:]]*\"${username}\""
}

client_id_exists() {
  local client_id="$1"
  /opt/keycloak/bin/kcadm.sh get clients -r "${KEYCLOAK_REALM}" -q "clientId=${client_id}" | grep -Eq "\"clientId\"[[:space:]]*:[[:space:]]*\"${client_id}\""
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
    -s displayName="VRP Platform"
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

  if [ "${#roles[@]}" -eq 0 ]; then
    return
  fi

  log "assigning roles to ${username}: ${roles[*]}"
  for role_name in "${roles[@]}"; do
    /opt/keycloak/bin/kcadm.sh add-roles \
      -r "${KEYCLOAK_REALM}" \
      --uusername "${username}" \
      --rolename "${role_name}" >/dev/null 2>&1 || true
  done
}

write_client_file() {
  local client_id="$1"
  local redirect_url="$2"
  local root_url="$3"
  local output_file="$4"

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
    "pkce.code.challenge.method": "S256"
  },
  "secret": "${OAUTH2_PROXY_CLIENT_SECRET}",
  "redirectUris": [
    "${redirect_url}"
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
  local redirect_url="$2"
  local root_url="$3"
  local client_file

  client_file="$(mktemp)"
  write_client_file "${client_id}" "${redirect_url}" "${root_url}" "${client_file}"

  if client_id_exists "${client_id}"; then
    local existing_id
    existing_id="$(
      /opt/keycloak/bin/kcadm.sh get clients -r "${KEYCLOAK_REALM}" -q "clientId=${client_id}" \
      | tr -d '\n' | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
    )"
    log "updating client ${client_id}"
    /opt/keycloak/bin/kcadm.sh update "clients/${existing_id}" -r "${KEYCLOAK_REALM}" -f "${client_file}"
  else
    log "creating client ${client_id}"
    /opt/keycloak/bin/kcadm.sh create clients -r "${KEYCLOAK_REALM}" -f "${client_file}"
  fi

  rm -f "${client_file}"
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
  require_env DISPATCH_HOST

  wait_for_keycloak
  create_realm
  create_roles

  create_user "alice.admin" "alice.admin@local.vrp" "Alice" "Admin"
  create_user "olivia.ops" "olivia.ops@local.vrp" "Olivia" "Ops"
  create_user "tom.truck" "tom.truck@local.vrp" "Tom" "Truck"
  create_user "sarah.spbu" "sarah.spbu@local.vrp" "Sarah" "SPBU"
  create_user "david.dispatch" "david.dispatch@local.vrp" "David" "Dispatch"
  create_user "victor.viewer" "victor.viewer@local.vrp" "Victor" "Viewer"

  assign_roles "alice.admin" admin ops vrp_user
  assign_roles "olivia.ops" ops vrp_user
  assign_roles "tom.truck" masterdata_truck vrp_user
  assign_roles "sarah.spbu" masterdata_spbu vrp_user
  assign_roles "david.dispatch" dispatcher vrp_user
  assign_roles "victor.viewer" viewer

  create_client "${OAUTH2_PROXY_CLIENT_ID}-portal" "${PLATFORM_PUBLIC_SCHEME}://${PORTAL_HOST}${PLATFORM_PUBLIC_PORT_SUFFIX}/oauth2/callback" "${PLATFORM_PUBLIC_SCHEME}://${PORTAL_HOST}${PLATFORM_PUBLIC_PORT_SUFFIX}"
  create_client "${OAUTH2_PROXY_CLIENT_ID}-truck" "${PLATFORM_PUBLIC_SCHEME}://${TRUCK_HOST}${PLATFORM_PUBLIC_PORT_SUFFIX}/oauth2/callback" "${PLATFORM_PUBLIC_SCHEME}://${TRUCK_HOST}${PLATFORM_PUBLIC_PORT_SUFFIX}"
  create_client "${OAUTH2_PROXY_CLIENT_ID}-spbu" "${PLATFORM_PUBLIC_SCHEME}://${SPBU_HOST}${PLATFORM_PUBLIC_PORT_SUFFIX}/oauth2/callback" "${PLATFORM_PUBLIC_SCHEME}://${SPBU_HOST}${PLATFORM_PUBLIC_PORT_SUFFIX}"
  create_client "${OAUTH2_PROXY_CLIENT_ID}-dispatch" "${PLATFORM_PUBLIC_SCHEME}://${DISPATCH_HOST}${PLATFORM_PUBLIC_PORT_SUFFIX}/oauth2/callback" "${PLATFORM_PUBLIC_SCHEME}://${DISPATCH_HOST}${PLATFORM_PUBLIC_PORT_SUFFIX}"

  log "bootstrap complete"
}

main "$@"
