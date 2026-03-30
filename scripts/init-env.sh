#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
EXAMPLE_FILE="${ROOT_DIR}/.env.example"

if [ -f "${ENV_FILE}" ]; then
  printf '.env already exists at %s\n' "${ENV_FILE}"
  exit 0
fi

admin_password="$(openssl rand -hex 16)"
db_password="$(openssl rand -hex 16)"
sample_password="LocalDev123!"
client_secret="$(openssl rand -hex 24)"
cookie_secret="$(openssl rand -base64 32 | tr -d '\n')"
database_url="postgresql+psycopg2://ferdeh:${db_password}@host.docker.internal:5432/ferdeh_lab"

while IFS= read -r line; do
  case "${line}" in
    KEYCLOAK_ADMIN_PASSWORD=*)
      printf 'KEYCLOAK_ADMIN_PASSWORD=%s\n' "${admin_password}"
      ;;
    KEYCLOAK_DB_PASSWORD=*)
      printf 'KEYCLOAK_DB_PASSWORD=%s\n' "${db_password}"
      ;;
    DATABASE_URL=*)
      printf 'DATABASE_URL=%s\n' "${database_url}"
      ;;
    POSTGRES_PASSWORD=*)
      printf 'POSTGRES_PASSWORD=%s\n' "${db_password}"
      ;;
    KEYCLOAK_SAMPLE_PASSWORD=*)
      printf 'KEYCLOAK_SAMPLE_PASSWORD=%s\n' "${sample_password}"
      ;;
    OAUTH2_PROXY_CLIENT_SECRET=*)
      printf 'OAUTH2_PROXY_CLIENT_SECRET=%s\n' "${client_secret}"
      ;;
    OAUTH2_PROXY_COOKIE_SECRET=*)
      printf 'OAUTH2_PROXY_COOKIE_SECRET=%s\n' "${cookie_secret}"
      ;;
    *)
      printf '%s\n' "${line}"
      ;;
  esac
done < "${EXAMPLE_FILE}" > "${ENV_FILE}"

printf 'Created %s\n' "${ENV_FILE}"
printf 'Sample user password: %s\n' "${sample_password}"
printf 'Edit .env if you want to switch to hosts-file mode or change ports.\n'
