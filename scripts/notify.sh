#!/usr/bin/env bash
# ================================================================
# notify.sh — Notification Helper Script
# ================================================================
#
# PURPOSE:
#   Sends deployment notifications via:
#   1. Console log (always)
#   2. Deployment notification log file
#   3. Email (if NOTIFICATION_EMAIL is set and mail is configured)
#   4. Slack webhook (if SLACK_WEBHOOK_URL is set)
#
# USAGE:
#   ./scripts/notify.sh --type SUCCESS|FAILURE --version v1 --message "msg" [--log logfile]
#
# ENVIRONMENT VARIABLES:
#   NOTIFICATION_EMAIL   Email address to send alerts to (optional)
#   SLACK_WEBHOOK_URL    Slack incoming webhook URL (optional)
#   APP_NAME             Application name (default: selfhealing-app)
# ================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"
if [[ -f "${ENV_FILE}" ]]; then
    export $(grep -v '^#' "${ENV_FILE}" | xargs) 2>/dev/null || true
fi

# Defaults
NOTIFICATION_TYPE=""
VERSION=""
MESSAGE=""
LOG_FILE=""
LOG_DIR="${LOG_DIR:-/var/log/deployments}"
NOTIFICATION_LOG="${LOG_DIR}/notifications.log"
APP_NAME="${APP_NAME:-selfhealing-app}"
NOTIFICATION_EMAIL="${NOTIFICATION_EMAIL:-}"
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --type)    NOTIFICATION_TYPE="$2"; shift 2 ;;
        --version) VERSION="$2";           shift 2 ;;
        --message) MESSAGE="$2";           shift 2 ;;
        --log)     LOG_FILE="$2";          shift 2 ;;
        *) shift ;;
    esac
done

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
ICON=$([ "${NOTIFICATION_TYPE}" == "SUCCESS" ] && echo "✅" || echo "❌")

# ----------------------------------------------------------------
# 1. Console Notification (always)
# ----------------------------------------------------------------
echo ""
echo "============================================================"
echo " ${ICON} DEPLOYMENT NOTIFICATION [${NOTIFICATION_TYPE}]"
echo "  App      : ${APP_NAME}"
echo "  Version  : ${VERSION}"
echo "  Time     : ${TIMESTAMP}"
echo "  Message  : ${MESSAGE}"
[[ -n "${LOG_FILE}" ]] && echo "  Log File : ${LOG_FILE}"
echo "============================================================"
echo ""

# ----------------------------------------------------------------
# 2. Notification Log File
# ----------------------------------------------------------------
mkdir -p "${LOG_DIR}"
{
    echo "----------------------------------------"
    echo "TIMESTAMP   : ${TIMESTAMP}"
    echo "TYPE        : ${NOTIFICATION_TYPE}"
    echo "APPLICATION : ${APP_NAME}"
    echo "VERSION     : ${VERSION}"
    echo "MESSAGE     : ${MESSAGE}"
    [[ -n "${LOG_FILE}" ]] && echo "DEPLOY LOG  : ${LOG_FILE}"
    echo "HOST        : $(hostname)"
    echo "----------------------------------------"
} >> "${NOTIFICATION_LOG}"

echo "[notify.sh] Notification logged to: ${NOTIFICATION_LOG}"

# ----------------------------------------------------------------
# 3. Email Notification (if configured)
# ----------------------------------------------------------------
if [[ -n "${NOTIFICATION_EMAIL}" ]]; then
    SUBJECT="${ICON} [${APP_NAME}] Deployment ${NOTIFICATION_TYPE}: ${VERSION}"
    BODY="Deployment ${NOTIFICATION_TYPE}\n\nApplication: ${APP_NAME}\nVersion: ${VERSION}\nTime: ${TIMESTAMP}\n\nMessage: ${MESSAGE}\n\nDeployment log: ${LOG_FILE}"

    if command -v mail &>/dev/null; then
        echo -e "${BODY}" | mail -s "${SUBJECT}" "${NOTIFICATION_EMAIL}"
        echo "[notify.sh] Email sent to: ${NOTIFICATION_EMAIL}"
    elif command -v sendmail &>/dev/null; then
        echo -e "Subject: ${SUBJECT}\n\n${BODY}" | sendmail "${NOTIFICATION_EMAIL}"
        echo "[notify.sh] Email sent via sendmail to: ${NOTIFICATION_EMAIL}"
    else
        echo "[notify.sh] WARNING: No mail command available. Email notification skipped."
        echo "            Install 'mailutils' to enable email: sudo apt-get install mailutils"
    fi
fi

# ----------------------------------------------------------------
# 4. Slack Notification (if webhook URL is configured)
# ----------------------------------------------------------------
if [[ -n "${SLACK_WEBHOOK_URL}" ]]; then
    COLOR=$([ "${NOTIFICATION_TYPE}" == "SUCCESS" ] && echo "good" || echo "danger")

    SLACK_PAYLOAD=$(cat <<EOF
{
    "attachments": [
        {
            "color": "${COLOR}",
            "title": "${ICON} ${APP_NAME} — Deployment ${NOTIFICATION_TYPE}",
            "fields": [
                { "title": "Version",   "value": "${VERSION}",           "short": true },
                { "title": "Status",    "value": "${NOTIFICATION_TYPE}", "short": true },
                { "title": "Timestamp", "value": "${TIMESTAMP}",         "short": false },
                { "title": "Message",   "value": "${MESSAGE}",           "short": false }
            ],
            "footer": "Self-Healing CI/CD | ${APP_NAME}"
        }
    ]
}
EOF
)

    if curl --silent --max-time 10 -X POST \
        -H 'Content-type: application/json' \
        --data "${SLACK_PAYLOAD}" \
        "${SLACK_WEBHOOK_URL}" > /dev/null; then
        echo "[notify.sh] Slack notification sent successfully."
    else
        echo "[notify.sh] WARNING: Slack notification failed."
    fi
fi

exit 0
