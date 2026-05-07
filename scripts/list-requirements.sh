#!/bin/bash
# List requirements from manifest, optionally filtered by status

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/_project-root.sh"
PROJECT_ROOT="$(vibe_resolve_project_root)"
REQ_MANIFEST="$PROJECT_ROOT/.requirement-manifest.json"
STATUS_FILTER="$(echo "${1:-}" | tr '[:lower:]' '[:upper:]')"

if [ ! -f "$REQ_MANIFEST" ]; then
  echo "Error: .requirement-manifest.json not found" >&2
  exit 1
fi

if [ -n "$STATUS_FILTER" ] && ! [[ "$STATUS_FILTER" =~ ^(PROPOSED|IN_PROGRESS|CODE_REVIEW|MERGED|DEPLOYED|BLOCKED|BACKLOG|CANCELLED)$ ]]; then
  echo "Error: Invalid status filter: $STATUS_FILTER" >&2
  exit 1
fi

echo "=== Requirements ==="
if [ -n "$STATUS_FILTER" ]; then
  echo "Filter: $STATUS_FILTER"
else
  echo "Filter: ALL"
fi

RESULTS="$(jq -r --arg status "$STATUS_FILTER" '
  ["ID", "STATUS", "PRIORITY", "NAME"],
  (.requirements[]
    | select($status == "" or .status == $status)
    | [.id, .status, .priority, .name])
  | @tsv
' "$REQ_MANIFEST")"

COUNT="$(jq -r --arg status "$STATUS_FILTER" '
  [.requirements[] | select($status == "" or .status == $status)] | length
' "$REQ_MANIFEST")"

if [ "$COUNT" -eq 0 ]; then
  echo "No requirements found."
  exit 0
fi

printf "%s\n" "$RESULTS" | column -t -s $'\t'
echo ""
echo "Count: $COUNT"
