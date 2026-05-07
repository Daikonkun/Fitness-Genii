#!/bin/bash
# Regression check: concurrent manifest writers should not lose updates.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/_project-root.sh"
PROJECT_ROOT="$(vibe_resolve_project_root)"
source "$PROJECT_ROOT/scripts/_manifest-lock.sh"

WORKERS="${1:-40}"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/manifest-lock-race.XXXXXX")"
TEST_MANIFEST="$TMP_ROOT/manifest.json"
LOCK_ROOT="${MANIFEST_LOCK_DIR:-$TMP_ROOT/vibe-manifest-locks}"

# Keep lock artifacts in a controlled test root so they are cleaned with TMP_ROOT.
export MANIFEST_LOCK_DIR="$LOCK_ROOT"
TEST_MANIFEST="$(manifest_lock_normalize_path "$TEST_MANIFEST")"
TEST_LOCK_FILE="$(manifest_lock_file_path "$TEST_MANIFEST")"

cleanup_test_lock_file() {
  if [ -n "${TEST_LOCK_FILE:-}" ]; then
    rm -f "$TEST_LOCK_FILE" 2>/dev/null || true
  fi
}

cleanup() {
  cleanup_test_lock_file
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

lock_file_count() {
  if [ ! -d "$LOCK_ROOT" ]; then
    echo 0
    return
  fi

  find "$LOCK_ROOT" -type f -name '*.lock' | wc -l | tr -d ' '
}

INITIAL_LOCK_COUNT="$(lock_file_count)"

if [[ ! "$WORKERS" =~ ^[0-9]+$ ]] || [ "$WORKERS" -le 0 ]; then
  echo "Usage: $0 [worker-count]" >&2
  echo "Example: $0 40" >&2
  exit 1
fi

cat > "$TEST_MANIFEST" << 'JSON'
{
  "requirements": []
}
JSON

write_once() {
  local req_id="$1"

  jq_update_manifest_locked "$TEST_MANIFEST" \
    '.requirements += [{"id": $id}]' \
    --arg id "$req_id"
}

run_parallel_writes() {
  local prefix="$1"
  local count="$2"
  local i=1

  while [ "$i" -le "$count" ]; do
    write_once "${prefix}-${i}" &
    i=$((i + 1))
  done

  wait
}

assert_count() {
  local prefix="$1"
  local expected="$2"
  local actual
  local unique

  actual="$(jq --arg prefix "$prefix" '[.requirements[] | select(.id | startswith($prefix))] | length' "$TEST_MANIFEST")"
  unique="$(jq --arg prefix "$prefix" '[.requirements[] | select(.id | startswith($prefix)) | .id] | unique | length' "$TEST_MANIFEST")"

  if [ "$actual" -ne "$expected" ] || [ "$unique" -ne "$expected" ]; then
    echo "FAIL: lost or duplicate updates for prefix '$prefix' (actual=$actual unique=$unique expected=$expected)" >&2
    jq '.' "$TEST_MANIFEST" >&2
    exit 1
  fi
}

assert_error_propagation() {
  local backend="$1"
  local status=0
  local expected=17

  if [ "$backend" = "mkdir" ]; then
    MANIFEST_LOCK_FORCE_MKDIR=1 with_manifest_lock "$TEST_MANIFEST" bash -c 'exit 17' || status=$?
    unset MANIFEST_LOCK_FORCE_MKDIR
  else
    with_manifest_lock "$TEST_MANIFEST" bash -c 'exit 17' || status=$?
  fi

  if [ "$status" -ne "$expected" ]; then
    echo "FAIL: backend '$backend' did not preserve command exit code (expected=$expected actual=$status)" >&2
    exit 1
  fi
}

assert_waiter_newcomer_exclusivity_flock() {
  local first_holder_pid
  local waiter_pid
  local waiter_marker="$TMP_ROOT/flock-waiter-holding"
  local newcomer_exit=0
  local attempts=0

  rm -f "$waiter_marker"

  with_manifest_lock "$TEST_MANIFEST" bash -c 'sleep 0.20' &
  first_holder_pid=$!

  sleep 0.05

  with_manifest_lock "$TEST_MANIFEST" bash -c '
    marker="$1"
    touch "$marker"
    sleep 0.30
    rm -f "$marker"
  ' _ "$waiter_marker" &
  waiter_pid=$!

  wait "$first_holder_pid"

  while [ ! -f "$waiter_marker" ]; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 300 ]; then
      echo "FAIL: flock waiter did not acquire lock within expected time." >&2
      wait "$waiter_pid" || true
      exit 1
    fi
    sleep 0.01
  done

  set +e
  with_manifest_lock "$TEST_MANIFEST" bash -c '
    marker="$1"
    if [ -f "$marker" ]; then
      exit 42
    fi
  ' _ "$waiter_marker"
  newcomer_exit=$?
  set -e

  wait "$waiter_pid"

  if [ "$newcomer_exit" -eq 42 ]; then
    echo "FAIL: flock waiter/newcomer overlap detected; lock exclusivity was broken." >&2
    exit 1
  fi

  if [ "$newcomer_exit" -ne 0 ]; then
    echo "FAIL: newcomer lock attempt failed unexpectedly (exit=$newcomer_exit)." >&2
    exit 1
  fi
}

if manifest_lock_supports_flock; then
  run_parallel_writes "flock" "$WORKERS"
  assert_count "flock" "$WORKERS"
  assert_error_propagation "flock"
  assert_waiter_newcomer_exclusivity_flock

  MANIFEST_LOCK_FORCE_MKDIR=1
  run_parallel_writes "mkdir" "$WORKERS"
  unset MANIFEST_LOCK_FORCE_MKDIR
  assert_count "mkdir" "$WORKERS"
  assert_error_propagation "mkdir"

  cleanup_test_lock_file
  FINAL_LOCK_COUNT="$(lock_file_count)"
  if [ "$FINAL_LOCK_COUNT" -gt "$INITIAL_LOCK_COUNT" ]; then
    echo "FAIL: lock artifacts grew in controlled test lock root '$LOCK_ROOT' (before=$INITIAL_LOCK_COUNT after=$FINAL_LOCK_COUNT)." >&2
    exit 1
  fi

  echo "PASS: flock and mkdir lock backends preserved concurrent writes, exclusivity, error propagation, and strict no lock growth ($WORKERS each)."
else
  run_parallel_writes "mkdir" "$WORKERS"
  assert_count "mkdir" "$WORKERS"
  assert_error_propagation "mkdir"

  cleanup_test_lock_file
  FINAL_LOCK_COUNT="$(lock_file_count)"
  if [ "$FINAL_LOCK_COUNT" -gt "$INITIAL_LOCK_COUNT" ]; then
    echo "FAIL: lock artifacts grew in controlled test lock root '$LOCK_ROOT' (before=$INITIAL_LOCK_COUNT after=$FINAL_LOCK_COUNT)." >&2
    exit 1
  fi

  echo "PASS: mkdir lock backend preserved concurrent writes, error propagation, and strict no lock growth ($WORKERS)."
fi
