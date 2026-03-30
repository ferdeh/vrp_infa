#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ ! -f "${ROOT_DIR}/.env" ]; then
  "${ROOT_DIR}/scripts/init-env.sh"
fi

cd "${ROOT_DIR}"
docker compose --env-file .env -f docker-compose.local.yml up -d --remove-orphans
"${ROOT_DIR}/scripts/show-urls.sh"
