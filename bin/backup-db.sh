#!/bin/bash

# Database Backup Script
# Creates timestamped backups of PostgreSQL database before destructive operations

set -e

BACKUP_DIR="backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DB_NAME="${1:-app_development}"
BACKUP_FILE="$BACKUP_DIR/db_backup_${DB_NAME}_${TIMESTAMP}.sql"

# Create backups directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

echo "🔄 Starting database backup..."
echo "Database: $DB_NAME"
echo "Backup file: $BACKUP_FILE"

# Check if database container is running
if ! docker ps | grep -q sage-db; then
  echo "❌ Error: sage-db container is not running"
  exit 1
fi

# Perform the backup
docker exec sage-db-1 pg_dump -U postgres "$DB_NAME" > "$BACKUP_FILE"

if [ $? -eq 0 ]; then
  FILE_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
  echo "✅ Backup completed successfully!"
  echo "📦 File size: $FILE_SIZE"
  echo "📍 Location: $BACKUP_FILE"
  
  # Keep only the last 10 backups to save space
  BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/db_backup_${DB_NAME}_*.sql 2>/dev/null | wc -l)
  if [ "$BACKUP_COUNT" -gt 10 ]; then
    echo "🧹 Cleaning up old backups (keeping last 10)..."
    ls -1t "$BACKUP_DIR"/db_backup_${DB_NAME}_*.sql | tail -n +11 | xargs rm -f
  fi
else
  echo "❌ Backup failed!"
  exit 1
fi

