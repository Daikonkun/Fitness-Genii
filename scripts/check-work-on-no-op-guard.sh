#!/bin/bash
# Regression check: work-on no-op guard must include tracked working-tree evidence.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/_project-root.sh"
PROJECT_ROOT="$(vibe_resolve_project_root)"
PROMPT_FILE="$PROJECT_ROOT/.github/prompts/work-on.prompt.md"

if [ ! -f "$PROMPT_FILE" ]; then
  echo "FAIL: missing prompt file: $PROMPT_FILE" >&2
  exit 1
fi

MISSING=0

assert_contains() {
  local needle="$1"
  local label="$2"

  if ! grep -Fq "$needle" "$PROMPT_FILE"; then
    echo "FAIL: missing $label" >&2
    echo "  expected text: $needle" >&2
    MISSING=1
  fi
}

assert_contains "git -C <worktree-path> diff --name-status <base-branch>...HEAD" "commit-diff no-op evidence command"
assert_contains "git -C <worktree-path> status --porcelain --untracked-files=no" "tracked working-tree no-op evidence command"
assert_contains "Treat evidence as present when either signal is non-empty." "dual-signal no-op evidence rule"
assert_contains "No-op evidence is tracked-only: staged and unstaged tracked deltas count, while untracked files are excluded." "tracked-only evidence constraint"
assert_contains "git rev-parse --git-common-dir" "canonical root resolver command"
assert_contains "dirname" "canonical root resolver path derivation"
assert_contains "<canonical-root>/.worktree-manifest.json" "canonical manifest lookup"
assert_contains "git rev-parse --abbrev-ref HEAD" "fallback branch identity resolver"
assert_contains "./scripts/start-work.sh <REQ-ID>" "actionable recovery command for missing mapping"
assert_contains "./scripts/worktree-list.sh" "actionable recovery command for worktree inspection"

if [ "$MISSING" -ne 0 ]; then
  echo "FAIL: work-on no-op guard contract is incomplete." >&2
  exit 1
fi

echo "PASS: work-on no-op guard includes dual evidence signals and tracked-only semantics."