#!/bin/bash

# Database Restore Script
# Restores a PostgreSQL database from a backup file

set -e

BACKUP_DIR="backups"

if [ -z "$1" ]; then
  echo "Usage: ./bin/restore-db.sh <backup_file>"
  echo ""
  echo "Available backups:"
  ls -lh "$BACKUP_DIR"/db_backup_*.sql 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
  exit 1
fi

BACKUP_FILE="$1"
DB_NAME="${2:-app_development}"

if [[ ! "$DB_NAME" =~ ^[A-Za-z0-9_]+$ ]]; then
  echo "❌ Error: Invalid database name: $DB_NAME"
  exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
  echo "❌ Error: Backup file not found: $BACKUP_FILE"
  exit 1
fi

echo "⚠️  WARNING: This will overwrite the current database!"
echo "Database: $DB_NAME"
echo "Backup file: $BACKUP_FILE"
echo ""
read -p "Are you sure you want to restore? (yes/no): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
  echo "Restore cancelled."
  exit 0
fi

# Check if database container is running
if ! dip compose ps -q db >/dev/null 2>&1; then
  echo "❌ Error: db service is not running"
  exit 1
fi

echo "🔄 Dropping existing database..."
dip compose exec -T db psql -U postgres -d postgres <<SQL
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = '$DB_NAME'
  AND pid <> pg_backend_pid();
DROP DATABASE IF EXISTS "$DB_NAME";
SQL

echo "🔄 Creating new database..."
dip compose exec -T db psql -U postgres -d postgres <<SQL
CREATE DATABASE "$DB_NAME";
SQL

echo "🔄 Restoring from backup..."
dip compose exec -T db psql -U postgres "$DB_NAME" < "$BACKUP_FILE"

if [ $? -eq 0 ]; then
  echo "✅ Restore completed successfully!"
  echo "Database: $DB_NAME"
else
  echo "❌ Restore failed!"
  exit 1
fi
