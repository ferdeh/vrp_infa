#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ ! -f "${ROOT_DIR}/.env" ]; then
  printf '.env is missing. Run make init-env first.\n' >&2
  exit 1
fi

cd "${ROOT_DIR}"

if [ "$#" -gt 0 ] && [ -n "${1:-}" ]; then
  docker compose --env-file .env -f docker-compose.local.yml logs -f "$1"
else
  docker compose --env-file .env -f docker-compose.local.yml logs -f
fi
