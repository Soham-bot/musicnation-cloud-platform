#!/bin/bash
# ─────────────────────────────────────────────────────────────
# MusicNation — Deployment Script
# Pulls latest code from Git and restarts services
# Usage: ./scripts/deploy.sh
# Run on EC2: bash deploy.sh
# ─────────────────────────────────────────────────────────────

set -euo pipefail

APP_DIR="/home/ubuntu/musicnation-cloud-platform"
LOG_PREFIX="[MusicNation Deploy]"
BRANCH="${1:-main}"

echo "${LOG_PREFIX} Starting deployment at $(date)"
echo "${LOG_PREFIX} Branch: ${BRANCH}"

# Pull latest code from Git
echo "${LOG_PREFIX} Pulling latest code..."
cd "${APP_DIR}"
git fetch origin
git checkout "${BRANCH}"
git pull origin "${BRANCH}"
echo "${LOG_PREFIX} Code updated to: $(git log -1 --format='%h %s')"

# Install/update Python dependencies
echo "${LOG_PREFIX} Installing dependencies..."
pip3 install -r app/requirements.txt --quiet

# Restart Flask service via systemctl
echo "${LOG_PREFIX} Restarting musicnation-api service..."
sudo systemctl restart musicnation-api
sudo systemctl restart nginx

# Verify services are running
sleep 3
if systemctl is-active --quiet musicnation-api; then
  echo "${LOG_PREFIX} ✓ musicnation-api is running"
else
  echo "${LOG_PREFIX} ✗ ERROR: musicnation-api failed to start"
  sudo journalctl -u musicnation-api --no-pager -n 20
  exit 1
fi

if systemctl is-active --quiet nginx; then
  echo "${LOG_PREFIX} ✓ nginx is running"
else
  echo "${LOG_PREFIX} ✗ ERROR: nginx failed to start"
  exit 1
fi

# Quick health check
HEALTH=$(curl -s http://localhost:5001/health | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','fail'))" 2>/dev/null || echo "fail")
if [ "${HEALTH}" = "ok" ]; then
  echo "${LOG_PREFIX} ✓ Health check passed"
else
  echo "${LOG_PREFIX} ✗ Health check failed — response: ${HEALTH}"
  exit 1
fi

echo "${LOG_PREFIX} Deployment completed successfully at $(date)"
