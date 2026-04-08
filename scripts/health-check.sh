#!/usr/bin/env bash
# ================================================================
# health-check.sh — Standalone Health Check Script
# ================================================================
#
# PURPOSE:
#   Performs health checks on both Blue (8080) and Green (8081) ports.
#   Useful for manual verification, monitoring scripts, and debugging.
#
# USAGE:
#   ./scripts/health-check.sh [PORT]
#
# OPTIONS:
#   PORT    Specific port to check (optional). If omitted, checks both 8080 and 8081.
#
# EXAMPLES:
#   ./scripts/health-check.sh          # Check both ports
#   ./scripts/health-check.sh 8080     # Check only port 8080
#   ./scripts/health-check.sh 8081     # Check only port 8081
# ================================================================

set -uo pipefail

BLUE_PORT=8080
GREEN_PORT=8081
TIMEOUT=5

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }

check_port() {
    local port="$1"
    local url="http://localhost:${port}/actuator/health"

    log "Checking port ${port}: ${url}"

    local response
    response=$(curl --silent --max-time "${TIMEOUT}" "${url}" 2>/dev/null || echo "CONNECTION_FAILED")

    if echo "${response}" | grep -q '"status":"UP"'; then
        log "  ✅ Port ${port}: HEALTHY — ${response}"
        return 0
    elif [[ "${response}" == "CONNECTION_FAILED" ]]; then
        log "  ❌ Port ${port}: No container running (connection refused)"
        return 1
    else
        log "  ⚠️  Port ${port}: Unhealthy — ${response}"
        return 1
    fi
}

# Determine which ports to check
if [[ $# -gt 0 ]]; then
    # Check specific port
    check_port "$1"
else
    # Check both ports
    log "================================================"
    log " Self-Healing App — Health Status Report"
    log "================================================"

    BLUE_OK=false
    GREEN_OK=false

    check_port "${BLUE_PORT}"  && BLUE_OK=true  || true
    check_port "${GREEN_PORT}" && GREEN_OK=true || true

    log ""
    log "Summary:"
    log "  Blue  (8080): $([ "${BLUE_OK}" == "true" ] && echo "✅ HEALTHY" || echo "❌ DOWN/NOT RUNNING")"
    log "  Green (8081): $([ "${GREEN_OK}" == "true" ] && echo "✅ HEALTHY" || echo "❌ DOWN/NOT RUNNING")"
    log ""

    # Check Nginx health
    NGINX_STATUS=$(curl --silent --max-time 3 http://localhost/nginx-health 2>/dev/null || echo "DOWN")
    log "  Nginx (80):   $(echo "${NGINX_STATUS}" | grep -q "nginx-ok" && echo "✅ UP" || echo "❌ DOWN")"
    log "================================================"
fi
