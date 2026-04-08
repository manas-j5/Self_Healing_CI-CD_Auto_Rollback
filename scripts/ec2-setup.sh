#!/usr/bin/env bash
# ================================================================
# ec2-setup.sh — ONE-COMMAND EC2 Server Setup
# ================================================================
# Run this ONCE on a fresh Ubuntu EC2 instance to set up
# everything needed for the Self-Healing CI/CD deployment.
#
# USAGE (SSH into EC2 first, then run):
#   curl -fsSL https://raw.githubusercontent.com/Arsalankhan-07/Self_Healing_CI-CD_Auto_Rollback/main/scripts/ec2-setup.sh | bash
#
# OR copy it to EC2 and run:
#   chmod +x ec2-setup.sh && ./ec2-setup.sh
# ================================================================

set -euo pipefail

echo "================================================================"
echo " Self-Healing CI/CD — EC2 Setup Script"
echo " $(date)"
echo "================================================================"

EC2_USER="${SUDO_USER:-ubuntu}"

# ---- 1. System Update ----
echo "[1/9] Updating system packages..."
sudo apt-get update -qq
sudo apt-get upgrade -y -qq
echo "  ✅ System updated"

# ---- 2. Install Docker ----
echo "[2/9] Installing Docker..."
if ! command -v docker &>/dev/null; then
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sudo sh /tmp/get-docker.sh
    rm /tmp/get-docker.sh
    sudo usermod -aG docker "${EC2_USER}"
    sudo systemctl enable docker
    sudo systemctl start docker
    echo "  ✅ Docker installed and started"
else
    echo "  ⏭  Docker already installed: $(docker --version)"
fi

# ---- 3. Install Nginx ----
echo "[3/9] Installing Nginx..."
if ! command -v nginx &>/dev/null; then
    sudo apt-get install -y nginx
    sudo systemctl enable nginx
    sudo systemctl start nginx
    echo "  ✅ Nginx installed and started"
else
    echo "  ⏭  Nginx already installed: $(nginx -v 2>&1)"
fi

# ---- 4. Install utilities ----
echo "[4/9] Installing utilities (curl, wget, jq, mailutils)..."
sudo apt-get install -y curl wget jq mailutils 2>/dev/null || \
sudo apt-get install -y curl wget jq
echo "  ✅ Utilities installed"

# ---- 5. Create directories ----
echo "[5/9] Creating required directories..."
sudo mkdir -p /var/log/deployments
sudo mkdir -p /var/log/app
sudo chown "${EC2_USER}:${EC2_USER}" /var/log/deployments /var/log/app
mkdir -p ~/selfhealing/scripts
mkdir -p ~/selfhealing/nginx
echo "  ✅ Directories created"

# ---- 6. Configure Nginx sudoers ----
echo "[6/9] Configuring passwordless nginx reload..."
SUDOERS_LINE="${EC2_USER} ALL=(ALL) NOPASSWD: /usr/sbin/nginx, /bin/systemctl reload nginx"
if ! sudo grep -q "${EC2_USER}.*nginx" /etc/sudoers; then
    echo "${SUDOERS_LINE}" | sudo tee -a /etc/sudoers > /dev/null
    echo "  ✅ Sudoers rule added for nginx"
else
    echo "  ⏭  Sudoers rule already exists"
fi

# ---- 7. Create initial Nginx app config (Blue on 8080) ----
echo "[7/9] Setting up initial Nginx configuration..."
sudo tee /etc/nginx/conf.d/app.conf > /dev/null << 'NGINXCONF'
# Blue-Green upstream — managed by deploy.sh
upstream app_backend {
    server 127.0.0.1:8080;
    keepalive 32;
}

server {
    listen 80;
    server_name _;

    access_log /var/log/nginx/app_access.log;
    error_log  /var/log/nginx/app_error.log warn;

    location /nginx-health {
        access_log off;
        return 200 "nginx-ok\n";
        add_header Content-Type text/plain;
    }

    location / {
        proxy_pass http://app_backend;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_connect_timeout 10s;
        proxy_send_timeout    60s;
        proxy_read_timeout    60s;
    }

    add_header X-Frame-Options        "SAMEORIGIN"    always;
    add_header X-Content-Type-Options "nosniff"       always;
}
NGINXCONF

sudo nginx -t && sudo nginx -s reload 2>/dev/null || sudo systemctl reload nginx
echo "  ✅ Nginx configured and reloaded"

# ---- 8. Create state file (initial: Blue/8080 is active) ----
echo "[8/9] Initializing deployment state..."
echo "8080" > /var/log/deployments/.active_port
echo "  ✅ State file created (initial active port: 8080)"

# ---- 9. Final verification ----
echo "[9/9] Running verification..."
echo ""
echo "  Docker  : $(docker --version 2>/dev/null || echo 'FAILED')"
echo "  Nginx   : $(nginx -v 2>&1)"
echo "  Nginx OK: $(curl -s http://localhost/nginx-health || echo 'Not responding yet')"
echo "  Groups  : $(groups ${EC2_USER})"
echo ""
echo "================================================================"
echo " ✅ EC2 SETUP COMPLETE!"
echo ""
echo " IMPORTANT: Log out and back in for Docker group to take effect"
echo " Then run: docker login -u YOUR_DOCKERHUB_USERNAME"
echo "================================================================"
