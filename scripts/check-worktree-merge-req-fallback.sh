#!/bin/bash
# Regression check for REQ-ID worktree resolution fallback when requirement.worktreeId is missing or stale.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/_project-root.sh"
PROJECT_ROOT="$(vibe_resolve_project_root)"
SCRIPT_UNDER_TEST="$PROJECT_ROOT/scripts/worktree-merge.sh"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/wt-merge-req-fallback.XXXXXX")"
REPO_DIR="$TMP_ROOT/repo"
WORKTREE_PATH="$TMP_ROOT/feature-wt"
REQ_ID="REQ-1111111111"
BRANCH_NAME="feature/$REQ_ID-fallback-check"

cleanup() {
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
      "name": "fallback check",
      "description": "regression fixture",
      "status": "CODE_REVIEW",
      "priority": "MEDIUM",
      "createdAt": "2026-01-01T00:00:00Z",
      "updatedAt": "2026-01-01T00:00:00Z",
      "worktreeId": "feature/stale-branch"
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
      "path": "$WORKTREE_PATH",
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

git -C "$REPO_DIR" worktree add "$WORKTREE_PATH" "$BRANCH_NAME" >/dev/null

# Keep tracked dirty file in the active worktree.
# The merge script should now auto-review and commit tracked worktree changes before cleanup.
echo "dirty" >> "$WORKTREE_PATH/README.md"

set +e
OUTPUT="$(cd "$REPO_DIR" && ./scripts/worktree-merge.sh "$REQ_ID" 2>&1)"
STATUS=$?
set -e

if [ "$STATUS" -ne 0 ]; then
  echo "FAIL: expected merge to succeed with auto-review dirty-worktree handling" >&2
  echo "$OUTPUT" >&2
  exit 1
fi

if ! echo "$OUTPUT" | grep -q "Falling back to requirement linkage lookup"; then
  echo "FAIL: expected stale-worktreeId fallback warning" >&2
  echo "$OUTPUT" >&2
  exit 1
fi

if ! echo "$OUTPUT" | grep -q "Resolved $REQ_ID to branch: $BRANCH_NAME"; then
  echo "FAIL: expected REQ resolution to fallback branch" >&2
  echo "$OUTPUT" >&2
  exit 1
fi

if ! echo "$OUTPUT" | grep -q "Auto-review decision: tracked changes found; auto-committing before cleanup"; then
  echo "FAIL: expected auto-review commit decision message" >&2
  echo "$OUTPUT" >&2
  exit 1
fi

if ! jq -e --arg reqId "$REQ_ID" '.requirements[] | select(.id == $reqId and .status == "MERGED")' "$REPO_DIR/.requirement-manifest.json" >/dev/null; then
  echo "FAIL: expected requirement status to update to MERGED after successful merge" >&2
  exit 1
fi

if ! jq -e --arg branch "$BRANCH_NAME" '.worktrees[] | select((.branch == $branch or .id == $branch) and .status == "MERGED")' "$REPO_DIR/.worktree-manifest.json" >/dev/null; then
  echo "FAIL: expected worktree status to update to MERGED after successful merge" >&2
  exit 1
fi

echo "PASS: REQ fallback resolves stale worktreeId and auto-review handles dirty worktree before successful merge cleanup."
