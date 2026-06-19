#!/bin/bash
# ─────────────────────────────────────────────────────────────
# MusicNation — System Monitor Script
# Logs CPU, memory, disk, and API health metrics
# Usage: ./scripts/monitor.sh
# Cron: */5 * * * * /path/to/scripts/monitor.sh >> /var/log/musicnation-monitor.log 2>&1
# ─────────────────────────────────────────────────────────────

TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
LOG_FILE="/var/log/musicnation-monitor.log"
ALERT_THRESHOLD_CPU=85
ALERT_THRESHOLD_MEM=90
ALERT_THRESHOLD_DISK=80

echo "═══════════════════════════════════════"
echo "MusicNation Monitor — ${TIMESTAMP}"
echo "═══════════════════════════════════════"

# CPU Usage
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 | tr -d ' ')
echo "CPU Usage:    ${CPU_USAGE}%"
if (( $(echo "${CPU_USAGE} > ${ALERT_THRESHOLD_CPU}" | bc -l) )); then
  echo "  ⚠️  ALERT: CPU above ${ALERT_THRESHOLD_CPU}%"
fi

# Memory Usage
MEM_TOTAL=$(free -m | awk '/^Mem:/{print $2}')
MEM_USED=$(free -m | awk '/^Mem:/{print $3}')
MEM_PCT=$(echo "scale=1; ${MEM_USED}*100/${MEM_TOTAL}" | bc)
echo "Memory:       ${MEM_USED}MB / ${MEM_TOTAL}MB (${MEM_PCT}%)"
if (( $(echo "${MEM_PCT} > ${ALERT_THRESHOLD_MEM}" | bc -l) )); then
  echo "  ⚠️  ALERT: Memory above ${ALERT_THRESHOLD_MEM}%"
fi

# Disk Usage
DISK_PCT=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
echo "Disk:         ${DISK_USED} / ${DISK_TOTAL} (${DISK_PCT}%)"
if [ "${DISK_PCT}" -gt "${ALERT_THRESHOLD_DISK}" ]; then
  echo "  ⚠️  ALERT: Disk above ${ALERT_THRESHOLD_DISK}%"
fi

# Process check
API_PID=$(pgrep -f "python.*app.py" || echo "")
if [ -n "${API_PID}" ]; then
  echo "Flask API:    RUNNING (PID: ${API_PID})"
else
  echo "Flask API:    ✗ NOT RUNNING — attempting restart..."
  sudo systemctl restart musicnation-api 2>/dev/null || true
fi

NGINX_STATUS=$(systemctl is-active nginx 2>/dev/null || echo "inactive")
echo "Nginx:        ${NGINX_STATUS^^}"

# API Health check
HEALTH=$(curl -s --max-time 5 http://localhost:5001/health 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','fail'))" 2>/dev/null || echo "unreachable")
echo "API Health:   ${HEALTH}"

# Active connections
CONNECTIONS=$(ss -t | grep ':5001' | wc -l 2>/dev/null || echo "0")
echo "Connections:  ${CONNECTIONS} active on port 5001"

echo ""
