#!/bin/bash
# Show project requirement status with optional doc refresh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/_project-root.sh"
PROJECT_ROOT="$(vibe_resolve_project_root)"
REQ_MANIFEST="$PROJECT_ROOT/.requirement-manifest.json"
REFRESH="${1:-}"

if [ ! -f "$REQ_MANIFEST" ]; then
  echo "Error: .requirement-manifest.json not found" >&2
  exit 1
fi

if [ "$REFRESH" != "--no-refresh" ]; then
  "$PROJECT_ROOT/scripts/regenerate-docs.sh" >/dev/null
fi

echo "=== Project Status ==="
echo "Manifest: $REQ_MANIFEST"

# Determine completion semantics based on requiresDeployment flag
REQUIRES_DEPLOYMENT="$(jq -r '.requiresDeployment // true' "$REQ_MANIFEST")"

TOTAL_COUNT="$(jq '.requirements | length' "$REQ_MANIFEST")"
MERGED_COUNT="$(jq '[.requirements[] | select(.status == "MERGED")] | length' "$REQ_MANIFEST")"
DEPLOYED_COUNT="$(jq '[.requirements[] | select(.status == "DEPLOYED")] | length' "$REQ_MANIFEST")"

if [ "$REQUIRES_DEPLOYMENT" = "false" ]; then
  # No deployment needed: MERGED and DEPLOYED both count as complete
  OUTSTANDING_COUNT="$(jq '[.requirements[] | select(.status != "DEPLOYED" and .status != "CANCELLED" and .status != "MERGED")] | length' "$REQ_MANIFEST")"
  COMPLETED_COUNT="$((MERGED_COUNT + DEPLOYED_COUNT))"
else
  # Deployment required: only DEPLOYED is truly complete; MERGED is not yet done
  OUTSTANDING_COUNT="$(jq '[.requirements[] | select(.status != "DEPLOYED" and .status != "CANCELLED")] | length' "$REQ_MANIFEST")"
  COMPLETED_COUNT="$DEPLOYED_COUNT"
fi

echo "Total: $TOTAL_COUNT"
echo "Outstanding: $OUTSTANDING_COUNT"
echo "Completed: $COMPLETED_COUNT"

echo ""
echo "Outstanding REQ IDs:"
if [ "$REQUIRES_DEPLOYMENT" = "false" ]; then
  OUTSTANDING_STATUSES='["PROPOSED", "BACKLOG", "IN_PROGRESS", "CODE_REVIEW", "BLOCKED"]'
else
  OUTSTANDING_STATUSES='["PROPOSED", "BACKLOG", "IN_PROGRESS", "CODE_REVIEW", "BLOCKED", "MERGED"]'
fi

OUTSTANDING_LINES="$(jq -r --argjson statuses "$OUTSTANDING_STATUSES" '
  . as $root |
  $statuses[]
  | . as $status
  | [$root.requirements[] | select(.status == $status)] as $items
  | select(($items | length) > 0)
  | "- " + $status + ": " + ($items | map(.id) | join(", "))
' "$REQ_MANIFEST")"

if [ -n "$OUTSTANDING_LINES" ]; then
  echo "$OUTSTANDING_LINES"
else
  echo "- None"
fi

echo ""
echo "Outstanding details:"
if [ "$REQUIRES_DEPLOYMENT" = "false" ]; then
  DETAIL_LINES="$(jq -r '.requirements[]
    | select(.status != "DEPLOYED" and .status != "CANCELLED" and .status != "MERGED")
    | "- \(.id) [\(.status)]: \(.name) (priority: \(.priority))"' "$REQ_MANIFEST")"
else
  DETAIL_LINES="$(jq -r '.requirements[]
    | select(.status != "DEPLOYED" and .status != "CANCELLED")
    | "- \(.id) [\(.status)]: \(.name) (priority: \(.priority))"' "$REQ_MANIFEST")"
fi

if [ -n "$DETAIL_LINES" ]; then
  echo "$DETAIL_LINES"
else
  echo "- None"
fi

echo ""
if [ "$REQUIRES_DEPLOYMENT" = "false" ]; then
  echo "Completed (MERGED + DEPLOYED — no deployment required):"
  echo "- MERGED: $MERGED_COUNT"
  echo "- DEPLOYED: $DEPLOYED_COUNT"
  echo "- TOTAL COMPLETED: $COMPLETED_COUNT"
else
  echo "Completed (DEPLOYED only — deployment required):"
  echo "- MERGED (awaiting deploy): $MERGED_COUNT"
  echo "- DEPLOYED: $DEPLOYED_COUNT"
  echo "- TOTAL COMPLETED: $COMPLETED_COUNT"
fi

echo ""
echo "Status board: docs/STATUS.md"
