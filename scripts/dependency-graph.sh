#!/bin/bash
# Regenerate docs and show requirement dependency graph

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/_project-root.sh"
PROJECT_ROOT="$(vibe_resolve_project_root)"

"$PROJECT_ROOT/scripts/regenerate-docs.sh" >/dev/null
cat "$PROJECT_ROOT/docs/DEPENDENCIES.md"
