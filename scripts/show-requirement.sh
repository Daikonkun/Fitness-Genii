#!/bin/bash
# Show a requirement and its detailed spec file if present

set -euo pipefail

REQ_ID="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/_project-root.sh"
PROJECT_ROOT="$(vibe_resolve_project_root)"
REQ_MANIFEST="$PROJECT_ROOT/.requirement-manifest.json"

if [ -z "$REQ_ID" ]; then
  echo "Usage: $0 REQ-<timestamp>" >&2
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

REQ_JSON="$(jq -c --arg reqId "$REQ_ID" '.requirements[] | select(.id == $reqId)' "$REQ_MANIFEST")"
if [ -z "$REQ_JSON" ]; then
  echo "Error: Requirement not found: $REQ_ID" >&2
  exit 1
fi

echo "=== Requirement $REQ_ID ==="
echo "$REQ_JSON" | jq '.'

SPEC_FILE="$(find "$PROJECT_ROOT/docs/requirements" -maxdepth 1 -type f -name "${REQ_ID}-*.md" | head -1)"
if [ -n "$SPEC_FILE" ]; then
  echo ""
  echo "=== Specification Path ==="
  echo "$SPEC_FILE"
  echo ""
  echo "=== Specification Content ==="
  cat "$SPEC_FILE"
else
  echo ""
  echo "No spec file found in docs/requirements for $REQ_ID"
fi
