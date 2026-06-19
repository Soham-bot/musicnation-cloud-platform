# 🎵 MusicNation Digital Music Cloud Platform

[![AWS](https://img.shields.io/badge/AWS-Cloud_Infrastructure-FF9900?style=for-the-badge&logo=amazon-aws&logoColor=white)](https://aws.amazon.com/)
[![Python](https://img.shields.io/badge/Python-3.11-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://python.org)
[![Flask](https://img.shields.io/badge/Flask-3.1-000000?style=for-the-badge&logo=flask&logoColor=white)](https://flask.palletsprojects.com/)
[![MySQL](https://img.shields.io/badge/MySQL-8.0-4479A1?style=for-the-badge&logo=mysql&logoColor=white)](https://mysql.com)
[![Docker](https://img.shields.io/badge/Docker-Containerized-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://docker.com)
[![Nginx](https://img.shields.io/badge/Nginx-Reverse_Proxy-009639?style=for-the-badge&logo=nginx&logoColor=white)](https://nginx.org)

---

## 📋 Project Overview

**MusicNation Digital Music Cloud** is a production-grade, fully functional music streaming and cloud management platform built as an end-to-end AWS case study for B.Tech CSE Semester IV.

The platform solves a real-world enterprise problem: MusicNation was operating on disconnected systems, manual workflows, and isolated reporting environments. This solution delivers a **centralized cloud platform** with:

- 🎵 **Real audio streaming** from Amazon S3 via IAM-secured pre-signed URLs
- 🗄️ **MySQL database** with full operational schema — users, tracks, play events, metrics, audit logs
- 📊 **Live dashboards** — Analytics, Monitoring, Pricing, RBAC, Workflow, Executive Reports
- 🐳 **Docker containerization** — 3-container orchestration with docker-compose
- 🔐 **Role-based access control** — Admin / Manager / Staff tiers
- 🤖 **Automated scripts** — backup, deployment, monitoring, cron jobs
- 💰 **Complete AWS pricing strategy** with multi-region cost breakdown

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    MUSICNATION CLOUD PLATFORM                │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   Browser (index.html)                                      │
│        │                                                    │
│        ▼                                                    │
│   ┌─────────────┐     ┌──────────────────────────────┐     │
│   │    Nginx    │────▶│      Flask API (Port 5001)   │     │
│   │  Port 80   │     │  /catalog  /stream  /metrics │     │
│   └─────────────┘     │  /analytics  /users  /tasks │     │
│                       └──────────┬───────────────────┘     │
│                                  │                          │
│              ┌───────────────────┼───────────────┐         │
│              ▼                   ▼               ▼         │
│        ┌──────────┐      ┌────────────┐   ┌──────────┐    │
│        │  MySQL   │      │  Amazon S3 │   │   boto3  │    │
│        │   DB     │      │  MP3 Files │   │  AWS SDK │    │
│        └──────────┘      └────────────┘   └──────────┘    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## ☁️ AWS Services Used

| Service | Purpose | Status |
|---|---|---|
| **EC2 t3.micro** | Hosts Flask API backend on Ubuntu | ✅ Live |
| **Amazon S3** | Stores MP3 audio files (33.8MB, 5 tracks) | ✅ Live |
| **IAM Role** | `musicnation-ec2-role` — credential-less EC2→S3 auth | ✅ Live |
| **Amazon RDS MySQL** | Production database in private subnet | ✅ Provisioned |
| **Amazon VPC** | Isolated network with public/private subnets | ✅ Live |
| **Security Groups** | Firewall rules — DB blocked from internet | ✅ Live |
| **Amazon CloudFront** | CDN for global low-latency audio delivery | ✅ Provisioned |
| **ElastiCache Redis** | Session + catalog query caching | ✅ Provisioned |
| **Amazon SQS** | Async audio transcoding queue + DLQ | ✅ Provisioned |
| **AWS CloudWatch** | Metrics, logs, and alerting | ✅ Provisioned |

---

## 🗂️ Project Structure

```
musicnation-cloud-platform/
├── app/
│   ├── app.py              # Flask backend — all API routes
│   └── requirements.txt    # Python dependencies
├── scripts/
│   ├── backup.sh           # MySQL dump → S3 (runs daily via cron)
│   ├── deploy.sh           # Git pull → pip install → systemctl restart
│   ├── monitor.sh          # CPU/memory/disk health check script
│   ├── setup_cron.sh       # Installs all cron jobs on the server
│   ├── scp_deploy.sh       # SCP file transfer + remote SSH deployment
│   ├── musicnation-api.service  # systemd service file for Flask
│   └── db/
│       └── schema.sql      # Full MySQL schema + seed data
├── nginx/
│   └── nginx.conf          # Nginx reverse proxy + rate limiting config
├── docs/
│   └── linux-setup.md      # Linux admin guide — users, packages, firewall
├── Dockerfile              # Flask API Docker image
├── docker-compose.yml      # 3-container orchestration (API + MySQL + Nginx)
├── index.html              # Full frontend SPA
└── README.md               # This file
```

---

## 🚀 Quick Start — Run Locally

### Option A: Docker (Recommended — everything included)

```bash
# Clone the repo
git clone https://github.com/Soham-bot/musicnation-cloud-platform
cd musicnation-cloud-platform

# Start all 3 containers (Flask + MySQL + Nginx)
docker-compose up -d

# Verify all containers are healthy
docker ps

# Open the app
open index.html
```

All services start automatically. MySQL schema is applied on first run.

### Option B: Run Flask directly

```bash
# Install dependencies
pip3 install flask flask-cors boto3 PyMySQL bcrypt psutil

# Configure AWS credentials
aws configure
# Enter: Access Key, Secret Key, region: us-east-1

# Start backend
python3 app/app.py

# Open frontend in browser
open index.html
```

---

## 🔌 API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| GET | `/` | API status and version |
| GET | `/health` | Health check — API + DB status |
| GET | `/catalog` | All tracks with pre-signed S3 stream URLs |
| GET | `/stream/<id>` | Fresh pre-signed URL for one track |
| GET | `/buckets` | List S3 buckets (proves IAM auth) |
| GET | `/analytics` | Play counts, top tracks, regional data |
| GET | `/metrics` | Live CPU/memory/disk + history |
| GET | `/users` | All platform users with roles |
| GET | `/audit` | Audit log — all platform actions |
| GET | `/tasks` | Workflow tasks with status |
| PATCH | `/tasks/<id>/status` | Update task status |
| GET | `/executive` | Executive KPI summary report |
| POST | `/login` | Authenticate user, returns role |

---

## 🎵 How Audio Streaming Works

```
1. User clicks Play on a track card
2. Frontend calls  GET /stream/<track_id>
3. Flask uses boto3 + IAM role to call S3.generate_presigned_url()
4. S3 returns a signed URL valid for 1 hour
5. Frontend sets  <audio>.src = signed_url
6. Browser streams MP3 directly from S3
7. Flask logs a play_event to MySQL
8. Track play_count increments in DB
```

**Key security point:** MP3 files are never public. Every URL is unique, time-limited, and tied to IAM credentials. No hardcoded keys anywhere in the code.

---

## 🗄️ Database Schema

```sql
users          — Platform users with role_id (admin/manager/staff)
roles          — Role definitions and permissions
tracks         — Music catalog with S3 keys
play_events    — Every stream event (analytics source)
system_metrics — CPU/memory/disk readings over time
audit_log      — Every user action for compliance
tasks          — Workflow tasks with status and assignment
```

**Default users (password: Admin@123):**
| Username | Role | Access |
|---|---|---|
| admin | Admin | Full platform |
| manager | Manager | Catalog + Analytics |
| staff | Staff | Read-only catalog |

---

## 🐳 Docker Architecture

```yaml
services:
  api:    Flask backend  — port 5001  — connects to db + S3
  db:     MySQL 8.0      — port 3306  — auto-applies schema.sql
  nginx:  Nginx reverse  — port 80    — proxies /api/ to Flask
```

```bash
# Start everything
docker-compose up -d

# Check status
docker ps

# View API logs
docker logs musicnation-api -f

# Stop everything
docker-compose down

# Rebuild after code change
docker-compose build api && docker-compose up -d api
```

---

## 🔧 Linux Administration

### systemd Service (EC2 Production)
```bash
# Install Flask as a system service
sudo cp scripts/musicnation-api.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable musicnation-api
sudo systemctl start musicnation-api

# Check status
sudo systemctl status musicnation-api
```

### Cron Jobs
```bash
# Install all automated tasks
bash scripts/setup_cron.sh

# What gets scheduled:
# 0 2 * * *    Daily database backup to S3 at 2AM
# */5 * * * *  System health check every 5 minutes
# */50 * * * * S3 URL cache refresh every 50 minutes
# 0 3 * * 0   Weekly log rotation
```

### Deploy via SCP
```bash
# Transfer files to EC2 and restart services
bash scripts/scp_deploy.sh
```

### Firewall (UFW)
```bash
sudo ufw allow 22    # SSH
sudo ufw allow 80    # HTTP
sudo ufw allow 443   # HTTPS
sudo ufw deny 3306   # Block MySQL from internet
sudo ufw enable
```

---

## 📊 Dashboard Pages

| Page | What it shows |
|---|---|
| **Home Portal** | Hero banner, live track catalog, platform stats |
| **Search Catalog** | Live search by song title or artist |
| **Cloud Library** | Real S3 bucket contents with file status |
| **Analytics** | Play counts, top tracks chart, regional breakdown |
| **Monitoring** | Live CPU/memory/disk gauges, service status, history |
| **Pricing** | Full AWS cost table, multi-region costs, RPO/RTO |
| **Access Control** | RBAC users table, role definitions, audit log |

---

## 🔐 Security Architecture

| Layer | Implementation |
|---|---|
| **Credential-less auth** | EC2 IAM role — no hardcoded keys anywhere |
| **Network isolation** | RDS + ElastiCache in private subnets only |
| **Audio security** | Pre-signed S3 URLs (1hr expiry, never public) |
| **Web security** | Nginx security headers + rate limiting (30 req/min) |
| **Password security** | bcrypt hashing — passwords never stored in plain text |
| **Audit trail** | Every action logged to `audit_log` table |
| **Firewall** | UFW + Security Groups block all non-essential ports |

---

## 💰 Pricing Strategy

| Service | Monthly Cost |
|---|---|
| EC2 t3.medium | $30.22 |
| EBS gp3 30GB | $2.40 |
| Amazon S3 | $0.02 |
| RDS MySQL t3.micro | $13.00 |
| ElastiCache t3.micro | $11.52 |
| CloudFront 100GB | $8.50 |
| Application Load Balancer | $16.20 |
| CloudWatch | $5.00 |
| WAF + Shield Standard | $15.00 |
| SQS | $0.40 |
| **Total** | **~$103/month** |

**Multi-region (Mumbai + Virginia):** ~$148.50/month

**Cost Optimization:**
- 1-year Reserved EC2 → saves 38%
- S3 Intelligent Tiering → auto-moves cold files to cheaper storage
- CloudFront caching → reduces S3 egress by up to 70%
- Auto Scaling → scale between 1–4 EC2 instances based on load

**Disaster Recovery:**
- RPO: 24 hours (daily automated backups to S3)
- RTO: 4 hours (automated restore + health verification)

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Frontend | HTML5, Tailwind CSS, Vanilla JS, Font Awesome |
| Backend | Python 3.11, Flask 3.1, Flask-CORS |
| Database | MySQL 8.0 (Docker), Amazon RDS (production) |
| Cloud | AWS EC2, S3, IAM, RDS, VPC, CloudFront, SQS, ElastiCache |
| Container | Docker, docker-compose |
| Web Server | Nginx (reverse proxy + rate limiting) |
| Monitoring | psutil (system metrics), custom `/metrics` API |
| Automation | Bash scripts, cron, systemd |
| Audio | HTML5 Audio API, S3 pre-signed URLs |
| Lyrics | lyrics.ovh public API |

---

## 👨‍💻 Author

**Soham Ahirrao**
B.Tech CSE 2024–2028 | ITM Skills University
AWS Case Study — Semester IV
