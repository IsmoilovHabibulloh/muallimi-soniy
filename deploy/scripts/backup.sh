#!/bin/bash
# Backup script for PostgreSQL + media files
# Usage: ./backup.sh
# Schedule with cron: 0 3 * * * /path/to/deploy/scripts/backup.sh

set -euo pipefail

# Resolve project root relative to this script's location
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
BACKUP_DIR="$PROJECT_DIR/backups"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

mkdir -p "$BACKUP_DIR"

echo "=== Backup started: $DATE ==="

# PostgreSQL dump
echo "Backing up PostgreSQL..."
docker compose -f "$PROJECT_DIR/docker-compose.yml" exec -T postgres \
    pg_dump -U muallimi muallimi_soniy | gzip > "$BACKUP_DIR/db_$DATE.sql.gz"
echo "Database backup: $BACKUP_DIR/db_$DATE.sql.gz"

# Media files
echo "Backing up media files..."
tar -czf "$BACKUP_DIR/media_$DATE.tar.gz" \
    -C "$PROJECT_DIR" \
    --exclude='media/uploads/normalized_*' \
    media/ 2>/dev/null || true
echo "Media backup: $BACKUP_DIR/media_$DATE.tar.gz"

# Clean old backups
echo "Cleaning backups older than $RETENTION_DAYS days..."
find "$BACKUP_DIR" -name "*.gz" -mtime +$RETENTION_DAYS -delete

echo "=== Backup completed: $(date) ==="

