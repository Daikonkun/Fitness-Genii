#!/bin/bash
# Merge a feature branch, clean worktree, and update manifests

set -euo pipefail

TARGET_REF=""
BRANCH=""
BASE_BRANCH="main"
FORCE="false"
AUTO_RESOLVE_CONFLICTS="false"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/_project-root.sh"
PROJECT_ROOT="$(vibe_resolve_project_root)"
REQ_MANIFEST="$PROJECT_ROOT/.requirement-manifest.json"
WORKTREE_MANIFEST="$PROJECT_ROOT/.worktree-manifest.json"
source "$PROJECT_ROOT/scripts/_manifest-lock.sh"
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
UNMAPPED_FORCE_MODE=false
WORKTREE_REMOVED=false
CLEANUP_FAILURE=false
PRE_MERGE_HEAD=""
MERGE_APPLIED=false
declare -a CLEANUP_FAILURE_DETAILS=()

record_cleanup_failure() {
  local message="$1"
  CLEANUP_FAILURE=true
  CLEANUP_FAILURE_DETAILS+=("$message")
  echo "⚠️  $message" >&2
}

is_tracked_requirement_spec_conflict() {
  local candidate="$1"
  local req_id
  local req_spec

  [ -z "$candidate" ] && return 1
  [ -z "${REQ_IDS:-}" ] && return 1

  while IFS= read -r req_id; do
    [ -z "$req_id" ] && continue
    req_spec=""
    if [ -d "$PROJECT_ROOT/docs/requirements" ]; then
      req_spec="$(find "$PROJECT_ROOT/docs/requirements" -maxdepth 1 -type f -name "${req_id}-*.md" | head -1)"
    fi
    if [ -n "$req_spec" ] && [ "${req_spec#$PROJECT_ROOT/}" = "$candidate" ]; then
      return 0
    fi
  done <<< "$REQ_IDS"

  return 1
}

is_auto_resolvable_conflict_file() {
  local candidate="$1"

  case "$candidate" in
    .requirement-manifest.json|.worktree-manifest.json|REQUIREMENTS.md|docs/STATUS.md|docs/ROADMAP.md|docs/DEPENDENCIES.md)
      return 0
      ;;
  esac

  if is_tracked_requirement_spec_conflict "$candidate"; then
    return 0
  fi

  return 1
}

resolve_conflict_file() {
  local candidate="$1"

  case "$candidate" in
    .requirement-manifest.json|.worktree-manifest.json)
      # Prefer branch content for manifest merges, then reconcile lifecycle below.
      if ! git -C "$PROJECT_ROOT" checkout --theirs -- "$candidate"; then
        git -C "$PROJECT_ROOT" checkout --ours -- "$candidate"
      fi
      ;;
    REQUIREMENTS.md|docs/STATUS.md|docs/ROADMAP.md|docs/DEPENDENCIES.md)
      # Generated outputs are regenerated after lifecycle updates.
      git -C "$PROJECT_ROOT" checkout --ours -- "$candidate"
      ;;
    *)
      if is_tracked_requirement_spec_conflict "$candidate"; then
        # Prefer feature branch requirement narrative for the merged requirement scope.
        if ! git -C "$PROJECT_ROOT" checkout --theirs -- "$candidate"; then
          git -C "$PROJECT_ROOT" checkout --ours -- "$candidate"
        fi
      else
        return 1
      fi
      ;;
  esac

  git -C "$PROJECT_ROOT" add -- "$candidate"
}

auto_resolve_conflicts() {
  local unresolved
  local candidate
  local unsupported=()

  unresolved="$(git -C "$PROJECT_ROOT" diff --name-only --diff-filter=U)"
  if [ -z "$unresolved" ]; then
    return 1
  fi

  while IFS= read -r candidate; do
    [ -z "$candidate" ] && continue

    if ! is_auto_resolvable_conflict_file "$candidate"; then
      unsupported+=("$candidate")
      continue
    fi

    if ! resolve_conflict_file "$candidate"; then
      unsupported+=("$candidate")
    fi
  done <<< "$unresolved"

  if [ "${#unsupported[@]}" -gt 0 ]; then
    echo "Error: Auto-resolve could not safely handle these merge conflicts:" >&2
    printf '  %s\n' "${unsupported[@]}" >&2
    echo "Resolve them manually, then run: git commit" >&2
    return 1
  fi

  return 0
}

auto_review_dirty_worktree() {
  local worktree_path="$1"
  local branch="$2"
  local wt_dirty
  local wt_tracked
  local wt_untracked

  if [ -z "$worktree_path" ] || [ ! -d "$worktree_path" ]; then
    return 0
  fi

  wt_dirty="$(git -C "$worktree_path" status --porcelain --untracked-files=all)"
  if [ -z "$wt_dirty" ]; then
    return 0
  fi

  wt_tracked="$(printf '%s\n' "$wt_dirty" | grep -Ev '^\?\?' || true)"
  wt_untracked="$(printf '%s\n' "$wt_dirty" | grep -E '^\?\?' || true)"

  echo "ℹ️  Auto-review: detected dirty worktree at $worktree_path"

  if [ -n "$wt_tracked" ]; then
    echo "ℹ️  Auto-review decision: tracked changes found; auto-committing before cleanup."
    git -C "$worktree_path" add -A
    if ! git -C "$worktree_path" diff --cached --quiet; then
      if ! git -C "$worktree_path" commit -m "chore: auto-commit worktree changes before merge cleanup for $branch" --no-verify >/dev/null; then
        echo "Error: Auto-review failed to commit dirty worktree changes at $worktree_path" >&2
        return 1
      fi
    fi
  elif [ -n "$wt_untracked" ]; then
    echo "ℹ️  Auto-review decision: untracked-only changes found; stashing before cleanup."
    if ! git -C "$worktree_path" stash push -u -m "auto-stash before worktree cleanup for $branch" >/dev/null; then
      echo "Error: Auto-review failed to stash untracked worktree changes at $worktree_path" >&2
      return 1
    fi
  fi

  wt_dirty="$(git -C "$worktree_path" status --porcelain --untracked-files=all)"
  if [ -n "$wt_dirty" ]; then
    echo "Error: Worktree remains dirty after auto-review at $worktree_path" >&2
    echo "$wt_dirty" | sed 's/^/  /' >&2
    return 1
  fi

  return 0
}

usage() {
  cat << 'EOF'
Usage: ./scripts/worktree-merge.sh <branch|REQ-ID> [base-branch] [--force]

Flags:
  --force                    Override lifecycle/mapping safeguards (unmapped branch or non-CODE_REVIEW requirements)
  --auto-resolve-conflicts   Attempt safe conflict resolution for generated outputs/manifests and mapped requirement specs
EOF
}

if [ "$#" -eq 0 ]; then
  usage >&2
  exit 1
fi

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  usage
  exit 0
fi

TARGET_REF="$1"
shift

if [ "$#" -gt 0 ] && [[ "$1" != --* ]]; then
  BASE_BRANCH="$1"
  shift
fi

for arg in "$@"; do
  case "$arg" in
    --force)
      FORCE="true"
      ;;
    --auto-resolve-conflicts)
      AUTO_RESOLVE_CONFLICTS="true"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: Unknown option: $arg" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ -z "$TARGET_REF" ]; then
  usage >&2
  exit 1
fi

if [[ "$TARGET_REF" =~ ^REQ-[0-9]+$ ]]; then
  if ! jq -e --arg reqId "$TARGET_REF" '.requirements[]? | select(.id == $reqId)' "$REQ_MANIFEST" >/dev/null; then
    echo "Error: Requirement not found in manifest: $TARGET_REF" >&2
    exit 1
  fi

  REQUIREMENT_WORKTREE_ID="$(jq -r --arg reqId "$TARGET_REF" '
    .requirements[]? | select(.id == $reqId) | .worktreeId // empty
  ' "$REQ_MANIFEST")"

  WORKTREE_ENTRY_FROM_REQ=""

  if [ -n "$REQUIREMENT_WORKTREE_ID" ]; then
    PRIMARY_MATCHES_RAW="$(jq -c --arg worktreeId "$REQUIREMENT_WORKTREE_ID" '
      .worktrees[]?
      | select(.status == "ACTIVE")
      | select((.id == $worktreeId) or (.branch == $worktreeId))
    ' "$WORKTREE_MANIFEST")"

    PRIMARY_MATCH_COUNT="$(printf '%s\n' "$PRIMARY_MATCHES_RAW" | sed '/^$/d' | wc -l | tr -d ' ')"

    if [ "$PRIMARY_MATCH_COUNT" -gt 1 ]; then
      echo "Error: Ambiguous ACTIVE worktree mappings for requirement: $TARGET_REF (worktreeId '$REQUIREMENT_WORKTREE_ID')." >&2
      echo "Conflicting candidates:" >&2
      while IFS= read -r candidate; do
        [ -z "$candidate" ] && continue
        echo "  - id=$(echo "$candidate" | jq -r '.id // "(none)"'), branch=$(echo "$candidate" | jq -r '.branch // "(none)"')" >&2
      done <<< "$PRIMARY_MATCHES_RAW"
      exit 1
    fi

    if [ "$PRIMARY_MATCH_COUNT" -eq 1 ]; then
      WORKTREE_ENTRY_FROM_REQ="$(printf '%s\n' "$PRIMARY_MATCHES_RAW" | sed -n '1p')"
    fi

    if [ -z "$WORKTREE_ENTRY_FROM_REQ" ]; then
      echo "⚠️  Warning: Requirement $TARGET_REF references worktreeId $REQUIREMENT_WORKTREE_ID, but no ACTIVE entry matched. Falling back to requirement linkage lookup." >&2
    fi
  fi

  if [ -z "$WORKTREE_ENTRY_FROM_REQ" ]; then
    FALLBACK_MATCHES_RAW="$(jq -c --arg reqId "$TARGET_REF" '
      .worktrees[]?
      | select(.status == "ACTIVE")
      | select((.requirementIds // []) | index($reqId))
    ' "$WORKTREE_MANIFEST")"

    FALLBACK_MATCH_COUNT="$(printf '%s\n' "$FALLBACK_MATCHES_RAW" | sed '/^$/d' | wc -l | tr -d ' ')"

    if [ "$FALLBACK_MATCH_COUNT" -gt 1 ]; then
      echo "Error: Ambiguous ACTIVE worktree mappings for requirement: $TARGET_REF (requirementIds linkage)." >&2
      echo "Conflicting candidates:" >&2
      while IFS= read -r candidate; do
        [ -z "$candidate" ] && continue
        echo "  - id=$(echo "$candidate" | jq -r '.id // "(none)"'), branch=$(echo "$candidate" | jq -r '.branch // "(none)"')" >&2
      done <<< "$FALLBACK_MATCHES_RAW"
      exit 1
    fi

    if [ "$FALLBACK_MATCH_COUNT" -eq 1 ]; then
      WORKTREE_ENTRY_FROM_REQ="$(printf '%s\n' "$FALLBACK_MATCHES_RAW" | sed -n '1p')"
    fi
  fi

  if [ -z "$WORKTREE_ENTRY_FROM_REQ" ]; then
    if [ -n "$REQUIREMENT_WORKTREE_ID" ]; then
      echo "Error: No ACTIVE worktree mapping found for requirement: $TARGET_REF (checked worktreeId '$REQUIREMENT_WORKTREE_ID' and requirementIds linkage)" >&2
    else
      echo "Error: Requirement has no mapped worktreeId and no ACTIVE worktree mapping by requirementIds: $TARGET_REF" >&2
    fi
    exit 1
  fi

  BRANCH="$(echo "$WORKTREE_ENTRY_FROM_REQ" | jq -r '.branch // .id // empty')"
  if [ -z "$BRANCH" ]; then
    echo "Error: ACTIVE worktree mapping for $TARGET_REF does not provide a branch" >&2
    exit 1
  fi

  echo "Resolved $TARGET_REF to branch: $BRANCH"
else
  BRANCH="$TARGET_REF"
fi

if [ ! -f "$REQ_MANIFEST" ] || [ ! -f "$WORKTREE_MANIFEST" ]; then
  echo "Error: requirement/worktree manifest missing" >&2
  exit 1
fi

DIRTY_FILES="$(git -C "$PROJECT_ROOT" status --porcelain)"
if [ -n "$DIRTY_FILES" ]; then
  echo "Error: Working tree is not clean. Refusing to merge with unrelated in-flight changes." >&2
  echo "Unexpected dirty files:" >&2
  echo "$DIRTY_FILES" | sed 's/^/  /' >&2
  exit 1
fi

if ! git -C "$PROJECT_ROOT" rev-parse --verify "$BASE_BRANCH" >/dev/null 2>&1; then
  echo "Error: Base branch not found locally: $BASE_BRANCH" >&2
  exit 1
fi

if ! git -C "$PROJECT_ROOT" show-ref --verify --quiet "refs/heads/$BRANCH"; then
  echo "Error: Feature branch not found locally: $BRANCH" >&2
  exit 1
fi

WORKTREE_ENTRY="$(jq -c --arg branch "$BRANCH" '
  .worktrees[]? | select((.branch == $branch or .id == $branch) and .status == "ACTIVE")
' "$WORKTREE_MANIFEST" | head -1)"

WORKTREE_PATH=""
REQ_IDS=""
if [ -n "$WORKTREE_ENTRY" ]; then
  WORKTREE_PATH="$(echo "$WORKTREE_ENTRY" | jq -r '.path // empty')"
  REQ_IDS="$(echo "$WORKTREE_ENTRY" | jq -r '.requirementIds[]?')"
else
  echo "⚠️  Warning: No ACTIVE worktree mapping found for branch: $BRANCH" >&2
  if [ "$FORCE" != "true" ]; then
    echo "Refusing to merge unmapped branch without --force." >&2
    exit 1
  fi
  UNMAPPED_FORCE_MODE=true
  echo "Proceeding due to --force. Requirement status updates will be skipped." >&2
fi

if [ -n "$REQ_IDS" ]; then
  while IFS= read -r reqId; do
    [ -z "$reqId" ] && continue

    CURRENT_REQ_STATUS="$(jq -r --arg reqId "$reqId" '
      .requirements[] | select(.id == $reqId) | .status // empty
    ' "$REQ_MANIFEST")"

    if [ -z "$CURRENT_REQ_STATUS" ]; then
      echo "Error: Requirement not found in manifest: $reqId" >&2
      exit 1
    fi

    if [ "$CURRENT_REQ_STATUS" = "CODE_REVIEW" ]; then
      continue
    fi

    if [ "$FORCE" = "true" ]; then
      echo "⚠️  Warning: $reqId is in $CURRENT_REQ_STATUS. Proceeding due to --force." >&2
      continue
    fi

    if [ "$CURRENT_REQ_STATUS" = "IN_PROGRESS" ]; then
      echo "Error: $reqId is IN_PROGRESS. Move it to CODE_REVIEW before merging, or use --force to override." >&2
    else
      echo "Error: $reqId is $CURRENT_REQ_STATUS. Only CODE_REVIEW can be merged without --force." >&2
    fi
    exit 1
  done <<< "$REQ_IDS"
fi

if [ -n "$WORKTREE_PATH" ] && [ -d "$WORKTREE_PATH" ]; then
  if ! auto_review_dirty_worktree "$WORKTREE_PATH" "$BRANCH"; then
    echo "Error: Automatic dirty worktree review failed. Resolve manually, then retry." >&2
    exit 1
  fi
fi

echo "Merging $BRANCH into $BASE_BRANCH..."
PRE_MERGE_HEAD="$(git -C "$PROJECT_ROOT" rev-parse HEAD)"
git -C "$PROJECT_ROOT" checkout "$BASE_BRANCH"
set +e
git -C "$PROJECT_ROOT" merge --no-ff "$BRANCH" -m "Merge $BRANCH"
MERGE_EXIT_CODE=$?
set -e

if [ "$MERGE_EXIT_CODE" -ne 0 ]; then
  if [ "$AUTO_RESOLVE_CONFLICTS" != "true" ]; then
    echo "Hint: retry with --auto-resolve-conflicts for safe auto-resolution of generated docs/manifests/spec merge conflicts." >&2
    exit "$MERGE_EXIT_CODE"
  fi

  echo "⚠️  Merge reported conflicts. Attempting auto-resolution (--auto-resolve-conflicts)..." >&2
  if ! auto_resolve_conflicts; then
    exit 1
  fi

  if [ -n "$(git -C "$PROJECT_ROOT" diff --name-only --diff-filter=U)" ]; then
    echo "Error: Unresolved merge conflicts remain after auto-resolution attempt." >&2
    git -C "$PROJECT_ROOT" diff --name-only --diff-filter=U >&2
    exit 1
  fi

  if ! git -C "$PROJECT_ROOT" commit -m "Merge $BRANCH"; then
    echo "Error: Auto-resolved merge requires manual commit completion." >&2
    echo "Run this to recover:" >&2
    echo "  git -C \"$PROJECT_ROOT\" status --short" >&2
    echo "  git -C \"$PROJECT_ROOT\" commit" >&2
    exit 1
  fi
fi

POST_MERGE_HEAD="$(git -C "$PROJECT_ROOT" rev-parse HEAD)"
if [ "$PRE_MERGE_HEAD" != "$POST_MERGE_HEAD" ]; then
  MERGE_APPLIED=true
fi

if [ -n "$WORKTREE_PATH" ] && [ -d "$WORKTREE_PATH" ]; then
  if git -C "$PROJECT_ROOT" worktree remove "$WORKTREE_PATH"; then
    WORKTREE_REMOVED=true
  elif [ "$UNMAPPED_FORCE_MODE" = true ]; then
    echo "⚠️  Could not remove worktree during forced unmapped merge: $WORKTREE_PATH" >&2
  else
    record_cleanup_failure "Failed to remove worktree: $WORKTREE_PATH"
  fi
fi

if ! git -C "$PROJECT_ROOT" branch -d "$BRANCH"; then
  if [ "$UNMAPPED_FORCE_MODE" = true ]; then
    echo "⚠️  Could not delete branch during forced unmapped merge: $BRANCH" >&2
  else
    record_cleanup_failure "Failed to delete merged branch: $BRANCH"
  fi
fi

if [ "$CLEANUP_FAILURE" = true ]; then
  if [ "$MERGE_APPLIED" = true ]; then
    if git -C "$PROJECT_ROOT" reset --hard "$PRE_MERGE_HEAD" >/dev/null 2>&1; then
      echo "↩️  Rolled back merge commit due to cleanup failure (all-or-nothing mode)." >&2
    else
      echo "⚠️  Failed to rollback merge commit automatically. Manual recovery may be required." >&2
    fi
  fi

  echo "⚠️  Merge cleanup failed before lifecycle reconciliation. Requirement/worktree manifests were not updated." >&2
  echo "Recovery guidance:" >&2
  if [ -n "$WORKTREE_PATH" ]; then
    echo "  git -C \"$PROJECT_ROOT\" worktree remove \"$WORKTREE_PATH\"" >&2
  fi
  echo "  git -C \"$PROJECT_ROOT\" branch -d \"$BRANCH\"" >&2
  echo "  ./scripts/worktree-list.sh" >&2
  echo "Cleanup failures:" >&2
  for failure in "${CLEANUP_FAILURE_DETAILS[@]}"; do
    echo "  - $failure" >&2
  done
  exit 1
fi

if [ -n "$WORKTREE_ENTRY" ]; then
  jq_update_manifest_locked "$WORKTREE_MANIFEST" \
    '.worktrees |= map(
      if .branch == $branch or .id == $branch
      then .status = "MERGED" | .mergedAt = $ts
      else .
      end
    )' \
    --arg branch "$BRANCH" \
    --arg ts "$TIMESTAMP"
fi

# Determine target status based on requiresDeployment flag
REQUIRES_DEPLOYMENT="$(jq -r '.requiresDeployment // true' "$REQ_MANIFEST")"
if [ "$REQUIRES_DEPLOYMENT" = "false" ]; then
  REQ_TARGET_STATUS="DEPLOYED"
else
  REQ_TARGET_STATUS="MERGED"
fi

if [ -n "$REQ_IDS" ]; then
  while IFS= read -r reqId; do
    [ -z "$reqId" ] && continue
    if [ "$REQ_TARGET_STATUS" = "DEPLOYED" ]; then
      jq_update_manifest_locked "$REQ_MANIFEST" \
        '.requirements |= map(
          if .id == $reqId
          then .status = "DEPLOYED" | .updatedAt = $ts | .deployedAt = $ts
          else .
          end
        )' \
        --arg reqId "$reqId" \
        --arg ts "$TIMESTAMP"
    else
      jq_update_manifest_locked "$REQ_MANIFEST" \
        '.requirements |= map(
          if .id == $reqId
          then .status = "MERGED" | .updatedAt = $ts
          else .
          end
        )' \
        --arg reqId "$reqId" \
        --arg ts "$TIMESTAMP"
    fi
  done <<< "$REQ_IDS"
else
  echo "⚠️  No mapped requirements found for $BRANCH; no requirement status was updated."
fi

"$PROJECT_ROOT/scripts/regenerate-docs.sh" >/dev/null

FILES_TO_ADD=()

add_stage_file() {
  local candidate="$1"
  local existing

  [ -z "$candidate" ] && return
  [ ! -e "$PROJECT_ROOT/$candidate" ] && return

  for existing in "${FILES_TO_ADD[@]:-}"; do
    if [ "$existing" = "$candidate" ]; then
      return
    fi
  done

  FILES_TO_ADD+=("$candidate")
}

add_stage_file ".requirement-manifest.json"
add_stage_file ".worktree-manifest.json"
add_stage_file "REQUIREMENTS.md"
add_stage_file "docs/STATUS.md"
add_stage_file "docs/ROADMAP.md"
add_stage_file "docs/DEPENDENCIES.md"

if [ -n "$REQ_IDS" ]; then
  while IFS= read -r reqId; do
    [ -z "$reqId" ] && continue
    req_spec=""
    if [ -d "$PROJECT_ROOT/docs/requirements" ]; then
      req_spec="$(find "$PROJECT_ROOT/docs/requirements" -maxdepth 1 -type f -name "${reqId}-*.md" | head -1)"
    fi
    if [ -n "$req_spec" ]; then
      add_stage_file "${req_spec#$PROJECT_ROOT/}"
    fi
  done <<< "$REQ_IDS"
fi

if [ "${#FILES_TO_ADD[@]}" -gt 0 ]; then
  git -C "$PROJECT_ROOT" add -- "${FILES_TO_ADD[@]}"
fi

is_allowed_dirty_file() {
  local candidate="$1"
  local staged
  for staged in "${FILES_TO_ADD[@]:-}"; do
    if [ "$staged" = "$candidate" ]; then
      return 0
    fi
  done
  return 1
}

STATUS_AFTER_STAGE="$(git -C "$PROJECT_ROOT" status --porcelain)"
if [ -n "$STATUS_AFTER_STAGE" ]; then
  UNEXPECTED_DIRTY=()
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    dirty_path="${line:3}"
    if [[ "$dirty_path" == *" -> "* ]]; then
      dirty_path="${dirty_path##* -> }"
    fi

    if ! is_allowed_dirty_file "$dirty_path"; then
      UNEXPECTED_DIRTY+=("$line")
    fi
  done <<< "$STATUS_AFTER_STAGE"

  if [ "${#UNEXPECTED_DIRTY[@]}" -gt 0 ]; then
    echo "Error: Unexpected dirty files detected; refusing to continue." >&2
    printf '  %s\n' "${UNEXPECTED_DIRTY[@]}" >&2
    exit 1
  fi
fi

if ! git -C "$PROJECT_ROOT" diff --cached --quiet; then
  if ! git -C "$PROJECT_ROOT" commit -m "chore: update manifests and docs after merging $BRANCH" --no-verify; then
    echo "Error: Failed to commit reconciliation changes after merging $BRANCH." >&2
    echo "Run this to recover:" >&2
    echo "  git -C \"$PROJECT_ROOT\" status --short" >&2
    echo "  git -C \"$PROJECT_ROOT\" commit -m \"chore: update manifests and docs after merging $BRANCH\" --no-verify" >&2
    exit 1
  fi
fi

echo "✅ Merged $BRANCH"
if [ "$WORKTREE_REMOVED" = true ]; then
  echo "Removed worktree: $WORKTREE_PATH"
fi
if [ -n "$REQ_IDS" ]; then
  echo "Updated requirements to $REQ_TARGET_STATUS: $(echo "$REQ_IDS" | tr '\n' ' ' | xargs)"
  if [ "$REQ_TARGET_STATUS" = "DEPLOYED" ]; then
    echo "✅ Requirements marked DEPLOYED (project does not require deployment)."
  else
    echo "⚠️  Requirements merged but not yet deployed. Deploy your changes, then run:"
    echo "   /update-requirement <REQ-ID> DEPLOYED"
  fi
fi
if [ "$UNMAPPED_FORCE_MODE" = true ]; then
  echo "⚠️  Completed forced unmapped merge. No requirement statuses were updated."
fi

