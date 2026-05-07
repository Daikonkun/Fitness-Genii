#!/bin/bash
# Rollback a merged requirement: revert its merge commit, restore manifests, and recreate worktree.

set -euo pipefail

FORCE="false"
for arg in "$@"; do
  case "$arg" in
    --force) FORCE="true"; shift ;;
  esac
done

REQ_ID="${1:-}"
BASE_BRANCH="${2:-main}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/_project-root.sh"
PROJECT_ROOT="$(vibe_resolve_project_root)"
REQ_MANIFEST="$PROJECT_ROOT/.requirement-manifest.json"
WORKTREE_MANIFEST="$PROJECT_ROOT/.worktree-manifest.json"
source "$PROJECT_ROOT/scripts/_manifest-lock.sh"
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [ -z "$REQ_ID" ]; then
  echo "Usage: $0 REQ-<timestamp> [base-branch] [--force]" >&2
  exit 1
fi

if [[ ! "$REQ_ID" =~ ^REQ-[0-9]{10,}$ ]]; then
  echo "Error: Invalid requirement ID format: $REQ_ID" >&2
  exit 1
fi

if [ ! -f "$REQ_MANIFEST" ]; then
  echo "Error: .requirement-manifest.json not found" >&2
  exit 1
fi

if [ ! -f "$WORKTREE_MANIFEST" ]; then
  echo "Error: .worktree-manifest.json not found" >&2
  exit 1
fi

# --- Validate requirement exists and is in a rollback-eligible status ---

CURRENT_STATUS="$(jq -r --arg reqId "$REQ_ID" '
  .requirements[] | select(.id == $reqId) | .status
' "$REQ_MANIFEST")"

if [ -z "$CURRENT_STATUS" ] || [ "$CURRENT_STATUS" = "null" ]; then
  echo "Error: Requirement not found: $REQ_ID" >&2
  exit 1
fi

if [ "$CURRENT_STATUS" != "MERGED" ] && [ "$CURRENT_STATUS" != "DEPLOYED" ]; then
  echo "Error: Requirement $REQ_ID is in status $CURRENT_STATUS. Only MERGED or DEPLOYED requirements can be rolled back." >&2
  exit 1
fi

# --- Look up the branch from worktree manifest ---

BRANCH="$(jq -r --arg reqId "$REQ_ID" '
  .worktrees[]? | select(.requirementIds[]? == $reqId) | .branch
' "$WORKTREE_MANIFEST" | head -1)"

if [ -z "$BRANCH" ] || [ "$BRANCH" = "null" ]; then
  echo "Error: No worktree branch found for $REQ_ID in .worktree-manifest.json" >&2
  exit 1
fi

WORKTREE_PATH="$(jq -r --arg reqId "$REQ_ID" '
  .worktrees[]? | select(.requirementIds[]? == $reqId) | .path
' "$WORKTREE_MANIFEST" | head -1)"

# --- Ensure working tree is clean ---

if [ -n "$(git -C "$PROJECT_ROOT" status --porcelain)" ]; then
  echo "Error: Working tree is not clean. Commit or stash changes first." >&2
  exit 1
fi

# --- Ensure we are on the base branch ---

CURRENT_BRANCH="$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD)"
if [ "$CURRENT_BRANCH" != "$BASE_BRANCH" ]; then
  echo "Switching to $BASE_BRANCH..."
  git -C "$PROJECT_ROOT" checkout "$BASE_BRANCH"
fi

# --- Find the merge commit for this branch ---

MERGE_COMMIT="$(git -C "$PROJECT_ROOT" log --merges --grep="Merge $BRANCH" --format="%H" | head -1)"

if [ -z "$MERGE_COMMIT" ]; then
  echo "Error: Could not find a merge commit for branch $BRANCH on $BASE_BRANCH" >&2
  exit 1
fi

# --- Safety check: detect newer merge commits after the target ---

NEWER_MERGES="$(git -C "$PROJECT_ROOT" log --merges "$MERGE_COMMIT"..HEAD --format="%H %s")"

if [ -n "$NEWER_MERGES" ]; then
  MERGE_COUNT="$(echo "$NEWER_MERGES" | wc -l | tr -d ' ')"
  echo "⚠️  Warning: There are $MERGE_COUNT merge commit(s) after the target merge." >&2
  echo "   Reverting may cause conflicts with subsequent work." >&2
  echo "" >&2
  echo "Newer merges:" >&2
  echo "$NEWER_MERGES" | head -5 >&2
  echo "" >&2
  if [ "$FORCE" != "true" ]; then
    echo "Aborting rollback. Use --force to override." >&2
    exit 1
  fi
  echo "Proceeding anyway (--force)." >&2
fi

# --- Revert the merge commit ---

echo "Reverting merge commit $MERGE_COMMIT for $BRANCH..."
git -C "$PROJECT_ROOT" revert -m 1 --no-edit "$MERGE_COMMIT"

# --- Recreate the feature branch from HEAD (post-revert) ---

if git -C "$PROJECT_ROOT" show-ref --verify --quiet "refs/heads/$BRANCH"; then
  echo "Branch $BRANCH already exists locally. Skipping branch creation."
else
  echo "Recreating branch $BRANCH from HEAD..."
  git -C "$PROJECT_ROOT" branch "$BRANCH" HEAD
fi

# --- Recreate the worktree if the path doesn't already exist ---

if [ -n "$WORKTREE_PATH" ] && [ "$WORKTREE_PATH" != "null" ] && [ ! -d "$WORKTREE_PATH" ]; then
  echo "Recreating worktree at $WORKTREE_PATH..."
  mkdir -p "$(dirname "$WORKTREE_PATH")"
  git -C "$PROJECT_ROOT" worktree add "$WORKTREE_PATH" "$BRANCH"
fi

# --- Update .requirement-manifest.json ---

jq_update_manifest_locked "$REQ_MANIFEST" \
  '.requirements |= map(
    if .id == $reqId then
      .status = "IN_PROGRESS"
      | .updatedAt = $ts
      | del(.deployedAt)
    else
      .
    end
  )' \
  --arg reqId "$REQ_ID" \
  --arg ts "$TIMESTAMP"

# --- Update .worktree-manifest.json ---

jq_update_manifest_locked "$WORKTREE_MANIFEST" \
  '.worktrees |= map(
    if (.requirementIds[]? == $reqId) then
      .status = "ACTIVE"
      | del(.mergedAt)
    else
      .
    end
  )' \
  --arg reqId "$REQ_ID" \
  --arg ts "$TIMESTAMP"

# --- Update spec file status ---

SPEC_FILE="$(find "$PROJECT_ROOT/docs/requirements" -name "${REQ_ID}-*.md" | head -1)"
if [ -n "$SPEC_FILE" ] && [ -f "$SPEC_FILE" ]; then
  sed -i '' 's/^\*\*Status\*\*: .*/\*\*Status\*\*: IN_PROGRESS/' "$SPEC_FILE"
fi

# --- Regenerate docs ---

"$PROJECT_ROOT/scripts/regenerate-docs.sh" >/dev/null

# --- Commit manifest + doc changes ---

git -C "$PROJECT_ROOT" add \
  .requirement-manifest.json \
  .worktree-manifest.json \
  REQUIREMENTS.md \
  docs/STATUS.md \
  docs/ROADMAP.md \
  docs/DEPENDENCIES.md \
  docs/requirements/ 2>/dev/null || true

git -C "$PROJECT_ROOT" commit -m "chore: rollback $REQ_ID – reverted merge and restored to IN_PROGRESS" --no-verify 2>/dev/null || true

echo ""
echo "✅ Rolled back $REQ_ID"
echo "   Reverted merge commit: $MERGE_COMMIT"
echo "   Status: $CURRENT_STATUS -> IN_PROGRESS"
echo "   Branch: $BRANCH (recreated)"
if [ -n "$WORKTREE_PATH" ] && [ -d "$WORKTREE_PATH" ]; then
  echo "   Worktree: $WORKTREE_PATH (restored)"
fi
echo ""
echo "Next steps:"
echo "   Open the worktree and resume development, or run:"
echo "   /work-on $REQ_ID"
