#!/bin/bash
# Regression check: start-work should not leave lock artifacts, and docs regen should be idempotent.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/_project-root.sh"
PROJECT_ROOT="$(vibe_resolve_project_root)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/start-work-clean-check.XXXXXX")"
CHECK_ROOT="$TMP_ROOT/check"

cleanup() {
  if [ -d "$CHECK_ROOT/.git" ]; then
    while IFS= read -r wt_path; do
      [ -z "$wt_path" ] && continue
      if [ "$wt_path" != "$CHECK_ROOT" ] && [[ "$wt_path" == "$TMP_ROOT"/* ]]; then
        git -C "$CHECK_ROOT" worktree remove "$wt_path" --force >/dev/null 2>&1 || true
      fi
    done < <(git -C "$CHECK_ROOT" worktree list --porcelain 2>/dev/null | awk '/^worktree / {print $2}')
  fi

  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

assert_no_lock_artifacts() {
  local repo_root="$1"
  local has_errors=0

  for lock_file in \
    "$repo_root/.requirement-manifest.json.lock" \
    "$repo_root/.worktree-manifest.json.lock"; do
    if [ -e "$lock_file" ]; then
      echo "FAIL: stale lock file found: $lock_file" >&2
      has_errors=1
    fi
  done

  while IFS= read -r lock_dir; do
    [ -z "$lock_dir" ] && continue
    echo "FAIL: stale lock directory found: $lock_dir" >&2
    has_errors=1
  done < <(find "$repo_root" -maxdepth 1 -type d -name '*.lock.d' -print)

  if [ "$has_errors" -ne 0 ]; then
    exit 1
  fi
}

mkdir -p "$CHECK_ROOT"
(
  cd "$PROJECT_ROOT"
  tar -cf - --exclude='.git' .
) | tar -xf - -C "$CHECK_ROOT"

git -C "$CHECK_ROOT" init -b main >/dev/null
git -C "$CHECK_ROOT" config user.email "start-work-clean-check@example.com"
git -C "$CHECK_ROOT" config user.name "Start Work Clean Check"
git -C "$CHECK_ROOT" add .
git -C "$CHECK_ROOT" commit -m "baseline snapshot" >/dev/null

cd "$CHECK_ROOT"

CANDIDATE_REQS=()
while IFS= read -r req_id; do
  [ -z "$req_id" ] && continue
  CANDIDATE_REQS+=("$req_id")
done < <(
  jq -r '.requirements[]
    | select((.status == "PROPOSED" or .status == "BACKLOG") and ((.worktreeId // "") == ""))
    | .id' .requirement-manifest.json
)

if [ "${#CANDIDATE_REQS[@]}" -lt 3 ]; then
  for idx in 1 2 3; do
    req_id="REQ-177888888800$idx"
    if jq -e --arg reqId "$req_id" '.requirements[]? | select(.id == $reqId)' .requirement-manifest.json >/dev/null; then
      continue
    fi

    tmp_file="$(mktemp .requirement-manifest.json.XXXXXX)"
    jq --arg reqId "$req_id" --arg name "start-work clean fixture $idx" '
      .requirements += [{
        "id": $reqId,
        "name": $name,
        "description": "Fixture requirement for start-work regression checks.",
        "status": "PROPOSED",
        "priority": "MEDIUM",
        "createdAt": "2026-01-01T00:00:00Z",
        "updatedAt": "2026-01-01T00:00:00Z"
      }]
    ' .requirement-manifest.json > "$tmp_file"
    mv "$tmp_file" .requirement-manifest.json

    cat > "docs/requirements/${req_id}-start-work-clean-fixture-${idx}.md" << EOF
# start-work clean fixture $idx

**ID**: $req_id
**Status**: PROPOSED
**Priority**: MEDIUM
**Created**: 2026-01-01T00:00:00Z

## Description

Fixture requirement for start-work regression checks.

## Success Criteria

- [ ] start-work can consume this fixture.

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
  done

  CANDIDATE_REQS=()
  while IFS= read -r req_id; do
    [ -z "$req_id" ] && continue
    CANDIDATE_REQS+=("$req_id")
  done < <(
    jq -r '.requirements[]
      | select((.status == "PROPOSED" or .status == "BACKLOG") and ((.worktreeId // "") == ""))
      | .id' .requirement-manifest.json
  )
fi

if [ "${#CANDIDATE_REQS[@]}" -lt 3 ]; then
  echo "FAIL: expected at least three PROPOSED/BACKLOG requirements without worktrees for regression check." >&2
  exit 1
fi

SUCCESS_REQ="${CANDIDATE_REQS[0]}"
FAIL_REQ="${CANDIDATE_REQS[1]}"
RACE_REQ="${CANDIDATE_REQS[2]}"

# 1) No-op regenerate-docs should not change generated outputs after baseline generation.
bash scripts/regenerate-docs.sh >/dev/null
git add REQUIREMENTS.md docs/STATUS.md docs/ROADMAP.md docs/DEPENDENCIES.md docs/requirements/ .requirement-manifest.json .worktree-manifest.json
git commit -m "baseline generated docs" >/dev/null || true

bash scripts/regenerate-docs.sh >/dev/null
if ! git diff --quiet -- REQUIREMENTS.md docs/STATUS.md docs/ROADMAP.md docs/DEPENDENCIES.md docs/requirements; then
  echo "FAIL: regenerate-docs produced generated-doc diffs without manifest changes." >&2
  git --no-pager diff -- REQUIREMENTS.md docs/STATUS.md docs/ROADMAP.md docs/DEPENDENCIES.md docs/requirements >&2
  exit 1
fi

# 2) start-work success path should not leave lock artifacts.
bash scripts/start-work.sh "$SUCCESS_REQ" >/dev/null
assert_no_lock_artifacts "$CHECK_ROOT"

# 3) Parallel start-work race check should use a requirement not consumed by prior steps.
set +e
bash scripts/start-work.sh "$RACE_REQ" >/dev/null 2>&1 &
RACE_PID_1=$!
bash scripts/start-work.sh "$RACE_REQ" >/dev/null 2>&1 &
RACE_PID_2=$!

wait "$RACE_PID_1"
RACE_STATUS_1=$?
wait "$RACE_PID_2"
RACE_STATUS_2=$?
set -e

RACE_SUCCESS_COUNT=0
[ "$RACE_STATUS_1" -eq 0 ] && RACE_SUCCESS_COUNT=$((RACE_SUCCESS_COUNT + 1))
[ "$RACE_STATUS_2" -eq 0 ] && RACE_SUCCESS_COUNT=$((RACE_SUCCESS_COUNT + 1))

if [ "$RACE_SUCCESS_COUNT" -ne 1 ]; then
  echo "FAIL: expected exactly one successful start-work in race check for $RACE_REQ (got statuses: $RACE_STATUS_1, $RACE_STATUS_2)." >&2
  exit 1
fi

assert_no_lock_artifacts "$CHECK_ROOT"

# 4) start-work failure after lock acquisition should still clean lock artifacts.
cp .worktree-manifest.json .worktree-manifest.json.bak
printf '{\n' > .worktree-manifest.json

set +e
FAIL_OUTPUT="$(bash scripts/start-work.sh "$FAIL_REQ" 2>&1)"
FAIL_STATUS=$?
set -e

mv .worktree-manifest.json.bak .worktree-manifest.json

if [ "$FAIL_STATUS" -eq 0 ]; then
  echo "FAIL: expected induced start-work failure, but command succeeded." >&2
  exit 1
fi

if ! grep -Eq 'parse error|Error:' <<< "$FAIL_OUTPUT"; then
  echo "FAIL: induced start-work failure did not surface expected script error output." >&2
  echo "$FAIL_OUTPUT" >&2
  exit 1
fi

assert_no_lock_artifacts "$CHECK_ROOT"

# 5) Locks should be acquirable immediately after failed start-work without manual cleanup.
source scripts/_manifest-lock.sh
with_manifest_lock .requirement-manifest.json true
with_manifest_lock .worktree-manifest.json true
assert_no_lock_artifacts "$CHECK_ROOT"

echo "PASS: start-work lock cleanup and regenerate-docs idempotence checks passed."
