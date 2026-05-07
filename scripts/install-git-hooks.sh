#!/bin/bash
# Configure local git hooks to use the repository-managed .githooks directory.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/_project-root.sh"
PROJECT_ROOT="$(vibe_resolve_project_root)"
HOOKS_DIR="$PROJECT_ROOT/.githooks"
PRE_PUSH_HOOK="$HOOKS_DIR/pre-push"

if [ ! -d "$HOOKS_DIR" ]; then
  echo "Error: hook directory not found: $HOOKS_DIR" >&2
  exit 1
fi

if [ ! -f "$PRE_PUSH_HOOK" ]; then
  echo "Error: pre-push hook not found: $PRE_PUSH_HOOK" >&2
  exit 1
fi

chmod +x "$PRE_PUSH_HOOK"

if [ -f "$PROJECT_ROOT/scripts/check-docs-sync.sh" ]; then
  chmod +x "$PROJECT_ROOT/scripts/check-docs-sync.sh"
fi

git -C "$PROJECT_ROOT" config core.hooksPath .githooks

echo "Installed repository hooks."
echo "  core.hooksPath = .githooks"
echo "  active hook     = .githooks/pre-push"
