#!/bin/bash
# Generate or update Development Plan section in a requirement spec file
# Usage: ./scripts/generate-plan.sh <REQ-ID> [spec-file]

set -euo pipefail

REQ_ID="${1:-}"
SPEC_FILE="${2:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/_project-root.sh"
PROJECT_ROOT="$(vibe_resolve_project_root)"

if [ -z "$REQ_ID" ]; then
  echo "Usage: $0 REQ-<timestamp> [spec-file]" >&2
  exit 1
fi

if [ -z "$SPEC_FILE" ]; then
  SPEC_FILE="$(find "$PROJECT_ROOT/docs/requirements" -name "${REQ_ID}-*.md" | head -1)"
fi

if [ ! -f "$SPEC_FILE" ]; then
  echo "Error: Spec file not found for $REQ_ID" >&2
  exit 1
fi

# Read key sections from spec (dynamically used in plan) - improved parsing
DESCRIPTION=$(awk '/^## Description/,/^## Success Criteria/{if(!/^## / && NF>0) print}' "$SPEC_FILE" | head -1 | sed 's/^[ \t]*//;s/[ \t]*$//' | cut -c1-80 || echo "No description")
SUCCESS=$(awk '/^## Success Criteria/,/^## Technical Notes/{if(!/^## / && NF>0) print}' "$SPEC_FILE" | head -2 | tr '\n' ' ' | sed 's/^[ \t]*//;s/[ \t]*$//' | cut -c1-100 || echo "No success criteria")
TECH_NOTES=$(awk '/^## Technical Notes/,/^## Dependencies/{if(!/^## / && NF>0) print}' "$SPEC_FILE" | head -1 | sed 's/^[ \t]*//;s/[ \t]*$//' | cut -c1-100 || echo "No technical notes")

# Use relative path for portability
REL_SPEC="docs/requirements/$(basename "$SPEC_FILE")"

PLAN_FILE=$(mktemp)
cat > "$PLAN_FILE" << EOF
## Development Plan

1. Review Description, Success Criteria, and Technical Notes in \`$REL_SPEC\`.
   - **Summary**: $DESCRIPTION
   - **Key criteria**: $SUCCESS
2. Analyse Technical Notes and identify implementation approach.
   - **Notes**: $TECH_NOTES
3. Implement changes in the files/scripts referenced by the requirement spec.
4. Run \`./scripts/regenerate-docs.sh\` to update manifests and generated docs.
5. Validate with \`./scripts/show-requirement.sh $REQ_ID\` and verify success criteria are met.

**Last updated**: $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

# Replace existing Development Plan section or append before Dependencies
if grep -q "^## Development Plan" "$SPEC_FILE"; then
  SPEC_TMP="$(mktemp "${SPEC_FILE}.XXXXXX")"
  awk -v planfile="$PLAN_FILE" '
    BEGIN { inplan=0 }
    /^## Development Plan/ { inplan=1; next }
    /^## (Dependencies|Worktree)/ { if (inplan) { system("cat " planfile); inplan=0 } }
    !inplan { print }
    END { if (inplan) system("cat " planfile) }
  ' "$SPEC_FILE" > "$SPEC_TMP"
  mv "$SPEC_TMP" "$SPEC_FILE"
else
  SPEC_TMP="$(mktemp "${SPEC_FILE}.XXXXXX")"
  awk -v planfile="$PLAN_FILE" '
    /^## Dependencies/ { print ""; system("cat " planfile); print "" }
    { print }
  ' "$SPEC_FILE" > "$SPEC_TMP"
  mv "$SPEC_TMP" "$SPEC_FILE"
fi

rm -f "$PLAN_FILE"

echo "✅ Development Plan updated in $SPEC_FILE"
