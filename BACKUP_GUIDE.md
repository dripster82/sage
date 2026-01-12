# Database Backup & Restore Guide

This guide explains how to backup and restore your Sage database.

## Automatic Backups

The `dip provision` command now **automatically creates a backup** before wiping the database. This ensures you have a recovery point if something goes wrong.

## Manual Backup

To manually backup your database:

```bash
dip backup
```

This creates a timestamped SQL dump in the `backups/` directory:
```
backups/db_backup_app_development_20260112_110530.sql
```

## Viewing Available Backups

```bash
ls -lh backups/
```

## Restoring from a Backup

To restore your database from a backup:

```bash
./bin/restore-db.sh backups/db_backup_app_development_20260112_110530.sql
```

Or use the dip command:

```bash
dip restore backups/db_backup_app_development_20260112_110530.sql
```

The script will:
1. Ask for confirmation (to prevent accidental overwrites)
2. Drop the existing database
3. Create a new database
4. Restore from the backup file

## Backup Retention

The backup script automatically keeps only the **last 10 backups** to save disk space. Older backups are automatically deleted.

## Important Notes

- ⚠️ Backups are stored locally in the `backups/` directory and are **NOT committed to git**
- 💾 For long-term storage, consider copying important backups to cloud storage or external drives
- 🔄 Always backup before running `dip provision`
- ✅ Test your backups periodically to ensure they can be restored

## Backup File Format

Backups are PostgreSQL SQL dumps created with `pg_dump`. They contain:
- Database schema (tables, indexes, constraints)
- All data (rows)
- Sequences and other database objects

## Troubleshooting

**Backup fails with "container is not running"**
- Make sure the database container is running: `dip compose up -d db`

**Restore fails**
- Ensure the backup file exists and is readable
- Check that the database container is running
- Verify you have enough disk space

**Need to restore a specific database**
- By default, backups/restores use `app_development`
- To backup a different database: `./bin/backup-db.sh app_test`
- To restore to a different database: `./bin/restore-db.sh <backup_file> app_test`

