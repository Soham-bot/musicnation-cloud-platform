# MusicNation — Linux Administration & Package Management

This document covers all Linux administration procedures for the MusicNation EC2 server running **Ubuntu 22.04 LTS**.

---

## 1. Initial Server Setup — User & Group Management

```bash
# Create dedicated application user (no login shell)
sudo useradd -r -s /bin/false musicnation

# Create application group
sudo groupadd musicnation-app

# Add ubuntu user to group
sudo usermod -aG musicnation-app ubuntu

# Set application directory ownership
sudo chown -R ubuntu:musicnation-app /home/ubuntu/musicnation-cloud-platform
sudo chmod -R 750 /home/ubuntu/musicnation-cloud-platform

# Verify
id ubuntu
ls -la /home/ubuntu/musicnation-cloud-platform
```

---

## 2. Package Management (apt)

```bash
# Update package index
sudo apt-get update

# Upgrade all packages
sudo apt-get upgrade -y

# Install required system packages
sudo apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    nginx \
    mysql-server \
    mysql-client \
    git \
    curl \
    htop \
    net-tools \
    ufw \
    docker.io \
    docker-compose-plugin

# Enable Docker
sudo systemctl enable docker
sudo usermod -aG docker ubuntu

# Verify installations
python3 --version
nginx -v
mysql --version
docker --version
```

---

## 3. Python Package Management (pip)

```bash
# Create virtual environment
cd /home/ubuntu/musicnation-cloud-platform
python3 -m venv venv
source venv/bin/activate

# Install application dependencies
pip install -r app/requirements.txt

# List installed packages
pip list

# Freeze current versions
pip freeze > app/requirements.txt
```

---

## 4. File Permissions

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Secure the .env / credential files
chmod 600 ~/.aws/credentials

# Application files — readable by group
chmod 644 app/app.py
chmod 644 index.html

# Logs directory
sudo mkdir -p /var/log/musicnation
sudo chown ubuntu:musicnation-app /var/log/musicnation
chmod 755 /var/log/musicnation
```

---

## 5. Process Monitoring

```bash
# View running processes
ps aux | grep python

# Check Flask API process
pgrep -a -f "python.*app.py"

# Monitor in real time
htop

# Check port 5001 listener
ss -tlnp | grep 5001

# View systemd service status
sudo systemctl status musicnation-api
sudo systemctl status nginx
sudo systemctl status mysql

# View last 50 log lines
sudo journalctl -u musicnation-api -n 50 --no-pager
sudo journalctl -u nginx -n 50 --no-pager
```

---

## 6. System Logs

```bash
# Application logs
sudo tail -f /var/log/musicnation/app.log

# Nginx access + error logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# MySQL logs
sudo tail -f /var/log/mysql/error.log

# System auth log (SSH access)
sudo tail -f /var/log/auth.log

# Monitor script output
tail -f /var/log/musicnation-monitor.log
tail -f /var/log/musicnation-backup.log
```

---

## 7. Firewall Rules (UFW)

```bash
# Enable firewall
sudo ufw enable

# Allow SSH (always first to avoid lockout)
sudo ufw allow 22/tcp

# Allow HTTP and HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow Flask API (internal only — from Nginx)
# Do NOT open 5001 to the internet
# sudo ufw allow from 127.0.0.1 to any port 5001

# Allow MySQL only from localhost
sudo ufw deny 3306

# Check status
sudo ufw status verbose
```

---

## 8. Cron Jobs

```bash
# Install MusicNation cron jobs
bash scripts/setup_cron.sh

# View active cron jobs
crontab -l

# Edit cron manually
crontab -e

# Active jobs:
# 0 2 * * *    — Daily DB backup to S3 at 2AM
# */5 * * * *  — System monitor every 5 minutes
# */50 * * * * — S3 presigned URL cache refresh
# 0 3 * * 0   — Weekly log rotation
```

---

## 9. Troubleshooting

```bash
# API not responding
sudo systemctl restart musicnation-api
curl http://localhost:5001/health

# Nginx 502 Bad Gateway
sudo systemctl status musicnation-api  # check if Flask is running
sudo nginx -t                           # check config syntax
sudo systemctl reload nginx

# MySQL connection refused
sudo systemctl status mysql
sudo systemctl start mysql
mysql -u musicnation -pmusicnation123 musicnation_db -e "SELECT 1;"

# Disk full
df -h
du -sh /var/log/* | sort -hr | head -10
sudo journalctl --vacuum-size=500M

# High CPU
top -bn1 | head -20
ps aux --sort=-%cpu | head -10
```
