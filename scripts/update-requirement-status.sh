#!/bin/bash
# Update a requirement's status with lifecycle transition validation.

set -euo pipefail

REQ_ID="${1:-}"
NEW_STATUS_RAW="${2:-}"
FORCE="false"
REFRESH_DOCS="true"
REASON=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/_project-root.sh"
PROJECT_ROOT="$(vibe_resolve_project_root)"
REQ_MANIFEST="$PROJECT_ROOT/.requirement-manifest.json"
WORKTREE_MANIFEST="$PROJECT_ROOT/.worktree-manifest.json"
source "$PROJECT_ROOT/scripts/_manifest-lock.sh"
GIT_OPERATION_LOCK="$PROJECT_ROOT/.vibe-git-operation.lock"
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

usage() {
  cat << 'EOF'
Usage: ./scripts/update-requirement-status.sh REQ-<timestamp> <new-status> [--force] [--no-refresh] [--reason "text"]

Valid statuses:
  PROPOSED, IN_PROGRESS, CODE_REVIEW, MERGED, DEPLOYED, BLOCKED, BACKLOG, CANCELLED

Flags:
  --force       Bypass transition validation
  --no-refresh  Skip docs regeneration
  --reason      Persist an audit reason for this status transition
EOF
}

if [ "$REQ_ID" = "-h" ] || [ "$REQ_ID" = "--help" ]; then
  usage
  exit 0
fi

if [ -z "$REQ_ID" ] || [ -z "$NEW_STATUS_RAW" ]; then
  usage >&2
  exit 1
fi

shift 2
while [ "$#" -gt 0 ]; do
  case "$1" in
    --force)
      FORCE="true"
      shift
      ;;
    --no-refresh)
      REFRESH_DOCS="false"
      shift
      ;;
    --reason)
      shift
      if [ "$#" -eq 0 ]; then
        echo "Error: --reason requires a value" >&2
        usage >&2
        exit 1
      fi
      REASON="$1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ -n "$REASON" ] && ! printf '%s' "$REASON" | grep -q '[^[:space:]]'; then
  echo "Error: --reason must not be empty" >&2
  exit 1
fi

if [[ ! "$REQ_ID" =~ ^REQ-[0-9]{10,}$ ]]; then
  echo "Error: Invalid requirement ID format: $REQ_ID" >&2
  exit 1
fi

NEW_STATUS="$(echo "$NEW_STATUS_RAW" | tr '[:lower:]' '[:upper:]')"

is_valid_status() {
  case "$1" in
    PROPOSED|IN_PROGRESS|CODE_REVIEW|MERGED|DEPLOYED|BLOCKED|BACKLOG|CANCELLED)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

if ! is_valid_status "$NEW_STATUS"; then
  echo "Error: Invalid status: $NEW_STATUS" >&2
  exit 1
fi

if [ ! -f "$REQ_MANIFEST" ]; then
  echo "Error: .requirement-manifest.json not found" >&2
  exit 1
fi

CURRENT_STATUS="$(jq -r --arg reqId "$REQ_ID" '
  .requirements[] | select(.id == $reqId) | .status
' "$REQ_MANIFEST")"

if [ -z "$CURRENT_STATUS" ] || [ "$CURRENT_STATUS" = "null" ]; then
  echo "Error: Requirement not found: $REQ_ID" >&2
  exit 1
fi

allowed_transitions() {
  case "$1" in
    PROPOSED)
      echo "IN_PROGRESS BACKLOG CANCELLED"
      ;;
    IN_PROGRESS)
      echo "CODE_REVIEW BLOCKED BACKLOG CANCELLED"
      ;;
    CODE_REVIEW)
      echo "MERGED BLOCKED CANCELLED"
      ;;
    MERGED)
      echo "DEPLOYED CANCELLED"
      ;;
    DEPLOYED)
      echo "CANCELLED"
      ;;
    BLOCKED)
      echo "IN_PROGRESS BACKLOG CANCELLED"
      ;;
    BACKLOG)
      echo "PROPOSED IN_PROGRESS CANCELLED"
      ;;
    CANCELLED)
      echo ""
      ;;
    *)
      echo ""
      ;;
  esac
}

can_transition() {
  local from_status="$1"
  local to_status="$2"
  [ "$from_status" = "$to_status" ] && return 0
  [ "$to_status" = "CANCELLED" ] && return 0

  for candidate in $(allowed_transitions "$from_status"); do
    if [ "$candidate" = "$to_status" ]; then
      return 0
    fi
  done

  return 1
}

is_terminal_status() {
  case "$1" in
    MERGED|DEPLOYED|CANCELLED)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

status_update_locked() {
  local enforce_terminal_invariant="$1"
  local current_status_locked
  local created_at
  local req_worktree_id
  local wt_status
  local wt_links_requirement
  local active_reverse_worktrees
  local active_reverse_worktrees_flat

  current_status_locked="$(jq -r --arg reqId "$REQ_ID" '
    .requirements[] | select(.id == $reqId) | .status
  ' "$REQ_MANIFEST")"

  if [ -z "$current_status_locked" ] || [ "$current_status_locked" = "null" ]; then
    echo "Error: Requirement not found: $REQ_ID" >&2
    return 1
  fi

  if [ "$current_status_locked" != "$CURRENT_STATUS" ]; then
    echo "Error: Requirement $REQ_ID changed concurrently ($CURRENT_STATUS -> $current_status_locked). Retry." >&2
    return 1
  fi

  created_at="$(jq -r --arg reqId "$REQ_ID" '.requirements[] | select(.id == $reqId) | .createdAt' "$REQ_MANIFEST")"
  if [ -n "$created_at" ] && [ "$created_at" != "null" ] && [[ "$TIMESTAMP" < "$created_at" ]]; then
    echo "Error: updatedAt ($TIMESTAMP) would be before createdAt ($created_at)" >&2
    return 1
  fi

  if [ "$enforce_terminal_invariant" = "true" ]; then
    active_reverse_worktrees="$(jq -r --arg reqId "$REQ_ID" '
      .worktrees[]?
      | select(.status == "ACTIVE")
      | select(any(.requirementIds[]?; . == $reqId))
      | .id
    ' "$WORKTREE_MANIFEST")"

    if [ -n "$active_reverse_worktrees" ]; then
      active_reverse_worktrees_flat="$(printf '%s\n' "$active_reverse_worktrees" | tr '\n' ' ' | xargs)"
      echo "Error: Cannot transition $REQ_ID to $NEW_STATUS while ACTIVE worktree link(s) exist: $active_reverse_worktrees_flat" >&2
      echo "Resolve the worktree first (for example via scripts/worktree-merge.sh) or repair historical drift with ./scripts/reconcile-lifecycle-invariants.sh --apply." >&2
      return 1
    fi

    req_worktree_id="$(jq -r --arg reqId "$REQ_ID" '
      .requirements[] | select(.id == $reqId) | .worktreeId // empty
    ' "$REQ_MANIFEST")"

    if [ -n "$req_worktree_id" ]; then
      wt_status="$(jq -r --arg wtId "$req_worktree_id" '
        .worktrees[]? | select(.id == $wtId) | .status // empty
      ' "$WORKTREE_MANIFEST" | head -1)"

      if [ -z "$wt_status" ]; then
        echo "Error: Requirement $REQ_ID references worktree $req_worktree_id, but no matching entry exists in .worktree-manifest.json." >&2
        echo "Run ./scripts/reconcile-lifecycle-invariants.sh --apply to repair manifest drift." >&2
        return 1
      fi

      wt_links_requirement="$(jq -r --arg wtId "$req_worktree_id" --arg reqId "$REQ_ID" '
        .worktrees[]? | select(.id == $wtId) | any(.requirementIds[]?; . == $reqId)
      ' "$WORKTREE_MANIFEST" | head -1)"

      if [ "$wt_links_requirement" != "true" ]; then
        echo "Error: Worktree $req_worktree_id is not linked back to requirement $REQ_ID in .worktree-manifest.json." >&2
        echo "Run ./scripts/reconcile-lifecycle-invariants.sh --apply to repair manifest drift." >&2
        return 1
      fi

      if [ "$wt_status" = "ACTIVE" ]; then
        echo "Error: Cannot transition $REQ_ID to $NEW_STATUS while linked worktree remains ACTIVE: $req_worktree_id" >&2
        echo "Resolve the worktree first (for example via scripts/worktree-merge.sh) or repair historical drift with ./scripts/reconcile-lifecycle-invariants.sh --apply." >&2
        return 1
      fi
    fi
  fi

  _jq_update_manifest_locked_inner "$REQ_MANIFEST" \
    '.requirements |= map(
      if .id == $reqId then
        .status = $newStatus
        | .updatedAt = $ts
        | if $newStatus == "DEPLOYED" then .deployedAt = $ts else . end
        | .statusHistory = ((.statusHistory // []) + [
            if ($reason | length) > 0 then
              {
                "from": $fromStatus,
                "to": $newStatus,
                "changedAt": $ts,
                "reason": $reason
              }
            else
              {
                "from": $fromStatus,
                "to": $newStatus,
                "changedAt": $ts
              }
            end
          ])
        | if ($reason | length) > 0 then
            .notes = ((.notes // "") as $existing
              | (if ($existing | length) > 0 then $existing + "\n" else "" end)
              + "[" + $ts + "] transition " + $fromStatus + " -> " + $newStatus + " reason: " + $reason)
          else
            .
          end
      else
        .
      end
    )' \
    --arg reqId "$REQ_ID" \
    --arg newStatus "$NEW_STATUS" \
    --arg fromStatus "$CURRENT_STATUS" \
    --arg reason "$REASON" \
    --arg ts "$TIMESTAMP"
}

if [ "$FORCE" != "true" ] && ! can_transition "$CURRENT_STATUS" "$NEW_STATUS"; then
  echo "Error: Invalid transition: $CURRENT_STATUS -> $NEW_STATUS" >&2
  echo "Allowed from $CURRENT_STATUS: $(allowed_transitions "$CURRENT_STATUS")" >&2
  echo "Use --force to bypass validation." >&2
  exit 1
fi

# Warn if manually deploying on a non-deployment project
REQUIRES_DEPLOYMENT="$(jq -r '.requiresDeployment // true' "$REQ_MANIFEST")"
if [ "$NEW_STATUS" = "DEPLOYED" ] && [ "$REQUIRES_DEPLOYMENT" = "false" ]; then
  echo "Note: This project has requiresDeployment=false. Requirements are auto-completed at merge."
  echo "      Proceeding with manual DEPLOYED transition anyway."
fi

if [ "$CURRENT_STATUS" = "$NEW_STATUS" ]; then
  echo "No change: $REQ_ID is already $NEW_STATUS"
  exit 0
fi

ENFORCE_TERMINAL_INVARIANT="false"
if [ "$FORCE" != "true" ] && is_terminal_status "$NEW_STATUS"; then
  ENFORCE_TERMINAL_INVARIANT="true"
  if [ ! -f "$WORKTREE_MANIFEST" ]; then
    echo "Error: .worktree-manifest.json not found" >&2
    exit 1
  fi
fi

status_update_workflow_locked() {
  if [ "$ENFORCE_TERMINAL_INVARIANT" = "true" ]; then
    if ! with_manifest_locks "$REQ_MANIFEST" "$WORKTREE_MANIFEST" status_update_locked "true"; then
      return 1
    fi
  else
    if ! with_manifest_lock "$REQ_MANIFEST" status_update_locked "false"; then
      return 1
    fi
  fi

  if [ "$REFRESH_DOCS" = "true" ]; then
    if ! "$PROJECT_ROOT/scripts/regenerate-docs.sh" >/dev/null; then
      return 1
    fi
  fi

  if ! git -C "$PROJECT_ROOT" add \
    .requirement-manifest.json \
    REQUIREMENTS.md \
    docs/STATUS.md \
    docs/ROADMAP.md \
    docs/DEPENDENCIES.md \
    docs/requirements/; then
    echo "Error: Failed to stage status update artifacts." >&2
    return 1
  fi

  if git -C "$PROJECT_ROOT" diff --cached --quiet; then
    echo "Error: No status update artifacts were staged after updating $REQ_ID to $NEW_STATUS." >&2
    return 1
  fi

  if ! git -C "$PROJECT_ROOT" commit -m "chore: update $REQ_ID status to $NEW_STATUS" --no-verify; then
    echo "Error: Failed to commit status update artifacts for $REQ_ID." >&2
    return 1
  fi
}

with_manifest_lock "$GIT_OPERATION_LOCK" status_update_workflow_locked

echo "✅ Updated $REQ_ID"
echo "   $CURRENT_STATUS -> $NEW_STATUS"
if [ -n "$REASON" ]; then
  echo "   Audit reason persisted"
fi
if [ "$REFRESH_DOCS" = "true" ]; then
  echo "   Docs regenerated"
else
  echo "   Docs regeneration skipped (--no-refresh)"
fi
