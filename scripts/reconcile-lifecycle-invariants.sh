#!/bin/bash
# Reconcile requirement/worktree lifecycle drift where terminal requirements still point to ACTIVE worktrees.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/_project-root.sh"
PROJECT_ROOT="$(vibe_resolve_project_root)"
REQ_MANIFEST="$PROJECT_ROOT/.requirement-manifest.json"
WORKTREE_MANIFEST="$PROJECT_ROOT/.worktree-manifest.json"
source "$PROJECT_ROOT/scripts/_manifest-lock.sh"

APPLY="false"
REFRESH_DOCS="true"
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

usage() {
  cat << 'EOF'
Usage: ./scripts/reconcile-lifecycle-invariants.sh [--apply] [--no-refresh]

Scans requirement/worktree manifests for lifecycle drift and optionally repairs it.

Detected drift:
  - Requirement status is terminal (MERGED, DEPLOYED, CANCELLED)
  - Requirement references a worktreeId
  - Matching worktree entry remains ACTIVE

Repair behavior (--apply):
  - MERGED/DEPLOYED requirements force linked worktree status to MERGED
  - CANCELLED requirements force linked worktree status to ABANDONED

Flags:
  --apply       Apply repairs to .worktree-manifest.json
  --no-refresh  Skip docs regeneration after successful --apply
  -h, --help    Show this help
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --apply)
      APPLY="true"
      shift
      ;;
    --no-refresh)
      REFRESH_DOCS="false"
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

if [ ! -f "$REQ_MANIFEST" ]; then
  echo "Error: .requirement-manifest.json not found" >&2
  exit 1
fi

if [ ! -f "$WORKTREE_MANIFEST" ]; then
  echo "Error: .worktree-manifest.json not found" >&2
  exit 1
fi

reconcile_lifecycle_locked() {
  local apply_mode="$1"
  local req_id
  local req_status
  local wt_id
  local wt_id_exists
  local wt_status
  local wt_links_requirement
  local active_reverse_worktrees
  local active_wt_id
  local target_status

  local checked=0
  local actionable=0
  local fixed=0
  local unresolved=0

  while IFS=$'\t' read -r req_id req_status wt_id; do
    [ -z "$req_id" ] && continue
    checked=$((checked + 1))

    if [ "$req_status" = "CANCELLED" ]; then
      target_status="ABANDONED"
    else
      target_status="MERGED"
    fi

    active_reverse_worktrees="$(jq -r --arg reqId "$req_id" '
      .worktrees[]?
      | select(.status == "ACTIVE")
      | select(any(.requirementIds[]?; . == $reqId))
      | .id
    ' "$WORKTREE_MANIFEST")"

    if [ -n "$active_reverse_worktrees" ]; then
      actionable=$((actionable + 1))
      echo "DRIFT: $req_id is $req_status while ACTIVE worktree link(s) exist via requirementIds (target: $target_status)"

      if [ "$apply_mode" = "true" ]; then
        while IFS= read -r active_wt_id; do
          [ -z "$active_wt_id" ] && continue

          if [ "$target_status" = "MERGED" ]; then
            _jq_update_manifest_locked_inner "$WORKTREE_MANIFEST" \
              '.worktrees |= map(
                if .id == $wtId and .status == "ACTIVE"
                then .status = "MERGED" | .mergedAt = (.mergedAt // $ts)
                else .
                end
              )' \
              --arg wtId "$active_wt_id" \
              --arg ts "$TIMESTAMP"
          else
            _jq_update_manifest_locked_inner "$WORKTREE_MANIFEST" \
              '.worktrees |= map(
                if .id == $wtId and .status == "ACTIVE"
                then .status = "ABANDONED"
                else .
                end
              )' \
              --arg wtId "$active_wt_id"
          fi
        done <<< "$active_reverse_worktrees"

        fixed=$((fixed + 1))
      fi
    fi

    [ -z "$wt_id" ] && continue

    wt_id_exists="$(jq -r --arg wtId "$wt_id" 'any(.worktrees[]?; .id == $wtId)' "$WORKTREE_MANIFEST")"
    if [ "$wt_id_exists" != "true" ]; then
      echo "WARN: $req_id ($req_status) references missing worktree entry: $wt_id" >&2
      actionable=$((actionable + 1))
      if [ "$apply_mode" = "true" ]; then
        _jq_update_manifest_locked_inner "$REQ_MANIFEST" \
          '.requirements |= map(
            if .id == $reqId
            then del(.worktreeId) | .updatedAt = $ts
            else .
            end
          )' \
          --arg reqId "$req_id" \
          --arg ts "$TIMESTAMP"
        fixed=$((fixed + 1))
      else
        unresolved=$((unresolved + 1))
      fi
      continue
    fi

    wt_status="$(jq -r --arg wtId "$wt_id" '.worktrees[]? | select(.id == $wtId) | .status // empty' "$WORKTREE_MANIFEST" | head -1)"
    wt_links_requirement="$(jq -r --arg wtId "$wt_id" --arg reqId "$req_id" '.worktrees[]? | select(.id == $wtId) | any(.requirementIds[]?; . == $reqId)' "$WORKTREE_MANIFEST" | head -1)"
    if [ "$wt_links_requirement" != "true" ]; then
      echo "WARN: $req_id references $wt_id but worktree requirementIds does not include $req_id" >&2
      actionable=$((actionable + 1))
      if [ "$apply_mode" = "true" ]; then
        _jq_update_manifest_locked_inner "$REQ_MANIFEST" \
          '.requirements |= map(
            if .id == $reqId
            then del(.worktreeId) | .updatedAt = $ts
            else .
            end
          )' \
          --arg reqId "$req_id" \
          --arg ts "$TIMESTAMP"
        fixed=$((fixed + 1))
      else
        unresolved=$((unresolved + 1))
      fi
      continue
    fi

  done < <(jq -r '.requirements[]
    | select(.status == "MERGED" or .status == "DEPLOYED" or .status == "CANCELLED")
    | [.id, .status, (.worktreeId // "")]
    | @tsv' "$REQ_MANIFEST")

  if [ "$checked" -eq 0 ]; then
    echo "No terminal requirements with linked worktrees were found."
    return 0
  fi

  if [ "$actionable" -eq 0 ] && [ "$unresolved" -eq 0 ]; then
    echo "No lifecycle invariant drift detected."
    return 0
  fi

  echo "Scan summary: checked=$checked actionable=$actionable unresolved=$unresolved"

  if [ "$apply_mode" = "true" ]; then
    echo "Repair summary: fixed=$fixed"
    if [ "$unresolved" -gt 0 ]; then
      echo "Error: unresolved manifest drift remains. Manual cleanup is required." >&2
      return 1
    fi
    return 0
  fi

  if [ "$actionable" -gt 0 ] || [ "$unresolved" -gt 0 ]; then
    echo "Re-run with --apply to repair actionable drift entries." >&2
    return 1
  fi

  return 0
}

set +e
with_manifest_locks "$REQ_MANIFEST" "$WORKTREE_MANIFEST" reconcile_lifecycle_locked "$APPLY"
RECONCILE_STATUS=$?
set -e

if [ "$RECONCILE_STATUS" -ne 0 ]; then
  exit "$RECONCILE_STATUS"
fi

if [ "$APPLY" = "true" ] && [ "$REFRESH_DOCS" = "true" ]; then
  "$PROJECT_ROOT/scripts/regenerate-docs.sh" >/dev/null
  echo "Docs regenerated after lifecycle reconciliation."
fi

if [ "$APPLY" = "true" ]; then
  echo "✅ Lifecycle reconciliation completed."
else
  echo "✅ Lifecycle reconciliation check completed."
fi
