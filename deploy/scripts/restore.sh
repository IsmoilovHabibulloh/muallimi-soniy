#!/bin/bash
# Restore from backup
# Usage: ./restore.sh db_20260215_030000.sql.gz [media_20260215_030000.tar.gz]

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <db_backup.sql.gz> [media_backup.tar.gz]"
    exit 1
fi

BACKUP_DIR="/var/www/ikkinchimuallim/backups"
DB_BACKUP="$BACKUP_DIR/$1"

echo "=== Restore started ==="

# Restore database
if [ -f "$DB_BACKUP" ]; then
    echo "Restoring database from $DB_BACKUP..."
    gunzip -c "$DB_BACKUP" | docker compose -f /var/www/ikkinchimuallim/docker-compose.yml exec -T postgres \
        psql -U muallimi muallimi_soniy
    echo "Database restored."
else
    echo "ERROR: Database backup file not found: $DB_BACKUP"
    exit 1
fi

# Restore media (optional)
if [ $# -ge 2 ]; then
    MEDIA_BACKUP="$BACKUP_DIR/$2"
    if [ -f "$MEDIA_BACKUP" ]; then
        echo "Restoring media from $MEDIA_BACKUP..."
        tar -xzf "$MEDIA_BACKUP" -C /var/www/ikkinchimuallim/
        echo "Media restored."
    else
        echo "WARNING: Media backup file not found: $MEDIA_BACKUP"
    fi
fi

echo "=== Restore completed ==="
echo "Restart services: docker compose restart api worker"
