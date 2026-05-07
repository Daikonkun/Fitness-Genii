#!/bin/bash
# Shared helpers for lock-safe, atomic manifest writes.

manifest_lock_supports_flock() {
  if [ "${MANIFEST_LOCK_FORCE_MKDIR:-0}" = "1" ]; then
    return 1
  fi

  command -v flock >/dev/null 2>&1
}

manifest_lock_normalize_path() {
  local manifest_file="$1"
  local manifest_dir
  local manifest_name
  local abs_dir

  manifest_dir="$(dirname "$manifest_file")"
  manifest_name="$(basename "$manifest_file")"

  if ! abs_dir="$(cd "$manifest_dir" 2>/dev/null && pwd -P)"; then
    echo "Error: Unable to resolve manifest directory: $manifest_dir" >&2
    return 1
  fi

  printf '%s/%s\n' "$abs_dir" "$manifest_name"
}

manifest_lock_directory() {
  local manifest_file="$1"
  local manifest_dir
  local git_common_dir
  local abs_git_common_dir

  if [ -n "${MANIFEST_LOCK_DIR:-}" ]; then
    printf '%s\n' "$MANIFEST_LOCK_DIR"
    return 0
  fi

  manifest_dir="$(dirname "$manifest_file")"

  if command -v git >/dev/null 2>&1; then
    if git_common_dir="$(git -C "$manifest_dir" rev-parse --git-common-dir 2>/dev/null)"; then
      if [ -n "$git_common_dir" ]; then
        if [ "${git_common_dir#/}" != "$git_common_dir" ]; then
          printf '%s/.manifest-locks\n' "$git_common_dir"
        else
          abs_git_common_dir="$(cd "$manifest_dir" && cd "$git_common_dir" && pwd -P)"
          printf '%s/.manifest-locks\n' "$abs_git_common_dir"
        fi
        return 0
      fi
    fi
  fi

  printf '%s/vibe-manifest-locks\n' "${TMPDIR:-/tmp}"
}

manifest_lock_file_path() {
  local manifest_file="$1"
  local lock_root
  local checksum
  local manifest_slug

  lock_root="$(manifest_lock_directory "$manifest_file")" || return 1

  if ! mkdir -p "$lock_root"; then
    echo "Error: Unable to create manifest lock directory: $lock_root" >&2
    return 1
  fi

  checksum="$(printf '%s' "$manifest_file" | cksum | awk '{print $1 "-" $2}')"
  manifest_slug="$(basename "$manifest_file" | tr -c 'A-Za-z0-9._-' '_')"

  printf '%s/%s-%s.lock\n' "$lock_root" "$manifest_slug" "$checksum"
}

manifest_lock_wait_for_directory() {
  local lock_dir="$1"
  local max_attempts="${2:-3000}"
  local attempt=0

  while ! mkdir "$lock_dir" 2>/dev/null; do
    attempt=$((attempt + 1))
    if [ "$attempt" -ge "$max_attempts" ]; then
      echo "Error: timed out waiting for lock: $lock_dir" >&2
      echo "Hint: install flock with: bash scripts/bootstrap-deps.sh --install" >&2
      return 1
    fi
    sleep 0.01
  done
}

manifest_lock_cleanup_artifacts() {
  local lock_dir="$1"

  if [ -d "$lock_dir" ]; then
    if ! rmdir "$lock_dir" 2>/dev/null; then
      rm -rf "$lock_dir" 2>/dev/null || true
    fi
  fi
}

with_manifest_lock() {
  local manifest_file="${1:-}"
  shift || true

  if [ -z "$manifest_file" ] || [ "$#" -eq 0 ]; then
    echo "Usage: with_manifest_lock <manifest-file> <command> [args...]" >&2
    return 1
  fi

  local lock_file="${manifest_file}.lock"
  local lock_dir=""
  local exit_code=0
  local normalized_manifest_file=""

  normalized_manifest_file="$(manifest_lock_normalize_path "$manifest_file")" || return 1
  lock_file="$(manifest_lock_file_path "$normalized_manifest_file")" || return 1
  lock_dir="${lock_file}.d"

  if manifest_lock_supports_flock; then
    if (
      flock -x 200
      "$@"
    ) 200>>"$lock_file"; then
      exit_code=0
    else
      exit_code=$?
    fi

    return "$exit_code"
  fi

  manifest_lock_wait_for_directory "$lock_dir" || return 1

  if "$@"; then
    exit_code=0
  else
    exit_code=$?
  fi

  manifest_lock_cleanup_artifacts "$lock_dir"
  return "$exit_code"
}

_jq_update_manifest_locked_inner() {
  local manifest_file="$1"
  local jq_filter="$2"
  shift 2

  local tmp_file
  tmp_file="$(mktemp "${manifest_file}.XXXXXX")"

  if ! jq "$@" "$jq_filter" "$manifest_file" > "$tmp_file"; then
    rm -f "$tmp_file"
    return 1
  fi

  if ! mv "$tmp_file" "$manifest_file"; then
    rm -f "$tmp_file"
    return 1
  fi
}

jq_update_manifest_locked() {
  local manifest_file="$1"
  local jq_filter="$2"
  shift 2

  if [ ! -f "$manifest_file" ]; then
    echo "Error: Manifest not found: $manifest_file" >&2
    return 1
  fi

  with_manifest_lock "$manifest_file" _jq_update_manifest_locked_inner "$manifest_file" "$jq_filter" "$@"
}

_with_manifest_locks_inner() {
  local first_manifest="$1"
  local second_manifest="$2"
  shift 2

  with_manifest_lock "$first_manifest" with_manifest_lock "$second_manifest" "$@"
}

with_manifest_locks() {
  local manifest_a="${1:-}"
  local manifest_b="${2:-}"
  shift 2 || true

  if [ -z "$manifest_a" ] || [ -z "$manifest_b" ] || [ "$#" -eq 0 ]; then
    echo "Usage: with_manifest_locks <manifest-a> <manifest-b> <command> [args...]" >&2
    return 1
  fi

  local normalized_a
  local normalized_b
  local first_manifest
  local second_manifest

  normalized_a="$(manifest_lock_normalize_path "$manifest_a")" || return 1
  normalized_b="$(manifest_lock_normalize_path "$manifest_b")" || return 1

  if [ "$normalized_a" = "$normalized_b" ]; then
    with_manifest_lock "$normalized_a" "$@"
    return $?
  fi

  if [ "$normalized_a" \< "$normalized_b" ]; then
    first_manifest="$normalized_a"
    second_manifest="$normalized_b"
  else
    first_manifest="$normalized_b"
    second_manifest="$normalized_a"
  fi

  _with_manifest_locks_inner "$first_manifest" "$second_manifest" "$@"
}
