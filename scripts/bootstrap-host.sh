#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run this script as root or via sudo." >&2
  exit 1
fi

STACK_ROOT=${STACK_ROOT:-/home/ferdeh/vrp-workspace/vrp_infa}
SSH_PORT=${SSH_PORT:-22}
SSH_ALLOW_CIDR=${SSH_ALLOW_CIDR:-0.0.0.0/0}
DEPLOY_USER=${DEPLOY_USER:-ferdeh}

install_base_packages() {
  apt-get update
  apt-get install -y ca-certificates curl gnupg lsb-release ufw fail2ban jq
}

install_docker() {
  install -d -m 0755 /etc/apt/keyrings
  if [[ ! -f /etc/apt/keyrings/docker.asc ]]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
  fi

  cat >/etc/apt/sources.list.d/docker.list <<EOF
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${VERSION_CODENAME}") stable
EOF

  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
  usermod -aG docker "${DEPLOY_USER}"
}

configure_firewall() {
  ufw --force reset
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow "${SSH_PORT}"/tcp comment "SSH"
  if [[ "${SSH_ALLOW_CIDR}" != "0.0.0.0/0" ]]; then
    ufw --force delete allow "${SSH_PORT}"/tcp || true
    ufw allow from "${SSH_ALLOW_CIDR}" to any port "${SSH_PORT}" proto tcp comment "SSH restricted"
  fi
  ufw allow 80/tcp comment "HTTP"
  ufw allow 443/tcp comment "HTTPS"
  ufw --force enable
}

configure_fail2ban() {
  install -d -m 0755 /etc/fail2ban
  cat >/etc/fail2ban/jail.d/sshd-local.conf <<EOF
[sshd]
enabled = true
port = ${SSH_PORT}
maxretry = 5
findtime = 10m
bantime = 1h
EOF
  systemctl enable --now fail2ban
  systemctl restart fail2ban
}

prepare_runtime_dirs() {
  install -d -m 0755 -o "${DEPLOY_USER}" -g "${DEPLOY_USER}" "${STACK_ROOT}/.runtime/traefik"
  install -m 0600 -o "${DEPLOY_USER}" -g "${DEPLOY_USER}" /dev/null "${STACK_ROOT}/.runtime/traefik/acme.json"
}

main() {
  install_base_packages
  install_docker
  configure_firewall
  configure_fail2ban
  prepare_runtime_dirs

  cat <<EOF
Host bootstrap selesai.

Tindak lanjut:
1. Logout/login ulang agar group docker aktif untuk user ${DEPLOY_USER}.
2. Salin ${STACK_ROOT}/.env.prod.example menjadi ${STACK_ROOT}/.env.prod lalu isi secret production.
3. Jalankan ${STACK_ROOT}/scripts/install-systemd.sh
4. Jalankan ${STACK_ROOT}/scripts/deploy-production.sh
EOF
}

main "$@"
