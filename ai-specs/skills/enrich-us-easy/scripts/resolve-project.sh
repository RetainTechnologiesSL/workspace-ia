#!/usr/bin/env bash
# Resolves an EasyRedmine project.id to the workspace repo/folder it belongs to,
# via devx's GET /api/proyectos/by-easyredmine/{idEasyRedmine} endpoint.
#
# Required env vars:
#   DEVX_API_URL          Base URL of the devx (gestor) app, e.g. https://devx.retain.es or http://localhost:8000
#   DEVX_PROYECTOS_API_KEY  Static API key matching devx's DEVX_PROYECTOS_API_KEY env var,
#                           sent as the X-Api-Key header.
#
# Usage:
#   resolve-project.sh <easyredmine_project_id>
#
# Output: the JSON body from devx on success (fields: idEasyRedmine, nombre,
# repositorio, repositorioGithub, vcsPrincipal). Exit code 1 and a message on
# stderr if the project is not found (404) or the request fails.

set -euo pipefail

if [[ -z "${DEVX_API_URL:-}" || -z "${DEVX_PROYECTOS_API_KEY:-}" ]]; then
  echo "Error: DEVX_API_URL and DEVX_PROYECTOS_API_KEY must be set in the environment." >&2
  exit 1
fi

PROJECT_ID="${1:?Usage: resolve-project.sh <easyredmine_project_id>}"
BASE_URL="${DEVX_API_URL%/}"

RESPONSE="$(curl -sS --max-time 15 -w '\nHTTP %{http_code}' \
  -H "X-Api-Key: ${DEVX_PROYECTOS_API_KEY}" \
  "${BASE_URL}/api/proyectos/by-easyredmine/${PROJECT_ID}")"
HTTP_CODE="$(echo "$RESPONSE" | grep -o 'HTTP [0-9]*' | awk '{print $2}')"
BODY="$(echo "$RESPONSE" | sed '$d')"

if [[ "$HTTP_CODE" != "200" ]]; then
  echo "Error: devx returned HTTP ${HTTP_CODE} for project id ${PROJECT_ID}: ${BODY}" >&2
  exit 1
fi

echo "$BODY"
