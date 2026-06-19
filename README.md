# 🎵 MusicNation Digital Music Cloud Architecture

[![AWS](https://img.shields.io/badge/AWS-100000?style=for-the-badge&logo=amazon-aws&logoColor=white&color=FF9900)](https://aws.amazon.com/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://www.python.org/)
[![Flask](https://img.shields.io/badge/Flask-000000?style=for-the-badge&logo=flask&logoColor=white)](https://flask.palletsprojects.com/)

A production-ready, highly available, and auto-scaling cloud platform engineered for **MusicNation Digital Music Cloud**. This architecture handles secure media ingestion, distributed caching, global low-latency audio delivery, and complete network isolation using AWS best practices.

---

## 🗺️ System Architecture Diagram

```mermaid
graph TD
    User([🌍 Global Listeners]) -->|HTTPS / DNS| CF[⚡ Amazon CloudFront CDN]
    CF -->|Cache Miss: Static Assets| S3_Assets[(📦 S3 Static Assets Bucket)]
    CF -->|Cache Miss: Media Delivery| S3_Deliv[(📦 S3 Delivery Bucket)]
    
    User -->|API Requests| ALB[⚖️ Application Load Balancer]
    ALB -->|Port 5000| EC2[💻 Ubuntu EC2 App Server]
    
    subnetsDB[(🔒 Private Subnets)]
    EC2 -->|Read/Write Metadata| RDS[(🗄️ Amazon RDS PostgreSQL Multi-AZ)]
    EC2 -->|Sub-millisecond Session Cache| Redis[(🚀 Amazon ElastiCache Redis)]
    
    subnetsDB --- RDS
    subnetsDB --- Redis

    %% Ingestion Pipeline
    Admin([🎵 Label/Artist Upload]) -->|Master Files| S3_Master[(🗄️ S3 Master Bucket)]
    S3_Master -->|S3 Put Event| SQS[📨 Amazon SQS Ingestion Queue]
    SQS -->|Asynchronous Trigger| Workers[⚙️ Transcoding Workers]
    Workers -->|Optimized Audio| S3_Deliv
cat << 'EOF' > docs/architecture.md
# 🏛️ Core Cloud Architecture & Design Decisions

This document details the architectural reasoning and cloud design principles applied to eliminate operations bottlenecks and fulfill production growth requirements for the **MusicNation Digital Music Cloud** platform.

---

## 🛡️ Production Tier Architecture Breakdown

### 1. High Availability & Regional Redundancy
* **Multi-AZ Infrastructure:** The Virtual Private Cloud (VPC) spans across two unique availability zones (`ap-south-1a` and `ap-south-1b`). If a physical data center experiences an unexpected service interruption, traffic automatically reroutes to the remaining operational availability zone.
* **Isolated Subnet Layers:** Resources are intentionally segmented. The Compute Layer (EC2 Application Server) operates within public subnets to handle incoming requests, while critical storage and transactional workloads are hidden in isolated private subnets.

### 2. Scalability & Traffic Optimization
* **Distributed Audio Delivery:** Serving high-fidelity lossless media natively from object storage results in high buffer times. Integrating **Amazon CloudFront CDN** drops regional delivery latency to single-digit milliseconds by caching audio files across hundreds of global edge nodes.
* **Memory-Tier Performance Caching:** Read-heavy catalog queries (such as global top tracks or trending playlist lookups) bypass the primary relational database entirely via **Amazon ElastiCache Redis**, preventing CPU starvation on the data layer.

### 3. Asynchronous Task Processing
* **Decoupled Media Pipelines:** High-resolution audio transcoding is an intensive task. Instead of executing processing tasks on the core app cluster, uploads to the **S3 Masters Bucket** automatically drop an event notification payload into **Amazon SQS**.
* **Fault Tolerance:** If a corrupted file or unsupported format breaks the translation thread, a strict **Dead Letter Queue (DLQ)** intercepts the task after 3 processing retries, isolating the failure without breaking the active listener queue.

---

## 🎯 Security Posture & Compliance Summary

| Security Layer | AWS Execution Parameter | Core Architectural Purpose |
| :--- | :--- | :--- |
| **Credential-less Access** | AWS IAM Execution Roles | Eliminates hardcoded configuration security keys. The EC2 instance securely assumes short-lived programmatic identity tokens via `musicnation-ec2-role`. |
| **Network Guardrails** | Security Group Mapping | Stateful security walls filter incoming and outgoing protocols. Database clusters block external internet traffic completely, trusting traffic *only* originating from the designated App server security group. |
| **Data Security** | Server-Side Encryption | Both S3 storage systems and relational databases utilize default AES-256 bits envelope encryption protection (`SSE-S3`) for static media arrays and application properties. |
# musicnation-cloud-platform
