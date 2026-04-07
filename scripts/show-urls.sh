#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ ! -f "${ROOT_DIR}/.env" ]; then
  printf '.env is missing. Run make init-env first.\n' >&2
  exit 1
fi

set -a
. "${ROOT_DIR}/.env"
set +a

printf 'Portal:   %s://%s%s\n' "${PLATFORM_PUBLIC_SCHEME}" "${PORTAL_HOST}" "${PLATFORM_PUBLIC_PORT_SUFFIX}"
printf 'Auth:     %s://%s%s\n' "${PLATFORM_PUBLIC_SCHEME}" "${KEYCLOAK_HOST}" "${PLATFORM_PUBLIC_PORT_SUFFIX}"
printf 'Truck:    %s://%s%s\n' "${PLATFORM_PUBLIC_SCHEME}" "${TRUCK_HOST}" "${PLATFORM_PUBLIC_PORT_SUFFIX}"
printf 'SPBU:     %s://%s%s\n' "${PLATFORM_PUBLIC_SCHEME}" "${SPBU_HOST}" "${PLATFORM_PUBLIC_PORT_SUFFIX}"
printf 'Planner:  %s://%s%s\n' "${PLATFORM_PUBLIC_SCHEME}" "${PLANNER_HOST}" "${PLATFORM_PUBLIC_PORT_SUFFIX}"
printf 'Traefik:  http://localhost:%s/dashboard/\n' "${TRAEFIK_DASHBOARD_PORT:-8081}"
