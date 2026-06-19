#!/bin/bash
# ─────────────────────────────────────────────────────────────
# MusicNation — Automated Backup Script
# Backs up MySQL database and uploads to S3
# Usage: ./scripts/backup.sh
# Cron: 0 2 * * * /path/to/scripts/backup.sh >> /var/log/musicnation-backup.log 2>&1
# ─────────────────────────────────────────────────────────────

set -euo pipefail

# Config
DB_HOST="${MYSQL_HOST:-localhost}"
DB_USER="${MYSQL_USER:-musicnation}"
DB_PASS="${MYSQL_PASSWORD:-musicnation123}"
DB_NAME="${MYSQL_DB:-musicnation_db}"
S3_BUCKET="musicnation-tracks"
BACKUP_DIR="/tmp/musicnation-backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="musicnation_db_${TIMESTAMP}.sql.gz"
LOG_PREFIX="[MusicNation Backup]"

echo "${LOG_PREFIX} Starting backup at $(date)"

# Create backup directory
mkdir -p "${BACKUP_DIR}"

# Dump MySQL database and compress
echo "${LOG_PREFIX} Dumping database: ${DB_NAME}"
mysqldump \
  -h "${DB_HOST}" \
  -u "${DB_USER}" \
  -p"${DB_PASS}" \
  --single-transaction \
  --routines \
  --triggers \
  "${DB_NAME}" | gzip > "${BACKUP_DIR}/${BACKUP_FILE}"

BACKUP_SIZE=$(du -sh "${BACKUP_DIR}/${BACKUP_FILE}" | cut -f1)
echo "${LOG_PREFIX} Backup created: ${BACKUP_FILE} (${BACKUP_SIZE})"

# Upload to S3
echo "${LOG_PREFIX} Uploading to S3: s3://${S3_BUCKET}/backups/${BACKUP_FILE}"
aws s3 cp \
  "${BACKUP_DIR}/${BACKUP_FILE}" \
  "s3://${S3_BUCKET}/backups/${BACKUP_FILE}" \
  --region us-east-1

echo "${LOG_PREFIX} Upload complete"

# Clean up local backup older than 7 days
find "${BACKUP_DIR}" -name "*.sql.gz" -mtime +7 -delete
echo "${LOG_PREFIX} Cleaned up old local backups"

# Keep only last 30 backups in S3
echo "${LOG_PREFIX} Pruning old S3 backups (keeping last 30)..."
aws s3 ls "s3://${S3_BUCKET}/backups/" \
  | sort \
  | head -n -30 \
  | awk '{print $4}' \
  | xargs -I{} aws s3 rm "s3://${S3_BUCKET}/backups/{}" || true

echo "${LOG_PREFIX} Backup completed successfully at $(date)"
echo "─────────────────────────────────────────"
