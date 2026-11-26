#!/usr/bin/env bash
# scripts/clone-projects.sh
#
# Clone or update all workspace-ia projects into projects/.
# Safe to re-run: clones missing repos, pulls existing ones.
#
# Usage:
#   ./scripts/clone-projects.sh           # clone/update all projects
#   ./scripts/clone-projects.sh devx      # clone/update a single project by name

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECTS_DIR="$REPO_ROOT/projects"

# ─── Project registry ────────────────────────────────────────────────────────
# Format: "folder_name|git_remote_url"
# Add a new line here each time a new project is added to projects/.
PROJECTS=(
  "easy-redmine-retain|git@github.com:RetainTechnologiesSL/easy-redmine-retain.git"
  "devx|git@github.com:RetainTechnologiesSL/devx.git"
  "moeve-maia|git@github.com:RetainTechnologiesSL/moeve-maia.git"
  "moeve-maia-api-app|git@github.com:RetainTechnologiesSL/moeve-maia-api-app.git"
  "moeve-oti|git@github.com:RetainTechnologiesSL/moeve-oti.git"
  "moeve-oti-api-app|git@github.com:RetainTechnologiesSL/moeve-oti-api-app.git"
  "moeve-oti-app|git@github.com:RetainTechnologiesSL/moeve-oti-app.git"
)
# ─────────────────────────────────────────────────────────────────────────────

FILTER="${1:-}"

mkdir -p "$PROJECTS_DIR"

ok=0
failed=0

for entry in "${PROJECTS[@]}"; do
  name="${entry%%|*}"
  url="${entry##*|}"
  dest="$PROJECTS_DIR/$name"

  # Skip if a specific name was requested and this isn't it
  [[ -n "$FILTER" && "$FILTER" != "$name" ]] && continue

  echo "──────────────────────────────────────────"
  echo "  $name"
  echo "──────────────────────────────────────────"

  if [[ -d "$dest/.git" ]]; then
    echo "  → already cloned; pulling latest..."
    if git -C "$dest" pull --ff-only 2>&1 | sed 's/^/     /'; then
      ok=$((ok + 1))
    else
      echo "  ⚠ pull failed (maybe local changes?); skipping"
      failed=$((failed + 1))
    fi
  else
    echo "  → cloning from $url ..."
    if git clone "$url" "$dest" 2>&1 | sed 's/^/     /'; then
      ok=$((ok + 1))
    else
      echo "  ✗ clone failed"
      failed=$((failed + 1))
    fi
  fi
done

echo ""
echo "Done — $ok succeeded, $failed failed."
[[ $failed -eq 0 ]] || exit 1
