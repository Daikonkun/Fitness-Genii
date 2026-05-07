#!/bin/bash
# Regression check: init-project.sh must clear only origin:vibe-master requirements.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/_project-root.sh"
PROJECT_ROOT="$(vibe_resolve_project_root)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/init-selective-clear.XXXXXX")"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

assert_eq() {
  local actual="$1"
  local expected="$2"
  local label="$3"

  if [ "$actual" != "$expected" ]; then
    echo "FAIL: $label" >&2
    echo "  expected: $expected" >&2
    echo "  actual:   $actual" >&2
    exit 1
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"

  if [[ "$haystack" != *"$needle"* ]]; then
    echo "FAIL: $label" >&2
    echo "  expected to contain: $needle" >&2
    echo "  actual: $haystack" >&2
    exit 1
  fi
}

cd "$TMP_ROOT"
git init -q
mkdir -p scripts docs/requirements

cp "$PROJECT_ROOT/scripts/init-project.sh" scripts/
cp "$PROJECT_ROOT/scripts/_project-root.sh" scripts/
cp "$PROJECT_ROOT/scripts/_manifest-lock.sh" scripts/
chmod +x scripts/*.sh

cat > .requirement-manifest.json << 'JSON'
{
  "$schema": ".requirement-manifest.schema.json",
  "version": "1.0",
  "projectName": "Old Name",
  "requiresDeployment": true,
  "requirements": [
    {"id": "REQ-1", "origin": "vibe-master"},
    {"id": "REQ-2", "origin": "project"},
    {"id": "REQ-3"},
    {"id": "REQ-4", "origin": null}
  ]
}
JSON

cat > .worktree-manifest.json << 'JSON'
{
  "$schema": ".worktree-manifest.schema.json",
  "version": "1.0",
  "worktrees": [
    {"id": "REQ-2", "branch": "feature/REQ-2"}
  ]
}
JSON

touch docs/requirements/REQ-1-template.md
touch docs/requirements/REQ-2-project.md
touch docs/requirements/REQ-3-project.md
touch docs/requirements/REQ-4-project.md
touch docs/requirements/EXAMPLE-REQ-keep.md

output="$(bash scripts/init-project.sh "New Name" 2>&1)"

remaining_ids="$(jq -r '.requirements[].id' .requirement-manifest.json | paste -sd, -)"
project_name="$(jq -r '.projectName' .requirement-manifest.json)"
worktree_count="$(jq -r '.worktrees | length' .worktree-manifest.json)"
spec_files="$(ls docs/requirements | sort | paste -sd, -)"

assert_eq "$remaining_ids" "REQ-2,REQ-3,REQ-4" "remaining requirement IDs"
assert_eq "$project_name" "New Name" "projectName update"
assert_eq "$worktree_count" "0" "worktree manifest reset"
assert_eq "$spec_files" "EXAMPLE-REQ-keep.md,REQ-2-project.md,REQ-3-project.md,REQ-4-project.md" "remaining requirement spec files"

assert_contains "$output" "Cleared 1 Vibe Master requirement(s)" "clear-count report"
assert_contains "$output" "Preserved 3 project-owned requirement(s)" "preserve-count report"

echo "PASS: init-project.sh selectively clears origin:vibe-master requirements and preserves project-owned history."
