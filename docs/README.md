# Muallimus Soniy — Developer Guide

An Arabic learning book app (Ikkinchi Muallim) with a Flutter web frontend, FastAPI backend, and admin panel.

## Architecture

```
├── frontend/          # Flutter Web app (Dart)
├── backend/           # FastAPI + Celery (Python)
│   ├── app/           # Main application code
│   │   ├── api/       # REST endpoints (v1/book, v1/admin/*)
│   │   ├── models/    # SQLAlchemy ORM models
│   │   ├── schemas/   # Pydantic request/response schemas
│   │   ├── services/  # Business logic (audio, PDF, AI, Telegram)
│   │   ├── tasks/     # Celery async tasks
│   │   └── middleware/ # Request logging, rate limiting
│   ├── alembic/       # DB migrations
│   └── scripts/       # One-off maintenance scripts
├── admin/dist/        # Static admin panel (HTML/JS/CSS)
├── deploy/
│   ├── nginx/         # Nginx configs (sites/, sites-local/, sites-ssl/)
│   └── scripts/       # Deploy & backup scripts
└── docs/reference/    # Book PDF, page screenshots (dev reference only)
```

## Local Development

### Prerequisites
- Docker & Docker Compose

### Quick Start

```bash
# 1. Copy environment file
cp .env.example .env             # Edit passwords/secrets as needed

# 2. Start all services (API, worker, DB, Redis, Nginx)
make up-local
# or: docker compose -f docker-compose.yml -f docker-compose.override.yml up -d

# 3. Run database migrations
make migrate

# 4. View logs
make logs
```

### Services (local)
| Service | URL |
|---------|-----|
| Flutter Web | http://localhost:8888 |
| Admin Panel | http://localhost:8888/admin/ |
| API Docs | http://localhost:8888/api/v1 (proxied) |
| API Direct | http://localhost:8001 |
| Health Check | http://localhost:8888/health |

## Production Deployment

### First-Time Setup
```bash
# On your server:
cp .env.production.example .env  # Fill in real passwords
bash deploy/scripts/deploy-init.sh
```

### Routine Deploy
```bash
docker compose build
docker compose up -d
docker compose exec api alembic upgrade head
```

### Production URLs
| Service | URL |
|---------|-----|
| Web | https://ikkinchimuallim.codingtech.uz |
| API | https://api.ikkinchimuallim.codingtech.uz |
| Admin | https://ikkinchimuallim.codingtech.uz/admin/ |

## Key Commands (Makefile)

| Command | Description |
|---------|-------------|
| `make up` | Start services (production) |
| `make up-local` | Start with local dev overrides |
| `make down` | Stop all services |
| `make build` | Rebuild Docker images |
| `make logs` | Tail all logs |
| `make logs-api` | Tail API logs only |
| `make migrate` | Run DB migrations |
| `make seed` | Seed initial data |
| `make backup` | Backup database |
| `make restore file=backup.sql` | Restore from backup |

## Environment Variables

All config is in `.env` — see `.env.example` for local dev values and `.env.production.example` for production values. Key variables:

- `DATABASE_URL` — PostgreSQL connection string
- `REDIS_URL` — Redis for caching
- `ADMIN_USERNAME` / `ADMIN_PASSWORD` — Admin panel credentials
- `JWT_SECRET_KEY` — Secret for JWT tokens
- `API_BASE_URL` / `MEDIA_BASE_URL` — Base URLs for API and media
- `ENVIRONMENT` — `development` or `production`
