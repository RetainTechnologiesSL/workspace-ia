#!/usr/bin/env bash
# Minimal REST client for EasyRedmine, mirroring the pattern already used
# in projects/devx/gestor/src/Service/EasyRedmineService.php (same base
# URL, same X-Redmine-API-Key header, same endpoints).
#
# Required env vars:
#   EASY_REDMINE_URL      e.g. https://easyredmine.retain.es
#   EASY_REDMINE_API_KEY  personal API key (Redmine > My account > API access key)
#
# Usage:
#   easy-redmine.sh get <issue_id>
#   easy-redmine.sh update-description <issue_id> <file-with-new-description>
#   easy-redmine.sh add-note <issue_id> <file-with-note-text>

set -euo pipefail

if [[ -z "${EASY_REDMINE_URL:-}" || -z "${EASY_REDMINE_API_KEY:-}" ]]; then
  echo "Error: EASY_REDMINE_URL and EASY_REDMINE_API_KEY must be set in the environment." >&2
  exit 1
fi

BASE_URL="${EASY_REDMINE_URL%/}"
CMD="${1:-}"

case "$CMD" in
  get)
    ISSUE_ID="${2:?Usage: easy-redmine.sh get <issue_id>}"
    curl -sS --http1.1 --max-time 30 \
      -H "X-Redmine-API-Key: ${EASY_REDMINE_API_KEY}" \
      "${BASE_URL}/issues/${ISSUE_ID}.json?include=journals"
    ;;

  update-description)
    ISSUE_ID="${2:?Usage: easy-redmine.sh update-description <issue_id> <file>}"
    DESC_FILE="${3:?Usage: easy-redmine.sh update-description <issue_id> <file>}"
    jq -n --rawfile desc "$DESC_FILE" '{issue: {description: $desc}}' |
      curl -sS --http1.1 --max-time 30 -X PUT \
        -H "X-Redmine-API-Key: ${EASY_REDMINE_API_KEY}" \
        -H "Content-Type: application/json" \
        -d @- \
        -w '\nHTTP %{http_code}\n' \
        "${BASE_URL}/issues/${ISSUE_ID}.json"
    ;;

  add-note)
    ISSUE_ID="${2:?Usage: easy-redmine.sh add-note <issue_id> <file>}"
    NOTE_FILE="${3:?Usage: easy-redmine.sh add-note <issue_id> <file>}"
    jq -n --rawfile notes "$NOTE_FILE" '{issue: {notes: $notes}}' |
      curl -sS --http1.1 --max-time 30 -X PUT \
        -H "X-Redmine-API-Key: ${EASY_REDMINE_API_KEY}" \
        -H "Content-Type: application/json" \
        -d @- \
        -w '\nHTTP %{http_code}\n' \
        "${BASE_URL}/issues/${ISSUE_ID}.json"
    ;;

  *)
    echo "Usage: easy-redmine.sh {get|update-description|add-note} <issue_id> [file]" >&2
    exit 1
    ;;
esac
