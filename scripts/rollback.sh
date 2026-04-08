#!/usr/bin/env bash
# ================================================================
# rollback.sh — Manual Rollback Script
# ================================================================
#
# PURPOSE:
#   Performs a manual rollback to a specified previous version.
#   Useful when you need to quickly revert to a known-good version
#   without waiting for the next CI/CD pipeline run.
#
# USAGE:
#   ./scripts/rollback.sh --version <VERSION_TAG>
#   ./scripts/rollback.sh --version v3
#   ./scripts/rollback.sh --version stable
#
# OPTIONS:
#   -v, --version    Target version tag to roll back to (REQUIRED)
#   -i, --image      Docker image name (default: from .env)
#   -h, --help       Show this help
#
# EXAMPLES:
#   # Roll back to version v3
#   ./scripts/rollback.sh --version v3
#
#   # Roll back to the stable tag
#   ./scripts/rollback.sh --version stable
#
# NOTE:
#   This script re-uses the deploy.sh logic with the specified version.
#   It will still run health checks — you can't roll back to a broken version.
# ================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ----------------------------------------------------------------
# Defaults
# ----------------------------------------------------------------
ENV_FILE="${SCRIPT_DIR}/../.env"
if [[ -f "${ENV_FILE}" ]]; then
    export $(grep -v '^#' "${ENV_FILE}" | xargs)
fi

DOCKER_IMAGE="${DOCKER_IMAGE:-yourdockerhub/selfhealing-app}"
TARGET_VERSION=""
LOG_DIR="${LOG_DIR:-/var/log/deployments}"

# ----------------------------------------------------------------
# Parse Arguments
# ----------------------------------------------------------------
usage() {
    echo "Usage: $0 --version <VERSION_TAG> [--image <IMAGE>]"
    echo ""
    echo "Options:"
    echo "  -v, --version    Target rollback version (required)"
    echo "  -i, --image      Docker image name"
    echo "  -h, --help       Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 --version v3"
    echo "  $0 --version stable"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--version) TARGET_VERSION="$2"; shift 2 ;;
        -i|--image)   DOCKER_IMAGE="$2";   shift 2 ;;
        -h|--help)    usage; exit 0 ;;
        *) echo "[ERROR] Unknown argument: $1"; usage; exit 1 ;;
    esac
done

# ----------------------------------------------------------------
# Validate
# ----------------------------------------------------------------
if [[ -z "${TARGET_VERSION}" ]]; then
    echo "[ERROR] --version is required."
    usage
    exit 1
fi

# ----------------------------------------------------------------
# Logging
# ----------------------------------------------------------------
mkdir -p "${LOG_DIR}"
ROLLBACK_LOG="${LOG_DIR}/rollback.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ROLLBACK] $1" | tee -a "${ROLLBACK_LOG}"; }

log "================================================================"
log " MANUAL ROLLBACK INITIATED"
log "  Target Version : ${TARGET_VERSION}"
log "  Image          : ${DOCKER_IMAGE}:${TARGET_VERSION}"
log "  Initiated By   : ${USER:-unknown}"
log "  Timestamp      : $(date)"
log "================================================================"

# ----------------------------------------------------------------
# Check if the target image tag exists in Docker Hub
# ----------------------------------------------------------------
log "Verifying that image ${DOCKER_IMAGE}:${TARGET_VERSION} exists..."
if docker pull "${DOCKER_IMAGE}:${TARGET_VERSION}" > /dev/null 2>&1; then
    log "Image verified: ${DOCKER_IMAGE}:${TARGET_VERSION}"
else
    log "ERROR: Image ${DOCKER_IMAGE}:${TARGET_VERSION} not found in Docker Hub!"
    log "Available tags can be checked at: https://hub.docker.com/r/${DOCKER_IMAGE}/tags"
    exit 1
fi

# ----------------------------------------------------------------
# Delegate to deploy.sh with the target version
# ----------------------------------------------------------------
log "Delegating to deploy.sh with version=${TARGET_VERSION} ..."

"${SCRIPT_DIR}/deploy.sh" \
    --image "${DOCKER_IMAGE}" \
    --version "${TARGET_VERSION}"

DEPLOY_EXIT=$?

if [[ ${DEPLOY_EXIT} -eq 0 ]]; then
    log "MANUAL ROLLBACK SUCCESSFUL → Version ${TARGET_VERSION} is now live."
else
    log "MANUAL ROLLBACK FAILED → Health check failed for version ${TARGET_VERSION}."
    log "The previous active version remains running."
    exit 1
fi
