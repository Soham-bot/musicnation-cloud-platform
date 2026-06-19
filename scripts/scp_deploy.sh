#!/bin/bash
# ─────────────────────────────────────────────────────────────
# MusicNation — SCP File Transfer & Remote Deployment Script
# Transfers files to EC2 via SCP and restarts services via SSH
# Usage: bash scripts/scp_deploy.sh
# ─────────────────────────────────────────────────────────────

set -euo pipefail

# ── Config — edit these ───────────────────────────────────────
EC2_HOST="3.108.56.235"
EC2_USER="ubuntu"
PEM_KEY="~/.ssh/musicnation-key.pem"
REMOTE_DIR="/home/ubuntu/musicnation-cloud-platform"
LOCAL_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "[SCP Deploy] Starting transfer to ${EC2_USER}@${EC2_HOST}"
echo "[SCP Deploy] Local:  ${LOCAL_DIR}"
echo "[SCP Deploy] Remote: ${REMOTE_DIR}"

# ── Step 1: Transfer application files via SCP ────────────────
echo "[SCP Deploy] Uploading app/app.py..."
scp -i "${PEM_KEY}" -o StrictHostKeyChecking=no \
    "${LOCAL_DIR}/app/app.py" \
    "${EC2_USER}@${EC2_HOST}:${REMOTE_DIR}/app/app.py"

echo "[SCP Deploy] Uploading app/requirements.txt..."
scp -i "${PEM_KEY}" \
    "${LOCAL_DIR}/app/requirements.txt" \
    "${EC2_USER}@${EC2_HOST}:${REMOTE_DIR}/app/requirements.txt"

echo "[SCP Deploy] Uploading index.html..."
scp -i "${PEM_KEY}" \
    "${LOCAL_DIR}/index.html" \
    "${EC2_USER}@${EC2_HOST}:${REMOTE_DIR}/index.html"

echo "[SCP Deploy] Uploading nginx config..."
scp -i "${PEM_KEY}" \
    "${LOCAL_DIR}/nginx/nginx.conf" \
    "${EC2_USER}@${EC2_HOST}:${REMOTE_DIR}/nginx/nginx.conf"

echo "[SCP Deploy] Uploading scripts..."
scp -i "${PEM_KEY}" -r \
    "${LOCAL_DIR}/scripts/" \
    "${EC2_USER}@${EC2_HOST}:${REMOTE_DIR}/"

# ── Step 2: Remote commands via SSH ──────────────────────────
echo "[SCP Deploy] Running remote setup..."
ssh -i "${PEM_KEY}" "${EC2_USER}@${EC2_HOST}" << 'REMOTE'
  set -e
  cd /home/ubuntu/musicnation-cloud-platform

  echo "[Remote] Installing Python dependencies..."
  pip3 install -r app/requirements.txt --quiet

  echo "[Remote] Applying DB schema..."
  mysql -u musicnation -pmusicnation123 musicnation_db < scripts/db/schema.sql 2>/dev/null || true

  echo "[Remote] Copying Nginx config..."
  sudo cp nginx/nginx.conf /etc/nginx/nginx.conf
  sudo nginx -t && sudo systemctl reload nginx

  echo "[Remote] Restarting Flask service..."
  sudo systemctl restart musicnation-api

  echo "[Remote] Health check..."
  sleep 2
  curl -s http://localhost:5001/health | python3 -c "import sys,json; d=json.load(sys.stdin); print('API:', d['status'], '| DB:', d['db'])"

  echo "[Remote] Done!"
REMOTE

echo "[SCP Deploy] Deployment complete at $(date)"
