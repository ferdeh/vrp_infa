#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE_SRC="${ROOT_DIR}/infra/systemd/vrp-platform.service"
SERVICE_DST="/etc/systemd/system/vrp-platform.service"

if [[ ${EUID} -ne 0 ]]; then
  echo "Run this script as root or via sudo." >&2
  exit 1
fi

install -D -m 0644 "${SERVICE_SRC}" "${SERVICE_DST}"
systemctl daemon-reload
systemctl enable vrp-platform.service

echo "Systemd unit installed at ${SERVICE_DST}"
echo "Use: systemctl start vrp-platform.service"
