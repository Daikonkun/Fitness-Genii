#!/bin/bash
# Safely preview/apply Vibe Master template updates in an isolated worktree.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/_project-root.sh"
PROJECT_ROOT="$(vibe_resolve_project_root)"

BASE_BRANCH="main"
WORKTREE_PATH=""
BRANCH_NAME="chore/vibe-master-upgrade"
COMMAND_NAME="upgrade"
CHECK_ONLY="false"
APPLY="false"
ASSUME_YES="false"
TEMPLATE_REPO="${VIBE_MASTER_TEMPLATE_REPO:-}"
DEFAULT_TEMPLATE_REPO="${VIBE_MASTER_DEFAULT_TEMPLATE_REPO:-https://github.com/Daikonkun/vibe-master.git}"

UPGRADE_STAGING=""
TEMPLATE_DIR=""
DIFF_FILE=""
DIFF_HAS_CHANGES="false"

MANIFEST_FILES=(
  ".requirement-manifest.json"
  ".worktree-manifest.json"
)

ROOT_STATUS_BEFORE="$(git -C "$PROJECT_ROOT" status --short || true)"

usage() {
  cat << 'EOF'
Usage: ./scripts/upgrade.sh [options]

Safely upgrade from the latest Vibe Master GitHub template in an isolated worktree.

Options:
  --template-repo <url>  GitHub URL for the template source repository.
                         Default resolution order: --template-repo, VIBE_MASTER_TEMPLATE_REPO,
                         origin remote URL (GitHub), then VIBE_MASTER_DEFAULT_TEMPLATE_REPO
                         (or built-in fallback: https://github.com/Daikonkun/vibe-master.git).
  --base-branch <name>   Base branch for upgrade worktree creation (default: main)
  --worktree-path <path> Upgrade worktree path (default: ../upgrade/vibe-master-latest)
  --branch-name <name>   Upgrade branch name (default: chore/vibe-master-upgrade)
  --command-name <name>  Slash command name to validate (default: upgrade)
  --check-only           Run preflight conflict checks only, then exit
  --apply                Apply template files after previewing diff
  --yes                  Skip interactive confirmation prompt (with --apply only)
  -h, --help             Show this help

Behavior:
  1) Always performs slash-command conflict preflight checks first.
  2) Creates/reuses an isolated sibling worktree.
  3) Clones latest template into <worktree>/.upgrade-template/latest.
  4) Generates diff preview at <worktree>/.upgrade-template/upgrade-preview.diff.
  5) Applies changes only when --apply is used and confirmation is explicit.
  6) Preserves local manifest history by merging manifest metadata in a separate apply path.
EOF
}

KNOWN_NATIVE_COMMANDS=(
  ask
  explain
  fix
  tests
  test
  doc
  docs
  help
  clear
  new
  terminal
  run
  start
  debug
  review
)

check_command_conflicts() {
  local command="$1"
  local prompts_dir="$PROJECT_ROOT/.github/prompts"

  if [[ ! "$command" =~ ^[a-z0-9-]+$ ]]; then
    echo "Error: Invalid command name '$command'. Use lowercase letters, digits, and hyphens only." >&2
    return 1
  fi

  if [ ! -d "$prompts_dir" ]; then
    echo "Error: Prompt directory not found: $prompts_dir" >&2
    return 1
  fi

  local native
  for native in "${KNOWN_NATIVE_COMMANDS[@]}"; do
    if [ "$native" = "$command" ]; then
      echo "Error: /$command conflicts with a known native VS Code/Copilot slash command name." >&2
      echo "Recommendation: rename to /vm-$command (or another unique project prefix)." >&2
      return 1
    fi
  done

  local project_match_count
  project_match_count="$(find "$prompts_dir" -maxdepth 1 -type f -name "${command}.prompt.md" | wc -l | tr -d ' ')"
  if [ "$project_match_count" -gt 1 ]; then
    echo "Error: /$command is defined by multiple prompt files in .github/prompts/." >&2
    echo "Recommendation: keep one canonical file and rename others to unique slash command names." >&2
    return 1
  fi

  echo "✅ Preflight command check passed for /$command"
  echo "   Project prompt matches: $project_match_count file(s)"
  echo "   Known native/Copilot command collisions: none"
}

resolve_template_repo() {
  if [ -n "$TEMPLATE_REPO" ]; then
    return 0
  fi

  if git -C "$PROJECT_ROOT" remote get-url origin >/dev/null 2>&1; then
    local origin_url
    origin_url="$(git -C "$PROJECT_ROOT" remote get-url origin)"
    if echo "$origin_url" | grep -Eq 'github\.com'; then
      TEMPLATE_REPO="$origin_url"
    fi
  fi

  if [ -z "$TEMPLATE_REPO" ]; then
    TEMPLATE_REPO="$DEFAULT_TEMPLATE_REPO"
    echo "ℹ️  No explicit template repo configured; using fallback: $TEMPLATE_REPO"
  fi

  if ! echo "$TEMPLATE_REPO" | grep -Eq 'github\.com'; then
    echo "Error: Template repo must be a GitHub URL: $TEMPLATE_REPO" >&2
    return 1
  fi

  return 0
}

is_registered_worktree() {
  local target_path="$1"
  local normalized_target
  normalized_target="$(cd "$target_path" 2>/dev/null && pwd -P)" || return 1

  git -C "$PROJECT_ROOT" worktree list --porcelain \
    | awk '/^worktree / {print substr($0, 10)}' \
    | while IFS= read -r listed_path; do
        [ -z "$listed_path" ] && continue
        if [ "$(cd "$listed_path" 2>/dev/null && pwd -P)" = "$normalized_target" ]; then
          return 0
        fi
      done
}

ensure_upgrade_worktree() {
  if [ -z "$WORKTREE_PATH" ]; then
    WORKTREE_PATH="$(dirname "$PROJECT_ROOT")/upgrade/vibe-master-latest"
  fi

  if [ -d "$WORKTREE_PATH" ]; then
    if is_registered_worktree "$WORKTREE_PATH"; then
      echo "ℹ️ Reusing existing upgrade worktree: $WORKTREE_PATH"
      return 0
    fi
    echo "Error: Path exists but is not a registered git worktree: $WORKTREE_PATH" >&2
    return 1
  fi

  if ! git -C "$PROJECT_ROOT" rev-parse --verify "$BASE_BRANCH" >/dev/null 2>&1; then
    echo "Error: Base branch does not exist locally: $BASE_BRANCH" >&2
    return 1
  fi

  mkdir -p "$(dirname "$WORKTREE_PATH")"

  if git -C "$PROJECT_ROOT" show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
    git -C "$PROJECT_ROOT" worktree add "$WORKTREE_PATH" "$BRANCH_NAME"
  else
    git -C "$PROJECT_ROOT" worktree add -b "$BRANCH_NAME" "$WORKTREE_PATH" "$BASE_BRANCH"
  fi

  echo "✅ Created isolated upgrade worktree: $WORKTREE_PATH"
}

sync_upgrade_worktree_with_project_root() {
  local target_ref

  if ! command -v rsync >/dev/null 2>&1; then
    echo "Error: rsync is required to refresh the upgrade worktree." >&2
    return 1
  fi

  if ! target_ref="$(git -C "$PROJECT_ROOT" rev-parse --verify "$BASE_BRANCH^{commit}" 2>/dev/null)"; then
    echo "Error: Unable to resolve base branch commit for refresh: $BASE_BRANCH" >&2
    return 1
  fi

  if is_registered_worktree "$WORKTREE_PATH"; then
    if ! git -C "$PROJECT_ROOT" -C "$WORKTREE_PATH" diff --quiet --ignore-submodules HEAD --; then
      echo "Error: Upgrade worktree has uncommitted changes. Commit, stash, or remove them before rerunning upgrade." >&2
      return 1
    fi

    echo "🔄 Refreshing upgrade worktree from project root ($BASE_BRANCH @ ${target_ref:0:12})"
    git -C "$WORKTREE_PATH" checkout -q "$BRANCH_NAME"
    git -C "$WORKTREE_PATH" reset --hard "$target_ref" >/dev/null
    git -C "$WORKTREE_PATH" clean -fdx >/dev/null
  fi

  rsync -a --delete \
    --exclude '.git' \
    --exclude '.upgrade-template' \
    --exclude '.DS_Store' \
    "$PROJECT_ROOT"/ "$WORKTREE_PATH"/

  git -C "$WORKTREE_PATH" add -A
  if git -C "$WORKTREE_PATH" diff --cached --quiet --ignore-submodules --; then
    echo "✅ Upgrade worktree already matches the active project tree."
  else
    echo "✅ Refreshed upgrade worktree snapshot from active project tree."
  fi
}

prepare_preview() {
  UPGRADE_STAGING="$WORKTREE_PATH/.upgrade-template"
  TEMPLATE_DIR="$UPGRADE_STAGING/latest"
  DIFF_FILE="$UPGRADE_STAGING/upgrade-preview.diff"

  rm -rf "$TEMPLATE_DIR"
  mkdir -p "$UPGRADE_STAGING"

  echo "⬇️  Cloning template: $TEMPLATE_REPO"
  git clone --depth 1 "$TEMPLATE_REPO" "$TEMPLATE_DIR" >/dev/null

  if diff -ruN \
    --exclude='.git' \
    --exclude='.upgrade-template' \
    --exclude='.requirement-manifest.json' \
    --exclude='.worktree-manifest.json' \
    "$TEMPLATE_DIR" "$WORKTREE_PATH" > "$DIFF_FILE"; then
    DIFF_HAS_CHANGES="false"
  else
    DIFF_HAS_CHANGES="true"
  fi

  echo "✅ Upgrade preview ready"
  echo "   Worktree: $WORKTREE_PATH"
  echo "   Template: $TEMPLATE_REPO"
  echo "   Diff file: $DIFF_FILE"
  echo "   Manifests: merged separately during --apply (history-preserving)"
  if [ "$DIFF_HAS_CHANGES" = "true" ]; then
    echo ""
    echo "Preview (first 120 lines):"
    head -n 120 "$DIFF_FILE"
  else
    echo "   No differences detected between template and worktree."
  fi
}

manifest_entry_count() {
  local file_path="$1"
  local array_key="$2"

  jq -r --arg key "$array_key" '(.[$key] // []) | if type == "array" then length else 0 end' "$file_path"
}

merge_manifest_preserving_history() {
  local manifest_name="$1"
  local local_path="$WORKTREE_PATH/$manifest_name"
  local template_path="$TEMPLATE_DIR/$manifest_name"
  local merged_path="$local_path.upgrade-merge.tmp"
  local array_key=""
  local before_count="0"
  local after_count="0"

  if [ ! -f "$local_path" ]; then
    echo "ℹ️  Local manifest missing, skipping merge: $manifest_name"
    return 0
  fi

  if [ ! -f "$template_path" ]; then
    echo "ℹ️  Template manifest missing, keeping local file unchanged: $manifest_name"
    return 0
  fi

  if ! jq -e . "$local_path" >/dev/null; then
    echo "Error: local manifest is not valid JSON: $local_path" >&2
    return 1
  fi

  if ! jq -e . "$template_path" >/dev/null; then
    echo "Error: template manifest is not valid JSON: $template_path" >&2
    return 1
  fi

  case "$manifest_name" in
    .requirement-manifest.json)
      array_key="requirements"
      before_count="$(manifest_entry_count "$local_path" "$array_key")"
      jq -n \
        --slurpfile local "$local_path" \
        --slurpfile template "$template_path" \
        '$local[0]
        | .["$schema"] = ($template[0]["$schema"] // .["$schema"])
        | .version = ($template[0].version // .version)
        | .projectName = (.projectName // $template[0].projectName)
        | .requiresDeployment = (.requiresDeployment // $template[0].requiresDeployment // true)
        | .requirements = (.requirements // [])' > "$merged_path"
      ;;
    .worktree-manifest.json)
      array_key="worktrees"
      before_count="$(manifest_entry_count "$local_path" "$array_key")"
      jq -n \
        --slurpfile local "$local_path" \
        --slurpfile template "$template_path" \
        '$local[0]
        | .["$schema"] = ($template[0]["$schema"] // .["$schema"])
        | .version = ($template[0].version // .version)
        | .worktrees = (.worktrees // [])' > "$merged_path"
      ;;
    *)
      echo "Error: unsupported manifest for merge: $manifest_name" >&2
      return 1
      ;;
  esac

  after_count="$(manifest_entry_count "$merged_path" "$array_key")"
  if [ "$after_count" -lt "$before_count" ]; then
    rm -f "$merged_path"
    echo "Error: refusing to reduce $manifest_name $array_key entries ($before_count -> $after_count)." >&2
    return 1
  fi

  mv "$merged_path" "$local_path"
  echo "✅ Preserved local $manifest_name history ($array_key entries: $after_count)."
}

merge_upgrade_manifests() {
  local manifest_name

  if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required for manifest-preserving upgrade apply." >&2
    return 1
  fi

  for manifest_name in "${MANIFEST_FILES[@]}"; do
    merge_manifest_preserving_history "$manifest_name"
  done
}

apply_template() {
  local applied_non_manifest="false"

  if [ "$ASSUME_YES" != "true" ]; then
    echo ""
    echo "Apply template files into the isolated worktree now? Type 'yes' to continue:"
    local confirmation
    read -r confirmation
    if [ "$confirmation" != "yes" ]; then
      echo "Cancelled apply. Preview artifacts remain in $UPGRADE_STAGING/."
      return 0
    fi
  fi

  if [ "$DIFF_HAS_CHANGES" = "true" ]; then
    if ! command -v rsync >/dev/null 2>&1; then
      echo "Error: rsync is required for --apply but is not installed." >&2
      return 1
    fi

    rsync -a --delete \
      --exclude '.git' \
      --exclude '.upgrade-template' \
      --exclude '.requirement-manifest.json' \
      --exclude '.worktree-manifest.json' \
      "$TEMPLATE_DIR"/ "$WORKTREE_PATH"/
    applied_non_manifest="true"
    echo "✅ Applied non-manifest template files in isolated worktree."
  else
    echo "ℹ️ No non-manifest file differences detected; applying manifest merge path only."
  fi

  merge_upgrade_manifests

  if [ "$applied_non_manifest" = "true" ]; then
    echo "✅ Applied template files in isolated worktree."
  else
    echo "✅ Manifest metadata merged in isolated worktree."
  fi
  echo "   Review with: git -C \"$WORKTREE_PATH\" status --short"
}

assert_root_unchanged() {
  local root_status_after
  root_status_after="$(git -C "$PROJECT_ROOT" status --short || true)"

  if [ "$root_status_after" != "$ROOT_STATUS_BEFORE" ]; then
    echo "Error: Active project working tree changed during upgrade workflow." >&2
    echo "Before:" >&2
    printf '%s\n' "$ROOT_STATUS_BEFORE" >&2
    echo "After:" >&2
    printf '%s\n' "$root_status_after" >&2
    return 1
  fi

  echo "✅ Active project tree remained unchanged (status snapshot matched)."
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

while [ "$#" -gt 0 ]; do
  case "$1" in
    --template-repo)
      shift
      if [ "$#" -eq 0 ]; then
        echo "Error: --template-repo requires a value" >&2
        usage >&2
        exit 1
      fi
      TEMPLATE_REPO="$1"
      shift
      ;;
    --base-branch)
      shift
      if [ "$#" -eq 0 ]; then
        echo "Error: --base-branch requires a value" >&2
        usage >&2
        exit 1
      fi
      BASE_BRANCH="$1"
      shift
      ;;
    --worktree-path)
      shift
      if [ "$#" -eq 0 ]; then
        echo "Error: --worktree-path requires a value" >&2
        usage >&2
        exit 1
      fi
      WORKTREE_PATH="$1"
      shift
      ;;
    --branch-name)
      shift
      if [ "$#" -eq 0 ]; then
        echo "Error: --branch-name requires a value" >&2
        usage >&2
        exit 1
      fi
      BRANCH_NAME="$1"
      shift
      ;;
    --command-name)
      shift
      if [ "$#" -eq 0 ]; then
        echo "Error: --command-name requires a value" >&2
        usage >&2
        exit 1
      fi
      COMMAND_NAME="$1"
      shift
      ;;
    --check-only)
      CHECK_ONLY="true"
      shift
      ;;
    --apply)
      APPLY="true"
      shift
      ;;
    --yes)
      ASSUME_YES="true"
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

if [ "$ASSUME_YES" = "true" ] && [ "$APPLY" != "true" ]; then
  echo "Error: --yes can only be used with --apply" >&2
  exit 1
fi

check_command_conflicts "$COMMAND_NAME"

if [ "$CHECK_ONLY" = "true" ]; then
  echo "Preflight check-only mode complete."
  exit 0
fi

resolve_template_repo
ensure_upgrade_worktree
sync_upgrade_worktree_with_project_root
prepare_preview

if [ "$APPLY" = "true" ]; then
  apply_template
else
  echo ""
  echo "Preview-only mode. Re-run with --apply after reviewing $DIFF_FILE."
fi

assert_root_unchanged

echo ""
echo "Next steps:"
echo "  1. Inspect diff: $DIFF_FILE"
echo "  2. If ready, run: ./scripts/upgrade.sh --apply --template-repo \"$TEMPLATE_REPO\""
echo "  3. Validate manifests/docs: jq . .requirement-manifest.json && jq . .worktree-manifest.json && bash scripts/regenerate-docs.sh"
echo "  4. Run upgrade regression check: bash scripts/check-upgrade-manifest-history.sh"