#!/bin/bash
# Regression check: status updates issued from a linked worktree must update
# the canonical project root manifests and docs/STATUS.md.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/_project-root.sh"
PROJECT_ROOT="$(vibe_resolve_project_root)"

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/worktree-status-root-check.XXXXXX")"
CHECK_ROOT="$TMP_ROOT/repo"
REQ_ID="REQ-1777777777001"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

mkdir -p "$CHECK_ROOT"
cp -R "$PROJECT_ROOT/scripts" "$CHECK_ROOT/scripts"
chmod +x "$CHECK_ROOT"/scripts/*.sh

cd "$CHECK_ROOT"
git init -b main >/dev/null
git config user.email "worktree-status-root-check@example.com"
git config user.name "Worktree Status Root Check"

mkdir -p docs/requirements

cat > .requirement-manifest.json << JSON
{
  "\$schema": ".requirement-manifest.schema.json",
  "version": "1.0",
  "projectName": "Worktree Status Root Check",
  "requiresDeployment": true,
  "requirements": [
    {
      "id": "$REQ_ID",
      "name": "Repro status root update",
      "description": "Verify status updates from linked worktrees update canonical root docs.",
      "status": "PROPOSED",
      "priority": "HIGH",
      "createdAt": "2026-01-01T00:00:00Z",
      "updatedAt": "2026-01-01T00:00:00Z"
    }
  ]
}
JSON

cat > .worktree-manifest.json << 'JSON'
{
  "$schema": ".worktree-manifest.schema.json",
  "version": "1.0",
  "worktrees": []
}
JSON

cat > "docs/requirements/${REQ_ID}-repro-status-root-update.md" << EOF
# Repro status root update

**ID**: $REQ_ID
**Status**: PROPOSED
**Priority**: HIGH
**Created**: 2026-01-01T00:00:00Z

## Description

Verify status updates from linked worktrees update canonical root docs.

## Success Criteria

- [ ] Status updates from a linked worktree update the canonical root manifest.
- [ ] Status updates from a linked worktree update canonical docs/STATUS.md.

## Technical Notes

Regression fixture.

## Dependencies

None

## Worktree

None

---

* **Linked Worktree**: None yet
* **Branch**: None yet
* **Merged**: No
* **Deployed**: No
EOF

bash scripts/regenerate-docs.sh >/dev/null
git add .
git commit -m "test: seed requirement" >/dev/null

bash scripts/start-work.sh "$REQ_ID" main >/dev/null

WORKTREE_PATH="$(jq -r --arg reqId "$REQ_ID" '
  .worktrees[] | select(any(.requirementIds[]?; . == $reqId)) | .path
' .worktree-manifest.json | head -1)"

if [ -z "$WORKTREE_PATH" ] || [ ! -d "$WORKTREE_PATH" ]; then
  echo "FAIL: start-work did not create a linked worktree path." >&2
  exit 1
fi

WORKTREE_STATUS="$(jq -r --arg reqId "$REQ_ID" '
  .requirements[] | select(.id == $reqId) | .status
' "$WORKTREE_PATH/.requirement-manifest.json")"

if [ "$WORKTREE_STATUS" != "IN_PROGRESS" ]; then
  echo "FAIL: linked worktree was created with stale requirement status: $WORKTREE_STATUS" >&2
  exit 1
fi

(
  cd "$WORKTREE_PATH"
  bash scripts/update-requirement-status.sh "$REQ_ID" CODE_REVIEW >/dev/null
)

ROOT_STATUS="$(jq -r --arg reqId "$REQ_ID" '
  .requirements[] | select(.id == $reqId) | .status
' .requirement-manifest.json)"

if [ "$ROOT_STATUS" != "CODE_REVIEW" ]; then
  echo "FAIL: canonical root manifest status is $ROOT_STATUS, expected CODE_REVIEW." >&2
  exit 1
fi

if ! awk -v reqId="$REQ_ID" '
  /^## CODE_REVIEW / { in_code_review = 1; next }
  /^## / { in_code_review = 0 }
  in_code_review && index($0, reqId) { found = 1 }
  END { exit found ? 0 : 1 }
' docs/STATUS.md; then
  echo "FAIL: canonical docs/STATUS.md does not list $REQ_ID under CODE_REVIEW." >&2
  exit 1
fi

echo "PASS: linked worktree status updates target canonical root manifests and docs."
