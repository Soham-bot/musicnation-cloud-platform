# 🎤 MusicNation — Viva Demo Script
## B.Tech CSE Sem IV — AWS Case Study

---

## ✅ BEFORE JUDGES ARRIVE

**Run this in terminal:**
```bash
cd /Users/sohamahirrao/Desktop/musicnation-cloud-platform
python3 app/app.py
```

**Open these browser tabs:**
- Tab 1: `file:///Users/sohamahirrao/Desktop/musicnation-cloud-platform/index.html`
- Tab 2: `http://localhost:5001/health`
- Tab 3: `http://localhost:5001/catalog`
- Tab 4: `http://localhost:5001/buckets`
- Tab 5: `https://console.aws.amazon.com` (logged in)

**Also open Docker Desktop** — show 3 containers running.

---

## OPENING (60 seconds)

> "Good morning. My name is Soham Ahirrao. My project is MusicNation Digital Music Cloud —
> a fully functional music streaming platform built on AWS.
>
> The problem was that MusicNation operated on disconnected systems and manual workflows.
> My solution is a centralized cloud platform with real audio streaming from S3,
> a MySQL database, monitoring dashboards, automation scripts, Docker containerization,
> and role-based access control. Everything is live and working right now."

---

## PART 1 — LIVE APP DEMO (2 min)

**→ Switch to Tab 1 (your app)**

> "This is the MusicNation platform. The frontend is a single-page app
> connected to a Flask microservice backend running on port 5001."

**→ Click "Ping Health Check" in sidebar**

> "Health check confirms: API is running, MySQL database is connected."

**→ Hover over Kesariya card → click the green Play button**

> "When I click play, the frontend calls our /stream endpoint on Flask.
> Flask uses AWS IAM credentials to generate a pre-signed S3 URL —
> a temporary, time-limited, secure link to the MP3 stored in Amazon S3.
> The browser streams audio directly from S3. No hardcoded keys. No public files."

**→ Let it play 5 seconds — show progress bar moving**

> "Everything is real. Real audio, real S3, real IAM authentication."

**→ Click "Search Catalog" in sidebar → type "Arijit"**

> "Live search filters the catalog fetched from our API."

**→ Click "Cloud Library" in sidebar**

> "This calls our /buckets endpoint using boto3 — a live AWS API call
> that lists actual S3 buckets. You can see musicnation-tracks marked Active."

---

## PART 2 — AWS CONSOLE (3 min)

**→ Switch to AWS Console (Tab 5)**

### 01. VPC Resource Map
**→ EC2 → Instances → your instance → Resource map tab**

> "This is my VPC — musicnation-vpc. Public subnet for EC2,
> private subnets for RDS and ElastiCache. The database is
> completely unreachable from the internet."

### 02. S3 Buckets
**→ S3 → Buckets**

> "Three S3 buckets. The musicnation-tracks bucket holds 33.8MB
> of audio files — the exact songs you just heard playing."

### 03. RDS Database
**→ RDS → Databases → musicnation-db → Details**

> "Amazon RDS MySQL in a private subnet. Notice VPC ID matches
> and it is not publicly accessible. Same schema as our Docker MySQL."

### 04. EC2 Instance
**→ EC2 → Instances → your instance → Details**

> "EC2 t3.micro on Ubuntu. Three things to notice:
> Public IP 3.108.56.235, VPC ID musicnation-vpc,
> and IAM Role musicnation-ec2-role.
> That role is how Flask authenticates to S3 without any passwords in code."

### 05. CloudFront
**→ CloudFront → Distributions**

> "CloudFront CDN delivers audio globally from S3 edge locations.
> Reduces streaming latency to single-digit milliseconds worldwide."

### 06. SQS Queues
**→ SQS → Queues**

> "Two queues — main transcoding queue and a Dead Letter Queue.
> Artist uploads a master file → S3 triggers this queue →
> workers transcode it → if it fails 3 times → goes to DLQ.
> Zero data loss in the pipeline."

### 07. ElastiCache Redis
**→ ElastiCache → Redis**

> "Redis cache for catalog queries and session data.
> Top tracks load from cache — the database is never hit
> for repeated requests."

### 08. IAM Role
**→ EC2 → your instance → Security tab**

> "IAM role attached directly to EC2. The application never stores
> AWS credentials anywhere. This is AWS security best practice —
> credential-less access via short-lived tokens."

---

## PART 3 — LIVE API PROOF (1 min)

**→ Tab 2: http://localhost:5001/health**

> "API is ok, database is connected. Live."

**→ Tab 3: http://localhost:5001/catalog**

> "Returns all 6 tracks with pre-signed S3 URLs.
> Each URL expires in one hour."

**→ Tab 4: http://localhost:5001/buckets**

> "This is the proof IAM works. Flask called the AWS S3 API
> from inside the container and returned your actual bucket names.
> If IAM was broken, you'd see a credentials error."

---

## PART 4 — DASHBOARD PAGES (2 min)

**→ Click "Analytics" in sidebar**

> "Real play data from MySQL. Every stream event is recorded
> with track, timestamp, and region. Top tracks chart,
> regional breakdown — all from live database queries."

**→ Click "Monitoring" in sidebar**

> "Live CPU, memory, disk — read using psutil inside Docker.
> Service status — Flask, MySQL, S3, Nginx all green.
> History table from database."

**→ Click "Pricing" in sidebar**

> "Complete AWS cost breakdown — $103/month for single region,
> $148.50 for multi-region with disaster recovery.
> RPO 24 hours, RTO 4 hours. Cost optimization recommendations."

**→ Click "Access Control" in sidebar**

> "Role-based access control — Admin, Manager, Staff.
> Users table from MySQL. Every action in audit log for compliance."

---

## PART 5 — DOCKER (1 min)

**→ Open Docker Desktop — show 3 containers**

> "Flask API, MySQL, and Nginx — all in Docker containers,
> orchestrated with docker-compose. One command starts everything.
> This is how we achieve environment consistency
> from local laptop to cloud deployment."

**→ Show terminal: `docker ps`**

> "All three containers healthy."

---

## PART 6 — ANSWER THESE QUESTIONS CONFIDENTLY

**"How is this different from a simple website?"**
> "Separate compute, storage, database, cache, and CDN layers —
> each independently scalable. Audio never touches the web server."

**"What if EC2 goes down?"**
> "Multi-AZ deployment. RDS has Multi-AZ enabled. S3 is
> regionally redundant. Auto Scaling replaces EC2 automatically."

**"How do we know IAM is actually working?"**
> "The /buckets endpoint. It calls AWS S3 API from Flask.
> It returns your actual bucket names. That proves it."

**"Where is Linux administration?"**
> "scripts/ folder — systemctl service file, cron setup,
> monitor.sh for CPU/memory/disk, deploy.sh for git pull and restart.
> docs/linux-setup.md covers users, groups, firewall, packages."

**"What about security?"**
> "Five layers: IAM roles, VPC private subnets, S3 pre-signed URLs,
> Nginx rate limiting, bcrypt passwords, audit log."

---

## CLOSING (20 seconds)

> "To summarize — MusicNation is a production-grade cloud platform
> addressing every requirement in the problem statement.
> Live AWS infrastructure, real audio streaming, MySQL database,
> Docker containerization, automated scripts, role-based access,
> monitoring, analytics, and complete pricing strategy.
> Everything you've seen is live and working. Thank you."

---

## QUICK CHEAT SHEET

| If asked about... | Say... |
|---|---|
| Why Flask? | Lightweight Python microframework, perfect for REST APIs |
| Why S3 for audio? | Infinitely scalable, durable, pay-per-use object storage |
| Why pre-signed URLs? | Files stay private, URLs expire, no credentials in frontend |
| Why Docker? | Consistent environment, easy deployment, isolated services |
| Why MySQL? | Relational data fits play events, users, tasks perfectly |
| Why Nginx? | Battle-tested reverse proxy, rate limiting, SSL termination |
| Why Redis? | Sub-millisecond read latency for cached catalog queries |
| Why SQS? | Decouples transcoding from upload — no blocking, no data loss |
