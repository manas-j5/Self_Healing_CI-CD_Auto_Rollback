#!/usr/bin/env bash
# ================================================================
# deploy.sh — Self-Healing CI/CD Deployment Script
# ================================================================
#
# PURPOSE:
#   Implements Blue-Green deployment with automatic self-healing rollback.
#   On every call:
#     1. Pulls the new Docker image
#     2. Starts the new container on the inactive port
#     3. Waits for startup and performs health check
#     4. IF healthy → switches Nginx traffic to new version (zero downtime)
#     5. IF unhealthy → rolls back, keeps old version running, logs event
#
# USAGE:
#   ./scripts/deploy.sh [OPTIONS]
#
# OPTIONS:
#   -i, --image      Docker image name (default: from .env)
#   -v, --version    Image tag/version to deploy (e.g., v1, v2, latest)
#   -h, --help       Show this help message
#
# EXAMPLES:
#   ./scripts/deploy.sh --version v5
#   ./scripts/deploy.sh --image myrepo/selfhealing-app --version v3
#
# ENVIRONMENT VARIABLES (override via .env or export):
#   DOCKER_IMAGE      Full Docker image name (e.g., yourdockerhub/selfhealing-app)
#   APP_VERSION       Version tag to deploy
#   HEALTH_CHECK_URL  URL to check (default: http://localhost:{PORT}/actuator/health)
#   MAX_WAIT_SECONDS  Max seconds to wait for startup (default: 60)
#   NGINX_CONF        Path to Nginx app config (default: /etc/nginx/conf.d/app.conf)
#   LOG_DIR           Directory for deployment logs (default: /var/log/deployments)
#   NOTIFICATION_EMAIL Email for failure notifications (optional)
#
# BLUE-GREEN PORTS:
#   BLUE  = 8080 (initial/stable port)
#   GREEN = 8081 (new deployment port)
#   These alternate on each successful deployment.
# ================================================================

set -euo pipefail

# ================================================================
# CONFIGURATION
# ================================================================

# Load environment variables from .env if present
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"
if [[ -f "${ENV_FILE}" ]]; then
    # shellcheck source=/dev/null
    export $(grep -v '^#' "${ENV_FILE}" | xargs)
fi

# Defaults (can be overridden by .env or CLI args)
DOCKER_IMAGE="${DOCKER_IMAGE:-yourdockerhub/selfhealing-app}"
APP_VERSION="${APP_VERSION:-latest}"
MAX_WAIT_SECONDS="${MAX_WAIT_SECONDS:-60}"
HEALTH_WAIT_SECONDS="${HEALTH_WAIT_SECONDS:-10}"
NGINX_CONF="${NGINX_CONF:-/etc/nginx/conf.d/app.conf}"
LOG_DIR="${LOG_DIR:-/var/log/deployments}"
STATE_FILE="${LOG_DIR}/.active_port"     # Persists which port is currently active
NOTIFICATION_EMAIL="${NOTIFICATION_EMAIL:-}"

# Port definitions
PORT_BLUE=8080
PORT_GREEN=8081

# Container name prefix
CONTAINER_PREFIX="selfhealing"

# ================================================================
# PARSE CLI ARGUMENTS
# ================================================================

usage() {
    grep '^#' "$0" | grep -E '^\# (USAGE|OPTIONS|EXAMPLES|  )' | sed 's/^# //'
    echo ""
    echo "Usage: $0 [--image IMAGE] [--version TAG]"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--image)    DOCKER_IMAGE="$2"; shift 2 ;;
        -v|--version)  APP_VERSION="$2";  shift 2 ;;
        -h|--help)     usage; exit 0 ;;
        *) echo "[ERROR] Unknown argument: $1"; usage; exit 1 ;;
    esac
done

# ================================================================
# LOGGING SETUP
# ================================================================

mkdir -p "${LOG_DIR}"
DEPLOY_LOG="${LOG_DIR}/deploy_$(date '+%Y%m%d_%H%M%S').log"
ROLLBACK_LOG="${LOG_DIR}/rollback.log"

log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local formatted="[${timestamp}] [${level}] ${message}"
    echo "${formatted}"
    echo "${formatted}" >> "${DEPLOY_LOG}"
}

log_info()    { log "INFO   " "$1"; }
log_success() { log "SUCCESS" "$1"; }
log_warn()    { log "WARN   " "$1"; }
log_error()   { log "ERROR  " "$1"; }

# Banner
log_info "================================================================"
log_info " Self-Healing CI/CD Deployment Starting"
log_info " Image   : ${DOCKER_IMAGE}:${APP_VERSION}"
log_info " Time    : $(date)"
log_info "================================================================"

# ================================================================
# HELPER FUNCTIONS
# ================================================================

# Determine which port is currently ACTIVE (serving traffic)
get_active_port() {
    if [[ -f "${STATE_FILE}" ]]; then
        cat "${STATE_FILE}"
    else
        echo "${PORT_BLUE}"  # Default: Blue is active initially
    fi
}

# Get the INACTIVE port (where new container will be deployed)
get_inactive_port() {
    local active
    active=$(get_active_port)
    if [[ "${active}" == "${PORT_BLUE}" ]]; then
        echo "${PORT_GREEN}"
    else
        echo "${PORT_BLUE}"
    fi
}

# Get container name for a given port
get_container_name() {
    local port="$1"
    echo "${CONTAINER_PREFIX}-${port}"
}

# Check if a container is running on a given port
is_container_running() {
    local container_name="$1"
    docker ps --format '{{.Names}}' | grep -q "^${container_name}$"
}

# ================================================================
# STEP 1: PULL LATEST IMAGE
# ================================================================

log_info "STEP 1: Pulling Docker image ${DOCKER_IMAGE}:${APP_VERSION} ..."

if docker pull "${DOCKER_IMAGE}:${APP_VERSION}"; then
    log_success "Image pulled successfully: ${DOCKER_IMAGE}:${APP_VERSION}"
else
    log_error "Failed to pull Docker image. Aborting deployment."
    exit 1
fi

# ================================================================
# STEP 2: DETERMINE PORTS
# ================================================================

ACTIVE_PORT=$(get_active_port)
NEW_PORT=$(get_inactive_port)
ACTIVE_CONTAINER=$(get_container_name "${ACTIVE_PORT}")
NEW_CONTAINER=$(get_container_name "${NEW_PORT}")

log_info "STEP 2: Blue-Green Port Assignment"
log_info "  Current active (OLD): Port ${ACTIVE_PORT} → Container: ${ACTIVE_CONTAINER}"
log_info "  New deployment (NEW): Port ${NEW_PORT} → Container: ${NEW_CONTAINER}"

# ================================================================
# STEP 3: STOP AND REMOVE OLD NEW-CONTAINER (IF EXISTS FROM FAILED DEPLOY)
# ================================================================

if is_container_running "${NEW_CONTAINER}"; then
    log_warn "Found leftover container '${NEW_CONTAINER}' on port ${NEW_PORT}. Cleaning up..."
    docker stop "${NEW_CONTAINER}" && docker rm "${NEW_CONTAINER}" || true
fi

# ================================================================
# STEP 4: START NEW CONTAINER ON INACTIVE PORT
# ================================================================

log_info "STEP 4: Starting new container '${NEW_CONTAINER}' on port ${NEW_PORT} ..."

docker run -d \
    --name "${NEW_CONTAINER}" \
    --restart unless-stopped \
    -p "${NEW_PORT}:8080" \
    -e "APP_VERSION=${APP_VERSION}" \
    -e "APP_ENV=production" \
    -e "JAVA_OPTS=-Xms256m -Xmx512m -XX:+UseG1GC -XX:+UseContainerSupport" \
    -v /var/log/app:/var/log/app \
    "${DOCKER_IMAGE}:${APP_VERSION}"

log_success "Container '${NEW_CONTAINER}' started on port ${NEW_PORT}"

# ================================================================
# STEP 5: HEALTH CHECK WITH RETRY
# ================================================================

log_info "STEP 5: Waiting for application to start (up to ${MAX_WAIT_SECONDS}s) ..."
log_info "  Health check URL: http://localhost:${NEW_PORT}/actuator/health"

ELAPSED=0
HEALTHY=false
HEALTH_CHECK_URL="http://localhost:${NEW_PORT}/actuator/health"

# Initial wait to allow JVM startup
log_info "  Waiting ${HEALTH_WAIT_SECONDS}s for JVM to initialize..."
sleep "${HEALTH_WAIT_SECONDS}"

while [[ ${ELAPSED} -lt ${MAX_WAIT_SECONDS} ]]; do
    log_info "  Health check attempt at ${ELAPSED}s..."

    HTTP_RESPONSE=$(curl --silent --max-time 5 "${HEALTH_CHECK_URL}" || echo "CURL_FAILED")

    if echo "${HTTP_RESPONSE}" | grep -q '"status":"UP"'; then
        HEALTHY=true
        log_success "  Health check PASSED: ${HTTP_RESPONSE}"
        break
    else
        log_warn "  Not healthy yet. Response: ${HTTP_RESPONSE}"
        sleep 5
        ELAPSED=$((ELAPSED + 5))
    fi
done

# ================================================================
# STEP 6: DEPLOYMENT DECISION — PROMOTE OR ROLLBACK
# ================================================================

if [[ "${HEALTHY}" == "true" ]]; then
    # ============================================================
    # ✅ SUCCESS PATH: Promote new container to active
    # ============================================================
    log_info "STEP 6: Health check passed. Promoting new deployment... "

    # 6a. Update Nginx upstream config to point to new port
    log_info "  6a. Updating Nginx upstream from port ${ACTIVE_PORT} to ${NEW_PORT} ..."
    sudo sed -i "s/server 127.0.0.1:${ACTIVE_PORT}/server 127.0.0.1:${NEW_PORT}/" "${NGINX_CONF}"

    # 6b. Test Nginx configuration
    log_info "  6b. Validating Nginx configuration..."
    if sudo nginx -t 2>&1; then
        log_success "  Nginx config is valid."
    else
        log_error "  Nginx config test FAILED! Rolling back Nginx config..."
        sudo sed -i "s/server 127.0.0.1:${NEW_PORT}/server 127.0.0.1:${ACTIVE_PORT}/" "${NGINX_CONF}"
        docker stop "${NEW_CONTAINER}" && docker rm "${NEW_CONTAINER}" || true
        exit 1
    fi

    # 6c. Reload Nginx gracefully (zero downtime — no dropped connections)
    log_info "  6c. Reloading Nginx (zero-downtime reload)..."
    sudo nginx -s reload
    log_success "  Nginx reloaded. Traffic now routed to port ${NEW_PORT}"

    # 6d. Stop old container (gracefully, allow in-flight requests to finish)
    if is_container_running "${ACTIVE_CONTAINER}"; then
        log_info "  6d. Stopping old container '${ACTIVE_CONTAINER}' (port ${ACTIVE_PORT})..."
        docker stop --time=30 "${ACTIVE_CONTAINER}" && docker rm "${ACTIVE_CONTAINER}" || true
        log_success "  Old container stopped and removed."
    else
        log_info "  6d. No old container running on port ${ACTIVE_PORT} to stop."
    fi

    # 6e. Update state file to record the new active port
    echo "${NEW_PORT}" > "${STATE_FILE}"

    # 6f. Log deployment success
    log_success "================================================================"
    log_success " DEPLOYMENT SUCCESSFUL"
    log_success "  Version  : ${APP_VERSION}"
    log_success "  Image    : ${DOCKER_IMAGE}:${APP_VERSION}"
    log_success "  Port     : ${NEW_PORT} (active)"
    log_success "  Container: ${NEW_CONTAINER}"
    log_success "  Time     : $(date)"
    log_success "================================================================"

    # 6g. Send success notification
    "${SCRIPT_DIR}/notify.sh" \
        --type "SUCCESS" \
        --version "${APP_VERSION}" \
        --message "Deployment successful. Version ${APP_VERSION} is now live on port ${NEW_PORT}." \
        --log "${DEPLOY_LOG}" || true

    exit 0

else
    # ============================================================
    # ❌ FAILURE PATH: Auto-rollback
    # ============================================================
    log_error "================================================================"
    log_error " HEALTH CHECK FAILED — INITIATING AUTOMATIC ROLLBACK"
    log_error "================================================================"

    # R1. Stop the failed new container
    log_info "  R1. Stopping failed container '${NEW_CONTAINER}' on port ${NEW_PORT}..."
    docker stop "${NEW_CONTAINER}" && docker rm "${NEW_CONTAINER}" || true
    log_info "  Failed container removed."

    # R2. Verify old container is still running (it should be — we never touched it)
    if is_container_running "${ACTIVE_CONTAINER}"; then
        log_info "  R2. Old container '${ACTIVE_CONTAINER}' on port ${ACTIVE_PORT} is still running. ✅"
        log_info "      Traffic was never switched — users unaffected."
    else
        log_warn "  R2. WARNING: Old container is NOT running! Attempting restart..."
        # Emergency: restart old container from last known-good image
        docker run -d \
            --name "${ACTIVE_CONTAINER}" \
            --restart unless-stopped \
            -p "${ACTIVE_PORT}:8080" \
            -e "APP_VERSION=stable" \
            -e "APP_ENV=production" \
            "${DOCKER_IMAGE}:stable" || \
        log_error "  CRITICAL: Could not restart old container! Manual intervention required."
    fi

    # R3. Log rollback event
    ROLLBACK_ENTRY="[$(date '+%Y-%m-%d %H:%M:%S')] ROLLBACK | Version: ${APP_VERSION} | Reason: Health check failed after ${MAX_WAIT_SECONDS}s | Active: ${ACTIVE_PORT}"
    echo "${ROLLBACK_ENTRY}" >> "${ROLLBACK_LOG}"
    log_error "  R3. Rollback event logged: ${ROLLBACK_LOG}"

    # R4. Send failure notification
    log_error "  R4. Sending failure notification..."
    "${SCRIPT_DIR}/notify.sh" \
        --type "FAILURE" \
        --version "${APP_VERSION}" \
        --message "ROLLBACK: Deployment of ${APP_VERSION} failed health checks. Old version on port ${ACTIVE_PORT} remains active." \
        --log "${DEPLOY_LOG}" || true

    log_error "================================================================"
    log_error " ROLLBACK COMPLETE"
    log_error "  Failed version : ${APP_VERSION} (Port ${NEW_PORT} — STOPPED)"
    log_error "  Active version : Still on Port ${ACTIVE_PORT} — RUNNING"
    log_error "  User impact    : NONE (traffic was never switched)"
    log_error "  Rollback log   : ${ROLLBACK_LOG}"
    log_error "================================================================"

    exit 1
fi
