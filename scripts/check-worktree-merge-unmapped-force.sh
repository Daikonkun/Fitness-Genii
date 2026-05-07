#!/bin/bash
# Regression check for forced unmapped merge branch-cleanup behavior.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/_project-root.sh"
PROJECT_ROOT="$(vibe_resolve_project_root)"
SCRIPT_UNDER_TEST="$PROJECT_ROOT/scripts/worktree-merge.sh"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/wt-merge-unmapped-regression.XXXXXX")"
REPO_DIR="$TMP_ROOT/repo"
BLOCKING_WT="$TMP_ROOT/blocking-worktree"
FEATURE_BRANCH="feature/unmapped-force-regression"

cleanup() {
  if [ -d "$REPO_DIR/.git" ]; then
    git -C "$REPO_DIR" worktree remove "$BLOCKING_WT" --force >/dev/null 2>&1 || true
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

cat > "$REPO_DIR/.requirement-manifest.json" << 'EOF'
{
  "$schema": ".requirement-manifest.schema.json",
  "version": "1.0",
  "requiresDeployment": true,
  "requirements": []
}
EOF

cat > "$REPO_DIR/.worktree-manifest.json" << 'EOF'
{
  "$schema": ".worktree-manifest.schema.json",
  "version": "1.0",
  "worktrees": []
}
EOF

chmod +x "$REPO_DIR/scripts/worktree-merge.sh"
chmod +x "$REPO_DIR/scripts/regenerate-docs.sh"

git -C "$REPO_DIR" init -b main >/dev/null
git -C "$REPO_DIR" config user.email "regression-check@example.com"
git -C "$REPO_DIR" config user.name "Regression Check"

echo "base" > "$REPO_DIR/README.md"
git -C "$REPO_DIR" add .
git -C "$REPO_DIR" commit -m "init regression repo" >/dev/null

git -C "$REPO_DIR" checkout -b "$FEATURE_BRANCH" >/dev/null
echo "feature" >> "$REPO_DIR/README.md"
git -C "$REPO_DIR" add README.md
git -C "$REPO_DIR" commit -m "feature change" >/dev/null
git -C "$REPO_DIR" checkout main >/dev/null

# Keep the feature branch checked out elsewhere so branch deletion fails.
git -C "$REPO_DIR" worktree add "$BLOCKING_WT" "$FEATURE_BRANCH" >/dev/null

set +e
MERGE_OUTPUT="$(
  cd "$REPO_DIR" &&
    ./scripts/worktree-merge.sh "$FEATURE_BRANCH" main --force 2>&1
)"
MERGE_STATUS=$?
set -e

if [ "$MERGE_STATUS" -ne 0 ]; then
  echo "FAIL: expected forced unmapped merge to succeed" >&2
  echo "$MERGE_OUTPUT" >&2
  exit 1
fi

if ! echo "$MERGE_OUTPUT" | grep -qi "could not delete branch during forced unmapped merge"; then
  echo "FAIL: expected cleanup warning about branch deletion failure" >&2
  echo "$MERGE_OUTPUT" >&2
  exit 1
fi

if ! echo "$MERGE_OUTPUT" | grep -qi "no requirement status was updated"; then
  echo "FAIL: expected explicit no-status-updated message" >&2
  echo "$MERGE_OUTPUT" >&2
  exit 1
fi

if ! git -C "$REPO_DIR" merge-base --is-ancestor "$FEATURE_BRANCH" main; then
  echo "FAIL: expected merge commit to land on main" >&2
  exit 1
fi

if ! git -C "$REPO_DIR" rev-parse --verify "$FEATURE_BRANCH" >/dev/null 2>&1; then
  echo "FAIL: expected feature branch to remain when deletion fails" >&2
  exit 1
fi

echo "PASS: forced unmapped merge tolerates branch cleanup failure and reports skipped requirement updates."
