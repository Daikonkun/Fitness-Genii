#!/bin/bash
# Create a new requirement and optionally start a worktree for it

set -euo pipefail

usage() {
  cat << 'EOF'
Usage: ./scripts/create-requirement.sh "<name>" "<description>" [priority] [--no-commit]

priority: CRITICAL | HIGH | MEDIUM | LOW (default: MEDIUM)

Flags:
  --no-commit  Create requirement files but skip final git add/commit
EOF
}

ARGS=()
NO_COMMIT="false"

for arg in "$@"; do
  case "$arg" in
    --no-commit)
      NO_COMMIT="true"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      echo "Error: Unknown option: $arg" >&2
      usage >&2
      exit 1
      ;;
    *)
      ARGS+=("$arg")
      ;;
  esac
done

if [ "${#ARGS[@]}" -lt 2 ] || [ "${#ARGS[@]}" -gt 3 ]; then
  echo "Error: Invalid arguments." >&2
  usage >&2
  exit 1
fi

REQ_NAME="${ARGS[0]}"
REQ_DESCRIPTION="${ARGS[1]}"
REQ_PRIORITY="${ARGS[2]:-MEDIUM}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/_project-root.sh"
PROJECT_ROOT="$(vibe_resolve_project_root)"
REQ_MANIFEST="$PROJECT_ROOT/.requirement-manifest.json"
source "$PROJECT_ROOT/scripts/_manifest-lock.sh"

generate_req_numeric_id() {
  if command -v python3 >/dev/null 2>&1; then
    python3 - << 'PY'
import random
import time

seed = int(time.time() * 1_000_000)
suffix = random.randint(0, 999)
print(f"{seed}{suffix:03d}")
PY
    return
  fi

  # Fallback: seconds plus two random chunks; still preserves numeric REQ-<digits> format.
  printf '%s%05d%05d\n' "$(date +%s)" "$RANDOM" "$RANDOM"
}

append_requirement_locked() {
  local manifest="$1"
  local req_id="$2"
  local req_name="$3"
  local req_desc="$4"
  local req_priority="$5"
  local ts="$6"

  with_manifest_lock "$manifest" bash -c '
    manifest="$1"
    req_id="$2"
    req_name="$3"
    req_desc="$4"
    req_priority="$5"
    ts="$6"

    if jq -e --arg id "$req_id" ".requirements[]? | select(.id == \$id)" "$manifest" >/dev/null; then
      echo "Error: Generated requirement ID collision: $req_id" >&2
      exit 1
    fi

    tmp_file="$(mktemp "${manifest}.XXXXXX")"
    if ! jq --arg id "$req_id" \
            --arg name "$req_name" \
            --arg desc "$req_desc" \
            --arg priority "$req_priority" \
            --arg ts "$ts" \
            '\''.requirements += [{
              "id": $id,
              "name": $name,
              "description": $desc,
              "status": "PROPOSED",
              "priority": $priority,
              "origin": "project",
              "createdAt": $ts,
              "updatedAt": $ts
            }] '\'' \
            "$manifest" > "$tmp_file"; then
      rm -f "$tmp_file"
      exit 1
    fi

    mv "$tmp_file" "$manifest"
  ' _ "$manifest" "$req_id" "$req_name" "$req_desc" "$req_priority" "$ts"
}

REQ_ID="REQ-$(generate_req_numeric_id)"
SLUG=$(echo "$REQ_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//; s/-$//')
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

echo "📝 Creating requirement: $REQ_ID"
echo "   Name: $REQ_NAME"
echo "   Priority: $REQ_PRIORITY"

# Ensure manifest exists
if [ ! -f "$REQ_MANIFEST" ]; then
  with_manifest_lock "$REQ_MANIFEST" bash -c '
    manifest="$1"
    if [ -f "$manifest" ]; then
      exit 0
    fi

    cat > "$manifest" << '\''JSON'\''
{
  "$schema": ".requirement-manifest.schema.json",
  "version": "1.0",
  "projectName": "Vibe Project",
  "requiresDeployment": true,
  "requirements": []
}
JSON
  ' _ "$REQ_MANIFEST"
fi

# Add to manifest with a lock-guarded collision check and atomic rename.
append_requirement_locked "$REQ_MANIFEST" "$REQ_ID" "$REQ_NAME" "$REQ_DESCRIPTION" "$REQ_PRIORITY" "$TIMESTAMP"

# Create detailed spec file
mkdir -p "$PROJECT_ROOT/docs/requirements"
cat > "$PROJECT_ROOT/docs/requirements/${REQ_ID}-${SLUG}.md" << EOF
# $REQ_NAME

**ID**: $REQ_ID  
**Status**: PROPOSED  
**Priority**: $REQ_PRIORITY  
**Created**: $TIMESTAMP  

## Description

$REQ_DESCRIPTION

## Success Criteria

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Technical Notes

(Add implementation notes here)

## Dependencies

(List other requirement IDs if applicable, e.g., REQ-XXX, REQ-YYY)

## Worktree

(Will be populated when work starts: feature/REQ-ID-slug)

---

* **Linked Worktree**: None yet
* **Branch**: None yet
* **Merged**: No
* **Deployed**: No
EOF

# Keep generated dashboards in sync so new REQs are immediately visible in docs/STATUS.md.
if [ -x "$PROJECT_ROOT/scripts/regenerate-docs.sh" ]; then
  "$PROJECT_ROOT/scripts/regenerate-docs.sh" >/dev/null
else
  echo "⚠️  Warning: scripts/regenerate-docs.sh not found or not executable; generated docs may be stale." >&2
fi

if [ "$NO_COMMIT" != "true" ]; then
  git -C "$PROJECT_ROOT" add \
    .requirement-manifest.json \
    REQUIREMENTS.md \
    docs/STATUS.md \
    docs/ROADMAP.md \
    docs/DEPENDENCIES.md \
    docs/requirements/ 2>/dev/null || true

  git -C "$PROJECT_ROOT" commit -m "chore: create requirement $REQ_ID" --no-verify 2>/dev/null || true
else
  echo "ℹ️  Skipping commit due to --no-commit; changes remain uncommitted for enrichment workflow."
fi

echo "✅ Requirement created: $REQ_ID"
echo "📄 Spec: docs/requirements/${REQ_ID}-${SLUG}.md"
echo ""
echo "Next steps:"
echo "  1. Review the specification file"
echo "  2. Run: /start-work $REQ_ID"
echo "  3. This will create a git worktree for isolated development"
