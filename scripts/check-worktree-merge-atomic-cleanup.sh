#!/bin/bash
# Regression check: mapped merges must be all-or-nothing when cleanup fails.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/_project-root.sh"
PROJECT_ROOT="$(vibe_resolve_project_root)"
SCRIPT_UNDER_TEST="$PROJECT_ROOT/scripts/worktree-merge.sh"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/wt-merge-atomic-cleanup.XXXXXX")"
REPO_DIR="$TMP_ROOT/repo"
MAPPED_WT="$TMP_ROOT/mapped-worktree"
BLOCKING_WT="$TMP_ROOT/blocking-worktree"
REQ_ID="REQ-3333333333"
BRANCH_NAME="feature/$REQ_ID-atomic-cleanup"

cleanup() {
  if [ -d "$REPO_DIR/.git" ]; then
    git -C "$REPO_DIR" worktree remove "$BLOCKING_WT" --force >/dev/null 2>&1 || true
    git -C "$REPO_DIR" worktree remove "$MAPPED_WT" --force >/dev/null 2>&1 || true
  fi
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

mkdir -p "$REPO_DIR/scripts"
cp "$SCRIPT_UNDER_TEST" "$REPO_DIR/scripts/worktree-merge.sh"
cp "$PROJECT_ROOT/scripts/_project-root.sh" "$REPO_DIR/scripts/_project-root.sh"
cp "$PROJECT_ROOT/scripts/_manifest-lock.sh" "$REPO_DIR/scripts/_manifest-lock.sh"

cat > "$REPO_DIR/scripts/regenerate-docs.sh" << 'EOF'
#!/bin/bash
set -euo pipefail
exit 0
EOF

cat > "$REPO_DIR/.requirement-manifest.json" << EOF
{
  "\$schema": ".requirement-manifest.schema.json",
  "version": "1.0",
  "requiresDeployment": true,
  "requirements": [
    {
      "id": "$REQ_ID",
      "name": "atomic cleanup fixture",
      "description": "regression fixture",
      "status": "CODE_REVIEW",
      "priority": "HIGH",
      "createdAt": "2026-01-01T00:00:00Z",
      "updatedAt": "2026-01-01T00:00:00Z",
      "worktreeId": "$BRANCH_NAME"
    }
  ]
}
EOF

cat > "$REPO_DIR/.worktree-manifest.json" << EOF
{
  "\$schema": ".worktree-manifest.schema.json",
  "version": "1.0",
  "worktrees": [
    {
      "id": "$BRANCH_NAME",
      "path": "$MAPPED_WT",
      "branch": "$BRANCH_NAME",
      "baseBranch": "main",
      "requirementIds": ["$REQ_ID"],
      "createdAt": "2026-01-01T00:00:00Z",
      "status": "ACTIVE"
    }
  ]
}
EOF

chmod +x "$REPO_DIR/scripts/worktree-merge.sh" "$REPO_DIR/scripts/regenerate-docs.sh"

git -C "$REPO_DIR" init -b main >/dev/null
git -C "$REPO_DIR" config user.email "regression-check@example.com"
git -C "$REPO_DIR" config user.name "Regression Check"

echo "base" > "$REPO_DIR/README.md"
git -C "$REPO_DIR" add .
git -C "$REPO_DIR" commit -m "init repo" >/dev/null

git -C "$REPO_DIR" checkout -b "$BRANCH_NAME" >/dev/null
echo "feature" >> "$REPO_DIR/README.md"
git -C "$REPO_DIR" add README.md
git -C "$REPO_DIR" commit -m "feature change" >/dev/null
git -C "$REPO_DIR" checkout main >/dev/null

# Mapped worktree is detached so branch can be checked out elsewhere and block deletion.
git -C "$REPO_DIR" worktree add --detach "$MAPPED_WT" "$BRANCH_NAME" >/dev/null
# Blocking worktree keeps branch checked out so `branch -d` fails during cleanup.
git -C "$REPO_DIR" worktree add "$BLOCKING_WT" "$BRANCH_NAME" >/dev/null

PRE_MAIN_HEAD="$(git -C "$REPO_DIR" rev-parse main)"

set +e
OUTPUT="$(cd "$REPO_DIR" && ./scripts/worktree-merge.sh "$REQ_ID" 2>&1)"
STATUS=$?
set -e

if [ "$STATUS" -eq 0 ]; then
  echo "FAIL: expected non-zero status when cleanup fails" >&2
  echo "$OUTPUT" >&2
  exit 1
fi

if ! echo "$OUTPUT" | grep -q "Rolled back merge commit due to cleanup failure"; then
  echo "FAIL: expected merge rollback diagnostic for all-or-nothing mode" >&2
  echo "$OUTPUT" >&2
  exit 1
fi

if ! echo "$OUTPUT" | grep -q "cleanup failed before lifecycle reconciliation"; then
  echo "FAIL: expected lifecycle reconciliation skip diagnostic" >&2
  echo "$OUTPUT" >&2
  exit 1
fi

POST_MAIN_HEAD="$(git -C "$REPO_DIR" rev-parse main)"
if [ "$PRE_MAIN_HEAD" != "$POST_MAIN_HEAD" ]; then
  echo "FAIL: expected main HEAD to be restored after rollback" >&2
  exit 1
fi

if ! jq -e --arg reqId "$REQ_ID" '.requirements[] | select(.id == $reqId and .status == "CODE_REVIEW")' "$REPO_DIR/.requirement-manifest.json" >/dev/null; then
  echo "FAIL: expected requirement status to remain CODE_REVIEW after rollback" >&2
  exit 1
fi

if ! jq -e --arg branch "$BRANCH_NAME" '.worktrees[] | select((.branch == $branch or .id == $branch) and .status == "ACTIVE")' "$REPO_DIR/.worktree-manifest.json" >/dev/null; then
  echo "FAIL: expected worktree status to remain ACTIVE after rollback" >&2
  exit 1
fi

echo "PASS: mapped merge is all-or-nothing when cleanup fails; merge and lifecycle updates are rolled back/skipped."
