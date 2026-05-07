#!/bin/bash
# Create a git worktree for a requirement and mark it IN_PROGRESS

set -euo pipefail

REQ_ID="${1:-}"
BASE_BRANCH="${2:-main}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/_project-root.sh"
PROJECT_ROOT="$(vibe_resolve_project_root)"
REQ_MANIFEST="$PROJECT_ROOT/.requirement-manifest.json"
WORKTREE_MANIFEST="$PROJECT_ROOT/.worktree-manifest.json"
source "$PROJECT_ROOT/scripts/_manifest-lock.sh"
GIT_OPERATION_LOCK="$PROJECT_ROOT/.vibe-git-operation.lock"
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
WORKTREE_ROOT_OVERRIDE="${VIBE_WORKTREE_ROOT:-}"

if [ -z "$REQ_ID" ]; then
  echo "Usage: $0 REQ-<timestamp> [base-branch]" >&2
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

if ! jq -e --arg reqId "$REQ_ID" '.requirements[] | select(.id == $reqId)' "$REQ_MANIFEST" >/dev/null; then
  echo "Error: Requirement not found: $REQ_ID" >&2
  exit 1
fi

CURRENT_STATUS="$(jq -r --arg reqId "$REQ_ID" '
  .requirements[] | select(.id == $reqId) | .status // empty
' "$REQ_MANIFEST")"

if [ -z "$CURRENT_STATUS" ]; then
  echo "Error: Requirement status not found: $REQ_ID" >&2
  exit 1
fi

if [ "$CURRENT_STATUS" != "PROPOSED" ] && [ "$CURRENT_STATUS" != "BACKLOG" ]; then
  echo "Error: Requirement $REQ_ID is $CURRENT_STATUS. start-work is only allowed from PROPOSED or BACKLOG." >&2
  exit 1
fi

REQ_NAME="$(jq -r --arg reqId "$REQ_ID" '.requirements[] | select(.id == $reqId) | .name' "$REQ_MANIFEST")"
SLUG="$(echo "$REQ_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//; s/-$//')"
BRANCH_ID="feature/${REQ_ID}-${SLUG}"

resolve_worktree_path() {
  local default_root configured_root candidate_root candidate_path

  default_root="$(dirname "$PROJECT_ROOT")"

  if [ -n "$WORKTREE_ROOT_OVERRIDE" ]; then
    case "$WORKTREE_ROOT_OVERRIDE" in
      /*) configured_root="$WORKTREE_ROOT_OVERRIDE" ;;
      *) configured_root="$PROJECT_ROOT/$WORKTREE_ROOT_OVERRIDE" ;;
    esac
    candidate_root="$configured_root"
  else
    candidate_root="$default_root"
  fi

  candidate_path="$candidate_root/$BRANCH_ID"

  # If no explicit override is provided and parent-based placement cannot be prepared,
  # fall back to a local workspace path for sandboxed/constrained environments.
  if [ -z "$WORKTREE_ROOT_OVERRIDE" ]; then
    if ! mkdir -p "$(dirname "$candidate_path")" >/dev/null 2>&1; then
      candidate_root="$PROJECT_ROOT/.worktrees"
      candidate_path="$candidate_root/$BRANCH_ID"
    fi
  fi

  if ! mkdir -p "$(dirname "$candidate_path")"; then
    echo "Error: Unable to create worktree parent directory: $(dirname "$candidate_path")" >&2
    if [ -z "$WORKTREE_ROOT_OVERRIDE" ]; then
      echo "Hint: set VIBE_WORKTREE_ROOT to a writable path and retry." >&2
    fi
    exit 1
  fi

  printf '%s\n' "$candidate_path"
}

WORKTREE_PATH="$(resolve_worktree_path)"

if ! git -C "$PROJECT_ROOT" rev-parse --verify "$BASE_BRANCH" >/dev/null 2>&1; then
  echo "Error: Base branch does not exist locally: $BASE_BRANCH" >&2
  exit 1
fi

CURRENT_BRANCH="$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
if [ "$CURRENT_BRANCH" != "$BASE_BRANCH" ]; then
  echo "Error: Canonical project root must be on $BASE_BRANCH before starting work (current: ${CURRENT_BRANCH:-UNKNOWN})." >&2
  exit 1
fi

if [ -d "$WORKTREE_PATH" ]; then
  echo "Error: Worktree path already exists: $WORKTREE_PATH" >&2
  exit 1
fi

if git -C "$PROJECT_ROOT" show-ref --verify --quiet "refs/heads/$BRANCH_ID"; then
  echo "Error: Feature branch already exists: $BRANCH_ID" >&2
  echo "Resolve the existing branch before starting this requirement to avoid stale tracker state." >&2
  exit 1
fi

if [ ! -f "$WORKTREE_MANIFEST" ]; then
  with_manifest_lock "$WORKTREE_MANIFEST" bash -c '
    manifest="$1"
    if [ -f "$manifest" ]; then
      exit 0
    fi

    cat > "$manifest" << '\''JSON'\''
{
  "$schema": ".worktree-manifest.schema.json",
  "version": "1.0",
  "worktrees": []
}
JSON
  ' _ "$WORKTREE_MANIFEST"
fi

preflight_worktree_target() {
  if [ -d "$WORKTREE_PATH" ]; then
    echo "Error: Worktree path already exists: $WORKTREE_PATH" >&2
    return 1
  fi

  if git -C "$PROJECT_ROOT" show-ref --verify --quiet "refs/heads/$BRANCH_ID"; then
    echo "Error: Feature branch already exists: $BRANCH_ID" >&2
    echo "Resolve the existing branch before starting this requirement to avoid stale tracker state." >&2
    return 1
  fi
}

start_work_manifest_update_locked() {
  local current_status_locked
  local active_worktree
  local wt_status
  local manifest_collision
  local created_at

  if ! jq -e . "$REQ_MANIFEST" >/dev/null; then
    echo "Error: Invalid JSON in $REQ_MANIFEST" >&2
    return 1
  fi

  if ! jq -e . "$WORKTREE_MANIFEST" >/dev/null; then
    echo "Error: Invalid JSON in $WORKTREE_MANIFEST" >&2
    return 1
  fi

  current_status_locked="$(jq -r --arg reqId "$REQ_ID" '
    .requirements[] | select(.id == $reqId) | .status // empty
  ' "$REQ_MANIFEST")"

  if [ -z "$current_status_locked" ]; then
    echo "Error: Requirement not found: $REQ_ID" >&2
    return 1
  fi

  if [ "$current_status_locked" != "PROPOSED" ] && [ "$current_status_locked" != "BACKLOG" ]; then
    echo "Error: Requirement $REQ_ID is $current_status_locked. start-work is only allowed from PROPOSED or BACKLOG." >&2
    return 1
  fi

  active_worktree="$(jq -r --arg reqId "$REQ_ID" '
    .requirements[] | select(.id == $reqId) | .worktreeId // empty
  ' "$REQ_MANIFEST")"

  if [ -n "$active_worktree" ]; then
    wt_status="$(jq -r --arg wtId "$active_worktree" '
      .worktrees[]? | select(.id == $wtId) | .status // empty
    ' "$WORKTREE_MANIFEST" | head -1)"
    if [ "$wt_status" = "ACTIVE" ]; then
      echo "Error: Requirement $REQ_ID already has an active worktree: $active_worktree" >&2
      return 1
    fi
  fi

  manifest_collision="$(jq -r --arg id "$BRANCH_ID" --arg path "$WORKTREE_PATH" '
    .worktrees[]?
    | select(.status == "ACTIVE")
    | select(.id == $id or .branch == $id or .path == $path)
    | .id
  ' "$WORKTREE_MANIFEST" | head -1)"
  if [ -n "$manifest_collision" ]; then
    echo "Error: Active worktree manifest entry already exists for $BRANCH_ID or $WORKTREE_PATH: $manifest_collision" >&2
    return 1
  fi

  created_at="$(jq -r --arg reqId "$REQ_ID" '.requirements[] | select(.id == $reqId) | .createdAt' "$REQ_MANIFEST")"
  if [ -n "$created_at" ] && [ "$created_at" != "null" ] && [[ "$TIMESTAMP" < "$created_at" ]]; then
    echo "Error: updatedAt ($TIMESTAMP) would be before createdAt ($created_at)" >&2
    return 1
  fi

  if ! _jq_update_manifest_locked_inner "$REQ_MANIFEST" \
    '.requirements |= map(
       if .id == $reqId
       then .status = "IN_PROGRESS" | .worktreeId = $branch | .updatedAt = $ts
       else .
       end
     )' \
    --arg reqId "$REQ_ID" \
    --arg branch "$BRANCH_ID" \
    --arg ts "$TIMESTAMP"; then
    return 1
  fi

  if ! _jq_update_manifest_locked_inner "$WORKTREE_MANIFEST" \
    '.worktrees += [{
       "id": $id,
       "path": $path,
       "branch": $branch,
       "baseBranch": $base,
       "requirementIds": [$reqId],
       "createdAt": $ts,
       "status": "ACTIVE"
     }]' \
    --arg id "$BRANCH_ID" \
    --arg path "$WORKTREE_PATH" \
    --arg branch "$BRANCH_ID" \
    --arg base "$BASE_BRANCH" \
    --arg reqId "$REQ_ID" \
    --arg ts "$TIMESTAMP"; then
    return 1
  fi
}

start_work_workflow_locked() {
  if ! preflight_worktree_target; then
    return 1
  fi

  if ! with_manifest_locks "$REQ_MANIFEST" "$WORKTREE_MANIFEST" start_work_manifest_update_locked; then
    return 1
  fi

  if ! "$PROJECT_ROOT/scripts/regenerate-docs.sh" >/dev/null; then
    return 1
  fi

  # Generate/update Development Plan for idempotent execution context (REQ-1774681642)
  "$PROJECT_ROOT/scripts/generate-plan.sh" "$REQ_ID" || echo "Warning: Plan generation failed (non-fatal)"

  if ! git -C "$PROJECT_ROOT" add \
    .requirement-manifest.json \
    .worktree-manifest.json \
    REQUIREMENTS.md \
    docs/STATUS.md \
    docs/ROADMAP.md \
    docs/DEPENDENCIES.md \
    docs/requirements/; then
    echo "Error: Failed to stage start-work tracker changes." >&2
    return 1
  fi

  if git -C "$PROJECT_ROOT" diff --cached --quiet; then
    echo "Error: No start-work tracker changes were staged." >&2
    return 1
  fi

  if ! git -C "$PROJECT_ROOT" commit -m "chore: start work on $REQ_ID" --no-verify; then
    echo "Error: Failed to commit start-work tracker changes." >&2
    return 1
  fi

  if ! git -C "$PROJECT_ROOT" worktree add -b "$BRANCH_ID" "$WORKTREE_PATH" "$BASE_BRANCH"; then
    echo "Error: Failed to create worktree after tracker state was committed." >&2
    echo "Recovery: inspect $REQ_MANIFEST and $WORKTREE_MANIFEST, then retry after resolving branch/path state." >&2
    return 1
  fi
}

with_manifest_lock "$GIT_OPERATION_LOCK" start_work_workflow_locked

echo "✅ Work started for $REQ_ID"
echo "Worktree ID: $BRANCH_ID"
echo "Path: $WORKTREE_PATH"
echo "Base branch: $BASE_BRANCH"
