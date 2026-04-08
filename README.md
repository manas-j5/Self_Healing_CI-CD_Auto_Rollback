# 🔄 Self-Healing CI/CD Deployment System
### Automatic Rollback • Zero Downtime • Blue-Green Deployment

[![CI/CD Pipeline](https://github.com/YOUR_USERNAME/selfHealingCI_CD_Devops_Project/actions/workflows/ci-cd.yml/badge.svg)](https://github.com/YOUR_USERNAME/selfHealingCI_CD_Devops_Project/actions/workflows/ci-cd.yml)
[![Docker Hub](https://img.shields.io/docker/v/yourdockerhub/selfhealing-app?label=Docker%20Hub)](https://hub.docker.com/r/yourdockerhub/selfhealing-app)
[![Java](https://img.shields.io/badge/Java-17-ED8B00?logo=openjdk)](https://openjdk.org/)
[![Spring Boot](https://img.shields.io/badge/Spring%20Boot-3.2-6DB33F?logo=spring)](https://spring.io/projects/spring-boot)

---

## 📋 Table of Contents

1. [Architecture Overview](#-architecture-overview)
2. [Project Structure](#-project-structure)
3. [CI/CD Workflow](#-cicd-workflow)
4. [Blue-Green Deployment Strategy](#-blue-green-deployment-strategy)
5. [Self-Healing Mechanism](#-self-healing-mechanism)
6. [Rollback Logic](#-rollback-logic)
7. [Zero Downtime Strategy](#-zero-downtime-strategy)
8. [Quick Start Setup](#-quick-start-setup)
9. [GitHub Secrets Configuration](#-github-secrets-configuration)
10. [EC2 Setup Guide](#-ec2-setup-guide)
11. [Environment Variables](#-environment-variables)
12. [Deployment Scripts Reference](#-deployment-scripts-reference)
13. [Monitoring & Logs](#-monitoring--logs)
14. [Notifications](#-notifications)
15. [Troubleshooting](#-troubleshooting)

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         DEVELOPER WORKSTATION                           │
│                    git push → main branch                               │
└──────────────────────────────────┬──────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         GITHUB ACTIONS CI/CD                            │
│                                                                         │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐              │
│  │ Job 1        │───▶│ Job 2        │───▶│ Job 3        │              │
│  │ Build & Test │    │ Docker Build │    │ Deploy to EC2│              │
│  │              │    │ & Push Hub   │    │ (Self-Healing)│              │
│  └──────────────┘    └──────────────┘    └──────────────┘              │
│       ↑ Fail = Stop       ↑ v{N} tag          ↑ SSH + deploy.sh        │
└───────────────────────────────────────────────────┬─────────────────────┘
                                                    │
                    ┌───────────────────────────────▼───────────────────┐
                    │              AWS EC2 (Ubuntu)                      │
                    │                                                    │
                    │  ┌─────────────────────────────────────────────┐  │
                    │  │              Nginx (Port 80)                 │  │
                    │  │         Reverse Proxy + Load Balancer        │  │
                    │  └───────────────────┬─────────────────────────┘  │
                    │                      │                             │
                    │          ┌───────────┴───────────┐                 │
                    │          │                       │                 │
                    │  ┌───────▼───────┐     ┌─────────▼───────┐       │
                    │  │  BLUE         │     │  GREEN           │       │
                    │  │  Container    │     │  Container       │       │
                    │  │  Port 8080    │     │  Port 8081       │       │
                    │  │  (Stable)     │     │  (New Deploy)    │       │
                    │  └───────────────┘     └─────────────────┘        │
                    │                                                    │
                    │  ┌─────────────────────────────────────────────┐  │
                    │  │        Self-Healing Decision Logic           │  │
                    │  │                                              │  │
                    │  │  Health Check → UP?                          │  │
                    │  │    ✅ YES → Switch Nginx to Green → Kill Blue │  │
                    │  │    ❌ NO  → Kill Green → Keep Blue → Rollback │  │
                    │  └─────────────────────────────────────────────┘  │
                    └────────────────────────────────────────────────────┘
```

---

## 📁 Project Structure

```
selfHealingCI_CD_Devops_Project/
│
├── .github/
│   └── workflows/
│       └── ci-cd.yml              # 🔄 GitHub Actions Pipeline (4 jobs)
│
├── app/                           # 🍃 Spring Boot Application
│   ├── src/
│   │   ├── main/
│   │   │   ├── java/com/devops/selfhealing/
│   │   │   │   ├── SelfHealingApplication.java    # Main class
│   │   │   │   ├── controller/
│   │   │   │   │   └── AppInfoController.java     # REST endpoints
│   │   │   │   └── config/
│   │   │   │       └── AppConfig.java             # CORS config
│   │   │   └── resources/
│   │   │       └── application.properties         # App configuration
│   │   └── test/
│   │       └── java/com/devops/selfhealing/
│   │           └── SelfHealingApplicationTests.java  # Test suite
│   └── pom.xml                    # Maven project descriptor
│
├── docker/
│   └── Dockerfile                 # 🐳 Multi-stage production Dockerfile
│
├── nginx/
│   ├── nginx.conf                 # 🌐 Nginx main configuration
│   └── app.conf                   # 🌐 Blue-Green upstream proxy config
│
├── scripts/
│   ├── deploy.sh                  # 🚀 Main self-healing deployment script
│   ├── rollback.sh                # 🔙 Manual rollback script
│   ├── health-check.sh            # ❤️  Standalone health checker
│   └── notify.sh                  # 📢 Notification helper
│
├── .env.example                   # 📝 Environment variables template
├── .gitignore                     # 🚫 Git ignore rules
└── README.md                      # 📖 This documentation
```

---

## 🔄 CI/CD Workflow

The pipeline runs automatically on every push to the `main` branch.

### Pipeline Flow

```
Push to main
     │
     ▼
┌────────────────────────────────────────────────────┐
│ JOB 1: Build & Test                                │
│                                                    │
│  1. Checkout code                                  │
│  2. Set up JDK 17 (Temurin, with Maven cache)      │
│  3. mvn clean verify (compile + run all tests)     │
│  4. Upload test reports as artifact                │
│  5. Upload JAR as artifact                         │
│                                                    │
│  ❌ FAIL → Pipeline stops, no deployment           │
└─────────────────┬──────────────────────────────────┘
                  │ Success
                  ▼
┌────────────────────────────────────────────────────┐
│ JOB 2: Docker Build & Push                         │
│                                                    │
│  1. Download JAR artifact                          │
│  2. Set up Docker Buildx (layer caching)           │
│  3. Login to Docker Hub                            │
│  4. Build multi-stage Docker image                 │
│  5. Tag with v{run_number} + latest + sha          │
│  6. Push to Docker Hub                             │
│                                                    │
│  ❌ FAIL → Pipeline stops, no deployment           │
└─────────────────┬──────────────────────────────────┘
                  │ Success
                  ▼
┌────────────────────────────────────────────────────┐
│ JOB 3: Deploy to EC2                               │
│                                                    │
│  1. Configure SSH with EC2 key                     │
│  2. Copy scripts to EC2 via SCP                    │
│  3. SSH into EC2                                   │
│  4. Execute deploy.sh (SELF-HEALING)               │
│  5. Post-deploy health verification                │
│                                                    │
│  ❌ FAIL → App auto-rolled back by deploy.sh       │
└─────────────────┬──────────────────────────────────┘
                  │ Always runs
                  ▼
┌────────────────────────────────────────────────────┐
│ JOB 4: Notify                                      │
│                                                    │
│  1. Print full pipeline summary                    │
│  2. Report version, commit, author, run URL        │
│                                                    │
│  Always runs (success or failure)                  │
└────────────────────────────────────────────────────┘
```

---

## 🟦🟩 Blue-Green Deployment Strategy

Blue-Green deployment runs **two identical production environments** simultaneously, switching traffic between them for zero-downtime updates.

### How It Works

| Concept | Description |
|---------|-------------|
| **BLUE** | Port `8080` — The currently live, stable version |
| **GREEN** | Port `8081` — The new version being deployed |
| **Switch** | Nginx upstream is atomically updated and reloaded |
| **Rollback** | Simply keep/restart BLUE; no Nginx change needed |

### Deployment Cycle

```
Initial State:
  Nginx → BLUE (8080) [Running v1]
  GREEN → (not running)

Push v2:
  1. Pull v2 image
  2. Start GREEN (8081) with v2
  3. Health check GREEN
  4a. Health OK:
      Nginx → GREEN (8081)   ← atomic switch
      Stop BLUE (8080)
  4b. Health FAIL:
      Stop GREEN (8081)
      Keep Nginx → BLUE (8080) [v1 still live]

Next push (v3):
  GREEN becomes 8080 (old blue becomes new green)
  Pattern alternates each deployment
```

---

## 🩺 Self-Healing Mechanism

The self-healing capability is the **core feature** — implemented in `scripts/deploy.sh`.

### Decision Flow

```
deploy.sh starts
      │
      ▼
  Pull new Docker image
      │
      ▼
  Determine ACTIVE port (read from state file)
  Determine INACTIVE port (alternate: 8080↔8081)
      │
      ▼
  Start new container on INACTIVE port
      │
      ▼
  Wait HEALTH_WAIT_SECONDS (JVM warmup)
      │
      ▼
  ┌─── Health Check Loop ─────────────────────────┐
  │                                               │
  │  curl http://localhost:{NEW_PORT}/actuator/health │
  │                                               │
  │  IF response contains "status":"UP":          │
  │    HEALTHY = true → break                     │
  │  ELSE:                                        │
  │    sleep 5s → retry until MAX_WAIT_SECONDS    │
  │                                               │
  └───────────────────────────────────────────────┘
      │
      ├── HEALTHY ──────────────────────────────────────────┐
      │                                                     │
      ▼                                                     ▼
  ✅ PROMOTE NEW VERSION                        ❌ ROLLBACK
                                                            │
  1. Update Nginx upstream config (sed)    1. Stop failed container
  2. Test Nginx config (nginx -t)          2. Verify old container running
  3. Reload Nginx gracefully               3. Log rollback event
  4. Stop old container (30s timeout)      4. Send failure notification
  5. Update state file (new active port)   5. Exit code 1
  6. Log success
  7. Send success notification
```

### The Health Check

```bash
curl --silent --max-time 5 http://localhost:${NEW_PORT}/actuator/health
# Expected response:
# {"status":"UP","components":{"diskSpace":{"status":"UP"},"ping":{"status":"UP"}}}
```

---

## 🔙 Rollback Logic

### Automatic Rollback

Triggered automatically by `deploy.sh` when health checks fail:
- New container is **stopped and removed**
- Old container is **never touched** (traffic never switched)
- Rollback event is **logged** with timestamp
- **Notification** sent via configured channels

### Manual Rollback

Roll back to any previously pushed Docker tag:

```bash
# Roll back to version v3
./scripts/rollback.sh --version v3

# Roll back to the 'stable' tag
./scripts/rollback.sh --version stable

# Roll back with specific image
./scripts/rollback.sh --image myrepo/selfhealing-app --version v2
```

The rollback script:
1. Verifies the target image exists in Docker Hub
2. Delegates to `deploy.sh` with the target version
3. The same health-check + Blue-Green logic applies

---

## ⚡ Zero Downtime Strategy

Zero downtime is achieved through the combination of:

| Mechanism | How It Ensures Zero Downtime |
|-----------|------------------------------|
| **Blue-Green Ports** | Old version runs until new version is verified healthy |
| **Nginx Reload** | `nginx -s reload` is graceful — in-flight requests complete before workers are replaced |
| **Docker Stop Timeout** | `docker stop --time=30` allows 30s for graceful shutdown |
| **Actuator Health Check** | Only verified healthy apps receive traffic |
| **State File** | Deployment script knows active port even after restarts |

### Traffic During Deployment

```
t=0:  Nginx → BLUE (8080) [v1 live]
t=5:  GREEN (8081) starts with v2
t=35: Health check passes on GREEN
t=35: Nginx → GREEN (8081) [v2 live]  ← <1ms switch, no connections dropped
t=65: BLUE (8080) receives SIGTERM, waits for in-flight requests, then exits
```

---

## 🚀 Quick Start Setup

### Prerequisites

- GitHub account with repository
- Docker Hub account
- AWS EC2 instance (Ubuntu 22.04 recommended)
- SSH access to EC2

### Step 1: Fork / Clone

```bash
git clone https://github.com/YOUR_USERNAME/selfHealingCI_CD_Devops_Project.git
cd selfHealingCI_CD_Devops_Project
```

### Step 2: Configure GitHub Secrets

Go to your GitHub repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Add all secrets listed in the [GitHub Secrets Configuration](#-github-secrets-configuration) section.

### Step 3: Set Up EC2

Follow the [EC2 Setup Guide](#-ec2-setup-guide) below.

### Step 4: Push and Watch

```bash
git add .
git commit -m "feat: deploy self-healing CI/CD system"
git push origin main
```

Watch the pipeline at: `https://github.com/YOUR_USERNAME/selfHealingCI_CD_Devops_Project/actions`

---

## 🔑 GitHub Secrets Configuration

| Secret Name | Description | Example |
|------------|-------------|---------|
| `DOCKERHUB_USERNAME` | Docker Hub username | `johndoe` |
| `DOCKERHUB_TOKEN` | Docker Hub access token (NOT password) | `dckr_pat_xxx...` |
| `EC2_HOST` | EC2 public IP or hostname | `54.123.45.67` |
| `EC2_USER` | EC2 SSH username | `ubuntu` |
| `EC2_SSH_KEY` | Full PEM key content (not path) | `-----BEGIN RSA PRIVATE KEY-----...` |
| `NOTIFICATION_EMAIL` | (Optional) Alert email address | `devops@company.com` |
| `SLACK_WEBHOOK_URL` | (Optional) Slack webhook URL | `https://hooks.slack.com/...` |

> **Getting a Docker Hub Token:**
> Docker Hub → Account Settings → Security → New Access Token → Copy token

> **Getting EC2 SSH Key:**
> `cat ~/.ssh/your-key.pem` → Copy entire content including headers → Paste into secret

---

## ☁️ EC2 Setup Guide

SSH into your EC2 instance and run:

```bash
# 1. Update system
sudo apt-get update && sudo apt-get upgrade -y

# 2. Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu
newgrp docker

# 3. Install Nginx
sudo apt-get install -y nginx

# 4. Install curl (for health checks)
sudo apt-get install -y curl

# 5. Install mail utilities (for email notifications — optional)
sudo apt-get install -y mailutils

# 6. Create deployment directories
sudo mkdir -p /var/log/deployments
sudo mkdir -p /var/log/app
sudo chown ubuntu:ubuntu /var/log/deployments /var/log/app

# 7. Create script directory
mkdir -p ~/selfhealing/scripts

# 8. Copy Nginx config
sudo cp ~/selfhealing/nginx/nginx.conf /etc/nginx/nginx.conf
sudo cp ~/selfhealing/nginx/app.conf /etc/nginx/conf.d/app.conf

# 9. Test and start Nginx
sudo nginx -t
sudo systemctl enable nginx
sudo systemctl start nginx

# 10. Login to Docker Hub (so EC2 can pull your images)
docker login -u YOUR_DOCKERHUB_USERNAME
# Enter your Docker Hub access token when prompted

# 11. Allow Ubuntu user to run nginx commands without sudo password
echo "ubuntu ALL=(ALL) NOPASSWD: /usr/sbin/nginx" | sudo tee -a /etc/sudoers

# 12. Open firewall ports (EC2 Security Group)
# Port 80  → HTTP (Nginx)
# Port 22  → SSH (already open)
# Port 8080, 8081 → (Optional, for direct testing)
```

### Verify Nginx is Working

```bash
curl http://localhost/nginx-health
# Expected: nginx-ok
```

---

## 📊 Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DOCKER_IMAGE` | `yourdockerhub/selfhealing-app` | Full Docker image name |
| `APP_VERSION` | `latest` | Version tag to deploy |
| `APP_ENV` | `production` | Environment label |
| `HEALTH_WAIT_SECONDS` | `15` | Initial JVM warmup wait |
| `MAX_WAIT_SECONDS` | `60` | Max health check wait time |
| `NGINX_CONF` | `/etc/nginx/conf.d/app.conf` | Nginx app config path |
| `LOG_DIR` | `/var/log/deployments` | Deployment log directory |
| `NOTIFICATION_EMAIL` | _(empty)_ | Alert email (optional) |
| `SLACK_WEBHOOK_URL` | _(empty)_ | Slack webhook (optional) |

---

## 📜 Deployment Scripts Reference

### `scripts/deploy.sh`

Main self-healing deployment script.

```bash
# Deploy specific version
./scripts/deploy.sh --version v5

# Deploy specific image + version
./scripts/deploy.sh --image myrepo/myapp --version v3
```

### `scripts/rollback.sh`

Manual rollback to a previous version.

```bash
# Rollback to v3
./scripts/rollback.sh --version v3
```

### `scripts/health-check.sh`

Check health status of running containers.

```bash
# Check both blue and green containers
./scripts/health-check.sh

# Check specific port
./scripts/health-check.sh 8080
./scripts/health-check.sh 8081
```

### `scripts/notify.sh`

Send deployment notifications.

```bash
./scripts/notify.sh \
  --type SUCCESS \
  --version v5 \
  --message "Deployment successful"
```

---

## 📈 Monitoring & Logs

### Application Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /actuator/health` | Health status (returns `{"status":"UP"}`) |
| `GET /actuator/info` | App info and version |
| `GET /actuator/metrics` | Runtime metrics |
| `GET /api/info` | Custom app metadata |
| `GET /api/ping` | Simple liveness check |
| `GET /api/version` | Current deployed version |

### Log Files on EC2

| Log File | Description |
|----------|-------------|
| `/var/log/deployments/deploy_YYYYMMDD_HHMMSS.log` | Per-deployment log |
| `/var/log/deployments/rollback.log` | All rollback events |
| `/var/log/deployments/notifications.log` | Notification history |
| `/var/log/nginx/access.log` | Nginx access log |
| `/var/log/nginx/error.log` | Nginx error log |
| `/var/log/app/application.log` | Spring Boot application log |

### Live Log Monitoring

```bash
# Watch deployment in real time
tail -f /var/log/deployments/deploy_*.log

# Watch rollback events
tail -f /var/log/deployments/rollback.log

# Watch Nginx access
tail -f /var/log/nginx/app_access.log

# Watch application logs
docker logs -f selfhealing-8080
docker logs -f selfhealing-8081
```

---

## 🔔 Notifications

### Console Log (Always Active)

Every deployment prints a clear summary with `✅ SUCCESS` or `❌ FAILURE`.

### Log File Notification

All events are written to `/var/log/deployments/notifications.log`.

### Email Notification

Set `NOTIFICATION_EMAIL` in `.env` or GitHub Secrets. Requires `mailutils`:

```bash
sudo apt-get install -y mailutils
```

### Slack Notification

Set `SLACK_WEBHOOK_URL` in `.env` or GitHub Secrets:

```json
{
  "attachments": [{
    "color": "good|danger",
    "title": "✅ selfhealing-app — Deployment SUCCESS",
    "fields": [
      { "title": "Version", "value": "v5" },
      { "title": "Message", "value": "Deployment successful. Version v5 is now live." }
    ]
  }]
}
```

---

## 🔧 Troubleshooting

### Pipeline fails at "Docker Build"

- Check `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` secrets are correct
- Verify Docker Hub repository exists (create it manually first or enable auto-create)

### Pipeline fails at "Deploy to EC2"

- Verify `EC2_HOST`, `EC2_USER`, and `EC2_SSH_KEY` secrets
- Check EC2 Security Group allows port 22 from GitHub Actions IPs
- Ensure Docker is installed and running on EC2: `sudo systemctl status docker`

### Health check always fails

- Check if container is starting: `docker ps`
- Check container logs: `docker logs selfhealing-8081`
- Check if port is accessible: `curl http://localhost:8081/actuator/health`
- Increase `HEALTH_WAIT_SECONDS` if JVM takes longer to start

### Nginx reload fails after deployment

- Test nginx config: `sudo nginx -t`
- Check nginx logs: `sudo tail /var/log/nginx/error.log`
- Verify `NGINX_CONF` path is correct in `.env`

### Old container not stopping

- Manually stop: `docker stop selfhealing-8080 && docker rm selfhealing-8080`
- Check container state: `docker ps -a`

---

## 🔐 Security Best Practices

- ✅ Non-root user in Docker container
- ✅ Secrets stored in GitHub Secrets (never in code)
- ✅ `.env` file excluded from Git via `.gitignore`
- ✅ Docker Hub Access Token used (not password)
- ✅ EC2 SSH key stored as GitHub Secret
- ✅ Security headers in Nginx config
- ✅ `server_tokens off` (Nginx version not exposed)
- ✅ Minimal Alpine JRE base image (reduced attack surface)

---

## 📄 License

MIT License — Free to use and modify.

---

*Built with ❤️ as a production-grade DevOps reference implementation.*
*Spring Boot · Docker · GitHub Actions · Nginx · AWS EC2*
