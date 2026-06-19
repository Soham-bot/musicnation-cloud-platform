#!/bin/bash
# ─────────────────────────────────────────────────────────────
# MusicNation — Cron Job Setup Script
# Installs all automated tasks for the platform
# Usage: sudo bash scripts/setup_cron.sh
# ─────────────────────────────────────────────────────────────

APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CRON_FILE="/tmp/musicnation-cron"

echo "[Cron Setup] Installing MusicNation cron jobs from: ${APP_DIR}"

# Make all scripts executable
chmod +x "${APP_DIR}/scripts/"*.sh

# Write cron entries
cat > "${CRON_FILE}" << EOF
# MusicNation Platform — Automated Tasks
# ─────────────────────────────────────────

# Database backup — every day at 2:00 AM
0 2 * * * ${APP_DIR}/scripts/backup.sh >> /var/log/musicnation-backup.log 2>&1

# System monitor — every 5 minutes
*/5 * * * * ${APP_DIR}/scripts/monitor.sh >> /var/log/musicnation-monitor.log 2>&1

# Log rotation — weekly on Sunday at 3:00 AM
0 3 * * 0 find /var/log -name "musicnation-*.log" -size +50M -exec gzip {} \;

# S3 presigned URL cache refresh — every 50 minutes (before 1hr expiry)
*/50 * * * * curl -s http://localhost:5001/catalog > /dev/null 2>&1

EOF

# Install the crontab
crontab "${CRON_FILE}"
rm "${CRON_FILE}"

echo "[Cron Setup] ✓ Cron jobs installed:"
crontab -l
