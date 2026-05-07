#!/bin/bash
# Shared helpers for resolving the canonical Vibe Master project root.

vibe_resolve_project_root() {
  local override_root="${VIBE_PROJECT_ROOT:-}"
  local current_root
  local common_dir_raw
  local common_dir
  local canonical_root

  if [ -n "$override_root" ]; then
    if [ ! -d "$override_root" ]; then
      echo "Error: VIBE_PROJECT_ROOT is not a directory: $override_root" >&2
      return 1
    fi
    (cd "$override_root" && pwd -P)
    return 0
  fi

  current_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  if ! current_root="$(cd "$current_root" 2>/dev/null && pwd -P)"; then
    echo "Error: Unable to resolve current repository root." >&2
    return 1
  fi

  common_dir_raw="$(git -C "$current_root" rev-parse --git-common-dir 2>/dev/null || true)"
  if [ -z "$common_dir_raw" ]; then
    printf '%s\n' "$current_root"
    return 0
  fi

  case "$common_dir_raw" in
    /*) common_dir="$common_dir_raw" ;;
    *) common_dir="$current_root/$common_dir_raw" ;;
  esac

  if ! common_dir="$(cd "$common_dir" 2>/dev/null && pwd -P)"; then
    printf '%s\n' "$current_root"
    return 0
  fi

  if ! canonical_root="$(cd "$(dirname "$common_dir")" 2>/dev/null && pwd -P)"; then
    printf '%s\n' "$current_root"
    return 0
  fi

  printf '%s\n' "$canonical_root"
}
