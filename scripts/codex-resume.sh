#!/bin/bash
# Preflight Codex resume context for Vibe Master repositories.

set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: ./scripts/codex-resume.sh [--req-id <REQ-ID>] [--auto-detect] [--json]

Options:
  --req-id <REQ-ID>  Resume context for a specific requirement.
  --auto-detect      Infer the best requirement/worktree from current context (default).
  --json             Emit machine-readable JSON snapshot only.
  -h, --help         Show this help.
USAGE
}

REQ_ID=""
AUTO_DETECT="true"
JSON_ONLY="false"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --req-id)
      if [ "$#" -lt 2 ]; then
        echo "Error: --req-id requires a value." >&2
        exit 1
      fi
      REQ_ID="$2"
      AUTO_DETECT="false"
      shift 2
      ;;
    --auto-detect)
      AUTO_DETECT="true"
      shift
      ;;
    --json)
      JSON_ONLY="true"
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

if [ -n "$REQ_ID" ] && [[ ! "$REQ_ID" =~ ^REQ-[0-9]{10,}$ ]]; then
  echo "Error: Invalid requirement ID format: $REQ_ID" >&2
  exit 1
fi

CURRENT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CURRENT_ROOT="$(cd "$CURRENT_ROOT" && pwd -P)"
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "UNKNOWN")"
COMMON_DIR_RAW="$(git rev-parse --git-common-dir 2>/dev/null || true)"

if [ -n "$COMMON_DIR_RAW" ]; then
  case "$COMMON_DIR_RAW" in
    /*) COMMON_DIR="$COMMON_DIR_RAW" ;;
    *) COMMON_DIR="$CURRENT_ROOT/$COMMON_DIR_RAW" ;;
  esac
  COMMON_DIR="$(cd "$COMMON_DIR" 2>/dev/null && pwd -P || true)"
else
  COMMON_DIR=""
fi

if [ -n "$COMMON_DIR" ]; then
  CANONICAL_ROOT="$(cd "$(dirname "$COMMON_DIR")" && pwd -P)"
else
  CANONICAL_ROOT="$CURRENT_ROOT"
fi

REQ_MANIFEST="$CANONICAL_ROOT/.requirement-manifest.json"
WORKTREE_MANIFEST="$CANONICAL_ROOT/.worktree-manifest.json"

if [ ! -f "$REQ_MANIFEST" ]; then
  echo "Error: Missing manifest: $REQ_MANIFEST" >&2
  exit 1
fi

if [ ! -f "$WORKTREE_MANIFEST" ]; then
  echo "Error: Missing manifest: $WORKTREE_MANIFEST" >&2
  exit 1
fi

if ! jq -e . "$REQ_MANIFEST" >/dev/null; then
  echo "Error: Invalid JSON in $REQ_MANIFEST" >&2
  exit 1
fi

if ! jq -e . "$WORKTREE_MANIFEST" >/dev/null; then
  echo "Error: Invalid JSON in $WORKTREE_MANIFEST" >&2
  exit 1
fi

if [ -z "$REQ_ID" ] && [ "$AUTO_DETECT" = "true" ]; then
  REQ_ID="$(jq -r \
    --arg currentPath "$CURRENT_ROOT" \
    --arg currentBranch "$CURRENT_BRANCH" \
    --slurpfile req "$REQ_MANIFEST" '
      def req_by_id($id):
        ($req[0].requirements[]? | select(.id == $id));

      # Candidate 1: active worktree path match from current context.
      (
        .worktrees[]?
        | select(.status == "ACTIVE" and .path == $currentPath)
        | .requirementIds[]?
        | req_by_id(.)
      ) as $pathReq
      | if $pathReq != null then
          $pathReq.id
        else
          # Candidate 2: active worktree branch match from current context.
          (
            .worktrees[]?
            | select(.status == "ACTIVE" and .branch == $currentBranch)
            | .requirementIds[]?
            | req_by_id(.)
          ) as $branchReq
          | if $branchReq != null then
              $branchReq.id
            else
              # Candidate 3: most recently updated requirement currently in active workflow states.
              (
                [$req[0].requirements[]?
                  | select(.status == "IN_PROGRESS" or .status == "CODE_REVIEW" or .status == "BLOCKED")
                  | select((.worktreeId // "") != "")
                ]
                | sort_by(.updatedAt // .createdAt // "")
                | last
              ) as $inFlightReq
              | if $inFlightReq != null then
                  $inFlightReq.id
                else
                  # Candidate 4: newest resumable requirement (prefers PROPOSED/BACKLOG for /start-work).
                  (
                    [$req[0].requirements[]?
                      | select(.status == "PROPOSED" or .status == "BACKLOG" or .status == "IN_PROGRESS" or .status == "CODE_REVIEW" or .status == "BLOCKED" or .status == "MERGED")
                    ]
                    | sort_by(.updatedAt // .createdAt // "")
                    | last
                  ) as $fallbackReq
                  | if $fallbackReq != null then $fallbackReq.id else "" end
                end
            end
        end
    ' "$WORKTREE_MANIFEST")"
fi

if [ -n "$REQ_ID" ]; then
  if ! jq -e --arg reqId "$REQ_ID" '.requirements[]? | select(.id == $reqId)' "$REQ_MANIFEST" >/dev/null; then
    echo "Error: Requirement not found: $REQ_ID" >&2
    exit 1
  fi
fi

SNAPSHOT="$(jq -n \
  --arg canonicalRoot "$CANONICAL_ROOT" \
  --arg currentRoot "$CURRENT_ROOT" \
  --arg currentBranch "$CURRENT_BRANCH" \
  --arg reqId "$REQ_ID" \
  --arg vibeCaller "${VIBE_CALLER:-}" \
  --arg vibeAutoMode "${VIBE_AUTO_MODE:-}" \
  --slurpfile req "$REQ_MANIFEST" \
  --slurpfile wt "$WORKTREE_MANIFEST" '
    def req_by_id($id):
      ($req[0].requirements[]? | select(.id == $id));

    def wt_by_id($id):
      ($wt[0].worktrees[]? | select(.id == $id));

    def active_wt_for_req($r):
      if $r == null then null
      else
        ([
          (
            if ($r.worktreeId // "") != "" then
              (wt_by_id($r.worktreeId) | select((.status // "") == "ACTIVE"))
            else
              empty
            end
          ),
          (
            $wt[0].worktrees[]?
            | select(.status == "ACTIVE")
            | select((.requirementIds // []) | index($r.id))
          )
        ] | .[0] // null)
      end;

    def next_command($r; $w):
      if $r == null then
        "/status"
      else
        ($r.status // "") as $s
        | if $s == "PROPOSED" or $s == "BACKLOG" then
            if $w != null then
              "/work-on " + $r.id
            else
              "/start-work " + $r.id
            end
          elif $s == "IN_PROGRESS" or $s == "CODE_REVIEW" or $s == "BLOCKED" then
            if $w != null then
              "/work-on " + $r.id
            else
              "/start-work " + $r.id
            end
          elif $s == "MERGED" then
            "/update-requirement " + $r.id + " DEPLOYED"
          elif $s == "DEPLOYED" or $s == "CANCELLED" then
            "/add-requirement \"Feature name\" \"Description\""
          else
            "/status"
          end
      end;

    (if $reqId != "" then req_by_id($reqId) else null end) as $selectedReq
    | (active_wt_for_req($selectedReq)) as $selectedWt
    | {
        version: "1",
        generatedAt: (now | todateiso8601),
        mode: (if $reqId != "" then "explicit" else "auto-detect" end),
        canonicalRoot: $canonicalRoot,
        currentContext: {
          root: $currentRoot,
          branch: $currentBranch,
          insideTrackedWorktree: (
            [ $wt[0].worktrees[]? | select(.status == "ACTIVE" and (.path == $currentRoot or .branch == $currentBranch)) ]
            | length > 0
          )
        },
        caller: {
          vibeCaller: $vibeCaller,
          vibeAutoMode: $vibeAutoMode,
          trustedForAuto: (($vibeCaller == "codex") and ($vibeAutoMode == "1"))
        },
        requirement: (if $selectedReq == null then null else {
          id: $selectedReq.id,
          name: ($selectedReq.name // ""),
          status: ($selectedReq.status // "UNKNOWN"),
          priority: ($selectedReq.priority // ""),
          worktreeId: ($selectedReq.worktreeId // null),
          updatedAt: ($selectedReq.updatedAt // null)
        } end),
        worktree: (if $selectedWt == null then null else {
          id: ($selectedWt.id // null),
          branch: ($selectedWt.branch // null),
          baseBranch: ($selectedWt.baseBranch // "main"),
          path: ($selectedWt.path // null),
          status: ($selectedWt.status // null),
          requirementIds: ($selectedWt.requirementIds // [])
        } end),
        nextRecommendedCommand: next_command($selectedReq; $selectedWt)
      }
  ')"

if [ "$JSON_ONLY" = "true" ]; then
  echo "$SNAPSHOT"
  exit 0
fi

echo "=== Codex Resume Snapshot ==="

echo "$SNAPSHOT" | jq -r '
  "Canonical Root: " + .canonicalRoot,
  "Current Context: " + .currentContext.root + " (branch: " + .currentContext.branch + ")",
  (
    if .requirement == null then
      "Selected Requirement: none"
    else
      "Selected Requirement: " + .requirement.id + " [" + .requirement.status + "] " + .requirement.name
    end
  ),
  (
    if .worktree == null then
      "Linked Worktree: none"
    else
      "Linked Worktree: " + .worktree.id + " (" + .worktree.path + ")"
    end
  ),
  "Caller Auto Trust: " + (if .caller.trustedForAuto then "enabled" else "disabled" end),
  "Next recommended command: " + .nextRecommendedCommand
'

echo
echo "JSON snapshot:"
echo "$SNAPSHOT" | jq .
