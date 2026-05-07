#!/bin/bash
# Regression check: terminal requirements must not retain ACTIVE worktrees; repair path must reconcile existing drift.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/_project-root.sh"
PROJECT_ROOT="$(vibe_resolve_project_root)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/req-wt-lifecycle-check.XXXXXX")"
CHECK_ROOT="$TMP_ROOT/check"
TEST_REQ_ID="REQ-9999999999000002001"
TEST_WT_ID="feature/REQ-9999999999000002001-lifecycle-check"
STALE_WT_ID="feature/REQ-9999999999000002001-stale-pointer"
TEST_TS="2026-04-21T00:00:00Z"

cleanup() {
  if [ -d "$CHECK_ROOT/.git" ]; then
    while IFS= read -r wt_path; do
      [ -z "$wt_path" ] && continue
      if [ "$wt_path" != "$CHECK_ROOT" ] && [[ "$wt_path" == "$TMP_ROOT"/* ]]; then
        git -C "$CHECK_ROOT" worktree remove "$wt_path" --force >/dev/null 2>&1 || true
      fi
    done < <(git -C "$CHECK_ROOT" worktree list --porcelain 2>/dev/null | awk '/^worktree / {print $2}')
  fi

  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

assert_prereqs() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "FAIL: jq is required." >&2
    exit 1
  fi
}

copy_repo_snapshot() {
  mkdir -p "$CHECK_ROOT"
  (
    cd "$PROJECT_ROOT"
    tar -cf - --exclude='.git' .
  ) | tar -xf - -C "$CHECK_ROOT"
}

init_git_repo() {
  git -C "$CHECK_ROOT" init -b main >/dev/null
  git -C "$CHECK_ROOT" config user.email "req-wt-lifecycle-check@example.com"
  git -C "$CHECK_ROOT" config user.name "Requirement Worktree Lifecycle Check"
  git -C "$CHECK_ROOT" add .
  git -C "$CHECK_ROOT" commit -m "baseline snapshot" >/dev/null
}

assert_prereqs
copy_repo_snapshot
init_git_repo

cd "$CHECK_ROOT"

jq --arg req "$TEST_REQ_ID" --arg wt "$TEST_WT_ID" --arg ts "$TEST_TS" '
  .requirements += [{
    id: $req,
    name: "Lifecycle invariant regression fixture",
    description: "Synthetic requirement used by check-requirement-worktree-lifecycle.sh",
    status: "CODE_REVIEW",
    priority: "LOW",
    createdAt: $ts,
    updatedAt: $ts,
    worktreeId: $wt
  }]
' .requirement-manifest.json > .requirement-manifest.json.tmp
mv .requirement-manifest.json.tmp .requirement-manifest.json

jq --arg wt "$TEST_WT_ID" --arg req "$TEST_REQ_ID" --arg ts "$TEST_TS" --arg path "$CHECK_ROOT/synthetic-wt" '
  .worktrees += [{
    id: $wt,
    path: $path,
    branch: $wt,
    baseBranch: "main",
    requirementIds: [$req],
    createdAt: $ts,
    status: "ACTIVE"
  }]
' .worktree-manifest.json > .worktree-manifest.json.tmp
mv .worktree-manifest.json.tmp .worktree-manifest.json

WT_ID="$(jq -r --arg reqId "$TEST_REQ_ID" '.requirements[] | select(.id == $reqId) | .worktreeId // empty' .requirement-manifest.json)"
if [ "$WT_ID" != "$TEST_WT_ID" ]; then
  echo "FAIL: synthetic fixture did not attach expected worktreeId for $TEST_REQ_ID." >&2
  exit 1
fi

WT_STATUS="$(jq -r --arg wtId "$WT_ID" '.worktrees[] | select(.id == $wtId) | .status // empty' .worktree-manifest.json | head -1)"
if [ "$WT_STATUS" != "ACTIVE" ]; then
  echo "FAIL: expected ACTIVE synthetic worktree status, got '$WT_STATUS'." >&2
  exit 1
fi

set +e
MERGE_BLOCK_OUTPUT="$(bash scripts/update-requirement-status.sh "$TEST_REQ_ID" MERGED --no-refresh 2>&1)"
MERGE_BLOCK_STATUS=$?
set -e

if [ "$MERGE_BLOCK_STATUS" -eq 0 ]; then
  echo "FAIL: expected MERGED transition to be blocked while worktree is ACTIVE." >&2
  exit 1
fi

if ! grep -Fq "ACTIVE worktree link(s) exist" <<< "$MERGE_BLOCK_OUTPUT"; then
  echo "FAIL: blocked MERGED transition did not surface lifecycle invariant error." >&2
  echo "$MERGE_BLOCK_OUTPUT" >&2
  exit 1
fi

# Verify reverse-link enforcement when requirement.worktreeId is missing.
jq --arg req "$TEST_REQ_ID" '
  .requirements |= map(if .id == $req then del(.worktreeId) else . end)
' .requirement-manifest.json > .requirement-manifest.json.tmp
mv .requirement-manifest.json.tmp .requirement-manifest.json

set +e
REVERSE_BLOCK_OUTPUT="$(bash scripts/update-requirement-status.sh "$TEST_REQ_ID" MERGED --no-refresh 2>&1)"
REVERSE_BLOCK_STATUS=$?
set -e

if [ "$REVERSE_BLOCK_STATUS" -eq 0 ]; then
  echo "FAIL: expected MERGED transition to be blocked by reverse ACTIVE worktree linkage." >&2
  exit 1
fi

if ! grep -Fq "ACTIVE worktree link(s) exist" <<< "$REVERSE_BLOCK_OUTPUT"; then
  echo "FAIL: reverse-link guard did not surface expected lifecycle invariant error." >&2
  echo "$REVERSE_BLOCK_OUTPUT" >&2
  exit 1
fi

# Seed legacy drift intentionally so repair path can be validated.
bash scripts/update-requirement-status.sh "$TEST_REQ_ID" MERGED --force --no-refresh >/dev/null

WT_STATUS_AFTER_FORCE="$(jq -r --arg wtId "$WT_ID" '.worktrees[] | select(.id == $wtId) | .status // empty' .worktree-manifest.json | head -1)"
if [ "$WT_STATUS_AFTER_FORCE" != "ACTIVE" ]; then
  echo "FAIL: expected seeded drift to keep worktree ACTIVE, got '$WT_STATUS_AFTER_FORCE'." >&2
  exit 1
fi

bash scripts/reconcile-lifecycle-invariants.sh --apply --no-refresh >/dev/null

WT_STATUS_AFTER_REPAIR="$(jq -r --arg wtId "$WT_ID" '.worktrees[] | select(.id == $wtId) | .status // empty' .worktree-manifest.json | head -1)"
if [ "$WT_STATUS_AFTER_REPAIR" != "MERGED" ]; then
  echo "FAIL: lifecycle reconciliation did not repair ACTIVE worktree drift ($WT_STATUS_AFTER_REPAIR)." >&2
  exit 1
fi

REQ_STATUS_FINAL="$(jq -r --arg reqId "$TEST_REQ_ID" '.requirements[] | select(.id == $reqId) | .status // empty' .requirement-manifest.json)"
if [ "$REQ_STATUS_FINAL" != "MERGED" ]; then
  echo "FAIL: reconciliation unexpectedly changed requirement status ($REQ_STATUS_FINAL)." >&2
  exit 1
fi

# Verify stale requirement.worktreeId pointers are cleared by reconciliation.
jq --arg req "$TEST_REQ_ID" --arg stale "$STALE_WT_ID" --arg ts "$TEST_TS" '
  .requirements |= map(
    if .id == $req then
      .status = "DEPLOYED"
      | .worktreeId = $stale
      | .updatedAt = $ts
    else
      .
    end
  )
' .requirement-manifest.json > .requirement-manifest.json.tmp
mv .requirement-manifest.json.tmp .requirement-manifest.json

bash scripts/reconcile-lifecycle-invariants.sh --apply --no-refresh >/dev/null

STALE_PTR_VALUE="$(jq -r --arg req "$TEST_REQ_ID" '.requirements[] | select(.id == $req) | .worktreeId // empty' .requirement-manifest.json)"
if [ -n "$STALE_PTR_VALUE" ]; then
  echo "FAIL: reconciliation did not clear stale requirement.worktreeId pointer ($STALE_PTR_VALUE)." >&2
  exit 1
fi

echo "PASS: lifecycle invariant blocks terminal transitions (direct/reverse), force override is honored, and reconciliation repairs drift plus clears stale worktree pointers."
