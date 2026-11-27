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
  "mercure-server|git@github.com:RetainTechnologiesSL/mercure-server.git"
  "generico-proyectos|git@github.com:RetainTechnologiesSL/generico-proyectos.git"
  "retaia|git@github.com:RetainTechnologiesSL/metanoia-ia.git"
  "alcampo-hipermercados|git@github.com:RetainTechnologiesSL/alcampo-hipermercados.git"
  "templo-cafes|git@github.com:RetainTechnologiesSL/templo-cafes.git"
  "carrefour-proyectos-rcc|git@github.com:RetainTechnologiesSL/carrefour-proyectos-rcc.git"
  "carrefour-app|git@github.com:RetainTechnologiesSL/carrefour-app.git"
  "carrefour-api-app|git@github.com:RetainTechnologiesSL/carrefour-api-app.git"
  "carrefour|git@github.com:RetainTechnologiesSL/carrefour.git"
  "alsea-mexico-restaurantes|git@github.com:RetainTechnologiesSL/alsea-mexico-restaurantes.git"
  "alsea-mexico-fabricas|git@github.com:RetainTechnologiesSL/alsea-mexico-fabricas.git"
  "alsea-europa-admin|git@github.com:RetainTechnologiesSL/alsea-europa-admin.git"
  "alsea-europa-front|git@github.com:RetainTechnologiesSL/alsea-europa-front.git"
  "aat-proyectos|git@github.com:RetainTechnologiesSL/aat-proyectos.git"
  "selenta-gestor-documental|git@github.com:RetainTechnologiesSL/selenta-gestor-documental.git"
  "retailgas-llr|git@github.com:RetainTechnologiesSL/retailgas-llr.git"
  "q8-mantenimiento|git@github.com:RetainTechnologiesSL/q8-mantenimiento.git"
  "carrefour-gestor-documental-eess|git@github.com:RetainTechnologiesSL/carrefour-gestor-documental-eess.git"
  "carrefour-mantenimiento-eess|git@github.com:RetainTechnologiesSL/carrefour-mantenimiento-eess.git"
  "app-inventarios|git@github.com:RetainTechnologiesSL/app-inventarios.git"
  "canal-de-denuncias|git@github.com:RetainTechnologiesSL/canal-de-denuncias.git"
  "moeve-metodo|git@github.com:RetainTechnologiesSL/moeve-metodo.git"
  "moeve-sgis-app|git@github.com:RetainTechnologiesSL/moeve-sgis-app.git"
  "moeve-sgis|git@github.com:RetainTechnologiesSL/moeve-sgis.git"
  "q8-gestor-documental|git@github.com:RetainTechnologiesSL/q8-gestor-documental.git"
  "mailer|git@github.com:RetainTechnologiesSL/mailer.git"
  "generico-proveedores|git@github.com:RetainTechnologiesSL/generico-proveedores.git"
  "generico|git@github.com:RetainTechnologiesSL/generico.git"
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
