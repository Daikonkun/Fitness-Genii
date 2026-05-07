#!/bin/bash
# Regression check: upgrade --apply must merge manifest metadata even when only manifests differ.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/_project-root.sh"
PROJECT_ROOT="$(vibe_resolve_project_root)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/upgrade-manifest-history-check.XXXXXX")"
CHECK_ROOT="$TMP_ROOT/check"
TEMPLATE_REPO="$TMP_ROOT/template-github.com-source"
UPGRADE_WORKTREE="$TMP_ROOT/upgrade-worktree"
UPGRADE_OUTPUT="$TMP_ROOT/upgrade-output.log"

SEED_REQ_ID="REQ-9999999999000000001"
SEED_WORKTREE_ID="feature/REQ-9999999999000000001-upgrade-history-seed"
SEED_TIMESTAMP="2026-04-20T00:00:00Z"
REQ_VERSION_SENTINEL="9.9-manifest-only-check"
WT_VERSION_SENTINEL="8.8-manifest-only-check"

REQ_COUNT_BEFORE="0"
WT_COUNT_BEFORE="0"

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

copy_repo_snapshot() {
  local src_root="$1"
  local dst_root="$2"

  mkdir -p "$dst_root"
  (
    cd "$src_root"
    tar -cf - --exclude='.git' .
  ) | tar -xf - -C "$dst_root"
}

init_git_repo() {
  local repo_root="$1"
  local user_name="$2"
  local user_email="$3"
  local commit_message="$4"

  git -C "$repo_root" init -b main >/dev/null
  git -C "$repo_root" config user.email "$user_email"
  git -C "$repo_root" config user.name "$user_name"
  git -C "$repo_root" add .
  git -C "$repo_root" commit -m "$commit_message" >/dev/null
}

assert_prereqs() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "FAIL: jq is required." >&2
    exit 1
  fi
}

seed_manifest_history() {
  local req_manifest="$CHECK_ROOT/.requirement-manifest.json"
  local wt_manifest="$CHECK_ROOT/.worktree-manifest.json"
  local req_tmp="$req_manifest.seed.tmp"
  local wt_tmp="$wt_manifest.seed.tmp"

  jq \
    --arg req_id "$SEED_REQ_ID" \
    --arg wt_id "$SEED_WORKTREE_ID" \
    --arg ts "$SEED_TIMESTAMP" \
    '.requirements += [{
      id: $req_id,
      name: "Upgrade history preservation seed",
      description: "Synthetic entry used by check-upgrade-manifest-history.sh",
      status: "IN_PROGRESS",
      priority: "LOW",
      createdAt: $ts,
      updatedAt: $ts,
      worktreeId: $wt_id,
      origin: "regression-check"
    }]' "$req_manifest" > "$req_tmp"
  mv "$req_tmp" "$req_manifest"

  jq \
    --arg wt_id "$SEED_WORKTREE_ID" \
    --arg req_id "$SEED_REQ_ID" \
    --arg wt_path "$CHECK_ROOT/seed-worktree" \
    --arg ts "$SEED_TIMESTAMP" \
    '.worktrees += [{
      id: $wt_id,
      path: $wt_path,
      branch: $wt_id,
      baseBranch: "main",
      requirementIds: [$req_id],
      createdAt: $ts,
      status: "ACTIVE"
    }]' "$wt_manifest" > "$wt_tmp"
  mv "$wt_tmp" "$wt_manifest"
}

create_manifest_only_template_repo() {
  local req_manifest="$TEMPLATE_REPO/.requirement-manifest.json"
  local wt_manifest="$TEMPLATE_REPO/.worktree-manifest.json"
  local req_tmp="$req_manifest.template.tmp"
  local wt_tmp="$wt_manifest.template.tmp"

  copy_repo_snapshot "$CHECK_ROOT" "$TEMPLATE_REPO"

  jq --arg v "$REQ_VERSION_SENTINEL" '.version = $v | .requirements = []' "$req_manifest" > "$req_tmp"
  mv "$req_tmp" "$req_manifest"

  jq --arg v "$WT_VERSION_SENTINEL" '.version = $v | .worktrees = []' "$wt_manifest" > "$wt_tmp"
  mv "$wt_tmp" "$wt_manifest"

  init_git_repo "$TEMPLATE_REPO" "Upgrade Template Check" "upgrade-template-check@example.com" "template manifest-only snapshot"
}

assert_manifest_only_fixture() {
  local non_manifest_diff="$TMP_ROOT/non-manifest.diff"

  if ! diff -ruN \
    --exclude='.git' \
    --exclude='.upgrade-template' \
    --exclude='.requirement-manifest.json' \
    --exclude='.worktree-manifest.json' \
    "$TEMPLATE_REPO" "$CHECK_ROOT" > "$non_manifest_diff"; then
    echo "FAIL: template fixture contains non-manifest differences." >&2
    head -n 120 "$non_manifest_diff" >&2 || true
    exit 1
  fi

  if cmp -s "$TEMPLATE_REPO/.requirement-manifest.json" "$CHECK_ROOT/.requirement-manifest.json"; then
    echo "FAIL: requirement manifest fixture is not manifest-only (no manifest diff detected)." >&2
    exit 1
  fi

  if cmp -s "$TEMPLATE_REPO/.worktree-manifest.json" "$CHECK_ROOT/.worktree-manifest.json"; then
    echo "FAIL: worktree manifest fixture is not manifest-only (no manifest diff detected)." >&2
    exit 1
  fi
}

run_upgrade_apply() {
  local exit_code

  set +e
  (
    cd "$CHECK_ROOT"
    bash scripts/upgrade.sh \
      --template-repo "$TEMPLATE_REPO" \
      --worktree-path "$UPGRADE_WORKTREE" \
      --branch-name "chore/upgrade-manifest-history-check" \
      --apply \
      --yes
  ) > "$UPGRADE_OUTPUT" 2>&1
  exit_code=$?
  set -e

  if [ "$exit_code" -ne 0 ]; then
    echo "FAIL: upgrade apply command failed during regression check." >&2
    cat "$UPGRADE_OUTPUT" >&2
    exit "$exit_code"
  fi
}

assert_manifest_only_apply_path() {
  if ! grep -Fq "No differences detected between template and worktree." "$UPGRADE_OUTPUT"; then
    echo "FAIL: upgrade output did not enter the manifest-only apply branch." >&2
    cat "$UPGRADE_OUTPUT" >&2
    exit 1
  fi

  if ! grep -Fq "Manifest metadata merged in isolated worktree." "$UPGRADE_OUTPUT"; then
    echo "FAIL: upgrade output did not confirm manifest metadata merge." >&2
    cat "$UPGRADE_OUTPUT" >&2
    exit 1
  fi

}

assert_history_preserved() {
  local req_manifest="$UPGRADE_WORKTREE/.requirement-manifest.json"
  local wt_manifest="$UPGRADE_WORKTREE/.worktree-manifest.json"
  local req_count_after
  local wt_count_after
  local req_version_after
  local wt_version_after

  if [ ! -f "$req_manifest" ] || [ ! -f "$wt_manifest" ]; then
    echo "FAIL: upgrade output manifests are missing from $UPGRADE_WORKTREE." >&2
    exit 1
  fi

  req_count_after="$(jq -r '.requirements | length' "$req_manifest")"
  wt_count_after="$(jq -r '.worktrees | length' "$wt_manifest")"

  if [ "$req_count_after" -lt "$REQ_COUNT_BEFORE" ]; then
    echo "FAIL: requirement manifest history shrank after upgrade apply ($REQ_COUNT_BEFORE -> $req_count_after)." >&2
    exit 1
  fi

  if [ "$wt_count_after" -lt "$WT_COUNT_BEFORE" ]; then
    echo "FAIL: worktree manifest history shrank after upgrade apply ($WT_COUNT_BEFORE -> $wt_count_after)." >&2
    exit 1
  fi

  if ! jq -e --arg id "$SEED_REQ_ID" '.requirements[] | select(.id == $id)' "$req_manifest" >/dev/null; then
    echo "FAIL: seeded requirement history entry was lost after upgrade apply." >&2
    exit 1
  fi

  if ! jq -e --arg id "$SEED_WORKTREE_ID" '.worktrees[] | select(.id == $id)' "$wt_manifest" >/dev/null; then
    echo "FAIL: seeded worktree history entry was lost after upgrade apply." >&2
    exit 1
  fi

  req_version_after="$(jq -r '.version' "$req_manifest")"
  wt_version_after="$(jq -r '.version' "$wt_manifest")"

  if [ "$req_version_after" != "$REQ_VERSION_SENTINEL" ]; then
    echo "FAIL: requirement manifest metadata was not merged in manifest-only apply path (expected version $REQ_VERSION_SENTINEL, got $req_version_after)." >&2
    exit 1
  fi

  if [ "$wt_version_after" != "$WT_VERSION_SENTINEL" ]; then
    echo "FAIL: worktree manifest metadata was not merged in manifest-only apply path (expected version $WT_VERSION_SENTINEL, got $wt_version_after)." >&2
    exit 1
  fi

  echo "PASS: upgrade apply preserved history and merged manifest metadata in manifest-only mode ($REQ_COUNT_BEFORE/$WT_COUNT_BEFORE -> $req_count_after/$wt_count_after)."
}

assert_prereqs

copy_repo_snapshot "$PROJECT_ROOT" "$CHECK_ROOT"
init_git_repo "$CHECK_ROOT" "Upgrade Manifest History Check" "upgrade-manifest-history-check@example.com" "baseline snapshot"

seed_manifest_history

git -C "$CHECK_ROOT" add .requirement-manifest.json .worktree-manifest.json
git -C "$CHECK_ROOT" commit -m "seed manifest history" >/dev/null

REQ_COUNT_BEFORE="$(jq -r '.requirements | length' "$CHECK_ROOT/.requirement-manifest.json")"
WT_COUNT_BEFORE="$(jq -r '.worktrees | length' "$CHECK_ROOT/.worktree-manifest.json")"

create_manifest_only_template_repo
assert_manifest_only_fixture
run_upgrade_apply
assert_manifest_only_apply_path
assert_history_preserved
