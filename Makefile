.PHONY: up down build logs migrate seed test lint clean

# Development
up:
	docker compose up -d

up-local:
	docker compose -f docker-compose.yml -f docker-compose.override.yml up -d

down:
	docker compose down

build:
	docker compose build

logs:
	docker compose logs -f

logs-api:
	docker compose logs -f api

logs-worker:
	docker compose logs -f worker

# Database
migrate:
	docker compose exec api alembic upgrade head

migrate-new:
	docker compose exec api alembic revision --autogenerate -m "$(msg)"

seed:
	docker compose exec api python -m app.seed

# Testing
test:
	docker compose exec api pytest tests/ -v --cov=app

# Backup
backup:
	./deploy/scripts/backup.sh

restore:
	./deploy/scripts/restore.sh $(file)

# Clean
clean:
	docker compose down -v --remove-orphans
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
