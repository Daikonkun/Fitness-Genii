#!/bin/bash
# Initialize a new vibe project by clearing only Vibe Master template REQs
# while preserving project-owned REQs.

set -e

echo "🚀 Vibe Agent Orchestrator - Project Initialization"
echo "===================================================="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/_project-root.sh"
PROJECT_ROOT="$(vibe_resolve_project_root)"
PROJECT_NAME="${1:-My Vibe Project}"
REQ_MANIFEST="$PROJECT_ROOT/.requirement-manifest.json"
WORKTREE_MANIFEST="$PROJECT_ROOT/.worktree-manifest.json"
source "$PROJECT_ROOT/scripts/_manifest-lock.sh"

echo "📦 Project: $PROJECT_NAME"
echo "📍 Location: $PROJECT_ROOT"
echo ""

# Self-protection: refuse to run on the Vibe Master source repo
if [ -f "$PROJECT_ROOT/.vibe-master-source" ]; then
  echo "❌ Error: This is the Vibe Master source repository."
  echo "   The /init command cannot run here to protect the template's own REQ history."
  echo "   Clone or copy this repo to a new directory first."
  exit 1
fi

# Initialize git if needed
if [ ! -d .git ]; then
  echo "🔧 Initializing git repository..."
  git init
  git config user.email "ai@vibe.local"
  git config user.name "Vibe Agent"
fi

# Make scripts executable
chmod +x scripts/*.sh

# Create docs/requirements directory
mkdir -p docs/requirements

# --- Clear only Vibe Master template REQs ---
# Keep project-owned REQs (origin: "project" or missing/null origin).

if [ -f "$REQ_MANIFEST" ]; then
  # Count existing and target REQs for reporting
  TOTAL=$(jq '[.requirements[]?] | length' "$REQ_MANIFEST" 2>/dev/null || echo 0)
  VM_COUNT=$(jq '[.requirements[]? | select(.origin == "vibe-master")] | length' "$REQ_MANIFEST" 2>/dev/null || echo 0)

  # Remove REQ-* spec files only for Vibe Master REQ IDs
  VM_IDS=$(jq -r '.requirements[]? | select(.origin == "vibe-master") | .id' "$REQ_MANIFEST" 2>/dev/null || true)
  CLEANED=0
  if [ -n "$VM_IDS" ]; then
    while IFS= read -r req_id; do
      [ -n "$req_id" ] || continue
      for f in "$PROJECT_ROOT"/docs/requirements/"$req_id"-*.md; do
        [ -f "$f" ] || continue
        rm "$f"
        CLEANED=$((CLEANED + 1))
      done
    done << EOF
$VM_IDS
EOF
  fi

  PRESERVED=$((TOTAL - VM_COUNT))
  echo "🧹 Cleared $VM_COUNT Vibe Master requirement(s) and removed $CLEANED matching spec file(s)"
  echo "📌 Preserved $PRESERVED project-owned requirement(s)"

  if [ "$VM_COUNT" -eq 0 ]; then
    echo "ℹ️  No Vibe Master requirements found to clear; project is already initialized."
  fi

  # Remove only Vibe Master template REQs and set the new project name
  jq_update_manifest_locked "$REQ_MANIFEST" \
    '.projectName = $name |
     .requirements = [.requirements[]? | select(.origin != "vibe-master")]' \
    --arg name "$PROJECT_NAME"
else
  echo "📋 Initializing requirement manifest..."
  with_manifest_lock "$REQ_MANIFEST" bash -c '
    manifest="$1"
    cat > "$manifest" << '\''JSON'\''
{
  "$schema": ".requirement-manifest.schema.json",
  "version": "1.0",
  "projectName": "",
  "requiresDeployment": true,
  "requirements": []
}
JSON
  ' _ "$REQ_MANIFEST"

  jq_update_manifest_locked "$REQ_MANIFEST" '.projectName = $name' --arg name "$PROJECT_NAME"
fi

# Reset worktree manifest so worktree state starts clean after init
echo "📋 Resetting worktree manifest..."
with_manifest_lock "$WORKTREE_MANIFEST" bash -c '
  manifest="$1"
  cat > "$manifest" << '\''JSON'\''
{
  "$schema": ".worktree-manifest.schema.json",
  "version": "1.0",
  "worktrees": []
}
JSON
 ' _ "$WORKTREE_MANIFEST"

# Regenerate docs
if [ -f scripts/regenerate-docs.sh ]; then
  echo "📄 Regenerating docs..."
  bash scripts/regenerate-docs.sh
fi

# Create initial commit
git add -A
git commit -m "chore: init project $PROJECT_NAME" --no-verify 2>/dev/null || true

echo ""
echo "✅ Initialization complete!"
echo ""
echo "Next steps:"
echo "  1. Create your first requirement: /add-requirement \"Feature\" \"Description\""
echo "  2. Check status: /status"
echo "  3. Start work: /start-work REQ-XXXXX"
echo ""
echo "Configuration complete. Open in VS Code to begin!"
