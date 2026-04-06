#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/.env.prod}"
COMPOSE_FILE="${COMPOSE_FILE:-${ROOT_DIR}/docker-compose.prod.yml}"

require_file() {
  local path=$1
  if [[ ! -f "${path}" ]]; then
    echo "Required file not found: ${path}" >&2
    exit 1
  fi
}

require_binary() {
  local name=$1
  if ! command -v "${name}" >/dev/null 2>&1; then
    echo "Required binary not found: ${name}" >&2
    exit 1
  fi
}

main() {
  require_binary docker
  require_file "${ENV_FILE}"
  require_file "${COMPOSE_FILE}"

  install -d -m 0755 "${ROOT_DIR}/.runtime/traefik"
  if [[ ! -f "${ROOT_DIR}/.runtime/traefik/acme.json" ]]; then
    install -m 0600 /dev/null "${ROOT_DIR}/.runtime/traefik/acme.json"
  fi

  docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" config >/dev/null
  docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" up -d --build --remove-orphans
  docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" ps
}

main "$@"
