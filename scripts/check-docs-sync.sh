#!/bin/bash
# Fail-fast guard: verify generated docs are in sync with manifest-backed sources at HEAD.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/_project-root.sh"
PROJECT_ROOT="$(vibe_resolve_project_root)"
cd "$PROJECT_ROOT"

if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
  echo "Error: no commits found; cannot run docs sync check on HEAD." >&2
  exit 1
fi

if [ ! -f "scripts/regenerate-docs.sh" ]; then
  echo "Error: scripts/regenerate-docs.sh not found." >&2
  exit 1
fi

if [ ! -f ".requirement-manifest.json" ]; then
  echo "Error: .requirement-manifest.json not found." >&2
  exit 1
fi

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/docs-sync-check.XXXXXX")"
CHECK_ROOT="$TMP_ROOT/check"
BASELINE_ROOT="$TMP_ROOT/baseline"
REQ_DIFF_FILE="$TMP_ROOT/requirements.diff"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

mkdir -p "$CHECK_ROOT" "$BASELINE_ROOT/docs"

# Export exactly what is committed at HEAD to avoid local working tree noise.
git archive --format=tar HEAD | tar -xf - -C "$CHECK_ROOT"

copy_or_empty() {
  local src="$1"
  local dst="$2"

  if [ -f "$src" ]; then
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
  else
    mkdir -p "$(dirname "$dst")"
    : > "$dst"
  fi
}

copy_or_empty "$CHECK_ROOT/REQUIREMENTS.md" "$BASELINE_ROOT/REQUIREMENTS.md"
copy_or_empty "$CHECK_ROOT/docs/STATUS.md" "$BASELINE_ROOT/docs/STATUS.md"
copy_or_empty "$CHECK_ROOT/docs/ROADMAP.md" "$BASELINE_ROOT/docs/ROADMAP.md"
copy_or_empty "$CHECK_ROOT/docs/DEPENDENCIES.md" "$BASELINE_ROOT/docs/DEPENDENCIES.md"

if [ -d "$CHECK_ROOT/docs/requirements" ]; then
  cp -R "$CHECK_ROOT/docs/requirements" "$BASELINE_ROOT/docs/requirements"
else
  mkdir -p "$BASELINE_ROOT/docs/requirements"
fi

(
  cd "$CHECK_ROOT"
  bash scripts/regenerate-docs.sh >/dev/null
)

normalize_requirements() {
  sed '/^\* Last updated: /d' "$1"
}

MISMATCHES=()

compare_exact_file() {
  local rel_path="$1"
  local before_file="$BASELINE_ROOT/$rel_path"
  local after_file="$CHECK_ROOT/$rel_path"

  if ! cmp -s "$before_file" "$after_file"; then
    MISMATCHES+=("$rel_path")
  fi
}

compare_exact_file "docs/STATUS.md"
compare_exact_file "docs/ROADMAP.md"
compare_exact_file "docs/DEPENDENCIES.md"

if ! diff -u \
  <(normalize_requirements "$BASELINE_ROOT/REQUIREMENTS.md") \
  <(normalize_requirements "$CHECK_ROOT/REQUIREMENTS.md") \
  >/dev/null; then
  MISMATCHES+=("REQUIREMENTS.md (excluding Last updated timestamp)")
fi

if ! diff -qr "$BASELINE_ROOT/docs/requirements" "$CHECK_ROOT/docs/requirements" >"$REQ_DIFF_FILE"; then
  MISMATCHES+=("docs/requirements/*.md")
fi

if [ "${#MISMATCHES[@]}" -gt 0 ]; then
  echo "FAIL: Generated docs are out of sync with committed manifest data (HEAD)." >&2
  echo "" >&2
  echo "Mismatched outputs:" >&2
  for item in "${MISMATCHES[@]}"; do
    echo "  - $item" >&2
  done

  if [ -s "$REQ_DIFF_FILE" ]; then
    echo "" >&2
    echo "docs/requirements drift summary (first 20 lines):" >&2
    sed -n '1,20p' "$REQ_DIFF_FILE" >&2
  fi

  echo "" >&2
  echo "Fix:" >&2
  echo "  1. bash scripts/regenerate-docs.sh" >&2
  echo "  2. git add REQUIREMENTS.md docs/STATUS.md docs/ROADMAP.md docs/DEPENDENCIES.md docs/requirements/" >&2
  echo "  3. Commit the regenerated files, then push again." >&2
  exit 1
fi

echo "PASS: Generated docs are in sync with committed manifest data (HEAD)."
