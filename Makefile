SHELL := /bin/bash
COMPOSE_LOCAL := docker compose --env-file .env -f docker-compose.local.yml
COMPOSE_PROD_EXAMPLE := docker compose --env-file .env -f docker-compose.prod.example.yml

.PHONY: init-env up down restart logs ps reset urls config config-prod bootstrap-keycloak

init-env:
	./scripts/init-env.sh

up: init-env
	./scripts/start-local.sh

down:
	$(COMPOSE_LOCAL) down --remove-orphans

restart:
	$(COMPOSE_LOCAL) down --remove-orphans
	./scripts/start-local.sh

logs:
	./scripts/logs.sh $(service)

ps:
	$(COMPOSE_LOCAL) ps

reset:
	./scripts/reset-local.sh

urls:
	./scripts/show-urls.sh

config:
	$(COMPOSE_LOCAL) config >/dev/null

config-prod:
	$(COMPOSE_PROD_EXAMPLE) config >/dev/null

bootstrap-keycloak:
	$(COMPOSE_LOCAL) run --rm keycloak-bootstrap
