#!/bin/bash
# Regression check for ambiguous ACTIVE worktree mappings during REQ-ID resolution.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/_project-root.sh"
PROJECT_ROOT="$(vibe_resolve_project_root)"
SCRIPT_UNDER_TEST="$PROJECT_ROOT/scripts/worktree-merge.sh"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/wt-merge-req-ambiguous.XXXXXX")"
REPO_DIR="$TMP_ROOT/repo"
REQ_ID="REQ-2222222222"
BRANCH_A="feature/$REQ_ID-a"
BRANCH_B="feature/$REQ_ID-b"

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
      "name": "ambiguous mapping fixture",
      "description": "regression fixture",
      "status": "CODE_REVIEW",
      "priority": "MEDIUM",
      "createdAt": "2026-01-01T00:00:00Z",
      "updatedAt": "2026-01-01T00:00:00Z"
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
      "id": "$BRANCH_A",
      "path": "$TMP_ROOT/wt-a",
      "branch": "$BRANCH_A",
      "baseBranch": "main",
      "requirementIds": ["$REQ_ID"],
      "createdAt": "2026-01-01T00:00:00Z",
      "status": "ACTIVE"
    },
    {
      "id": "$BRANCH_B",
      "path": "$TMP_ROOT/wt-b",
      "branch": "$BRANCH_B",
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

set +e
OUTPUT="$(cd "$REPO_DIR" && ./scripts/worktree-merge.sh "$REQ_ID" 2>&1)"
STATUS=$?
set -e

if [ "$STATUS" -eq 0 ]; then
  echo "FAIL: expected non-zero status for ambiguous ACTIVE mappings" >&2
  echo "$OUTPUT" >&2
  exit 1
fi

if ! echo "$OUTPUT" | grep -q "Ambiguous ACTIVE worktree mappings"; then
  echo "FAIL: expected ambiguity diagnostic" >&2
  echo "$OUTPUT" >&2
  exit 1
fi

if ! echo "$OUTPUT" | grep -q "$BRANCH_A" || ! echo "$OUTPUT" | grep -q "$BRANCH_B"; then
  echo "FAIL: expected conflicting candidates listed in diagnostics" >&2
  echo "$OUTPUT" >&2
  exit 1
fi

echo "PASS: ambiguous ACTIVE REQ mappings fail with explicit candidate diagnostics."
