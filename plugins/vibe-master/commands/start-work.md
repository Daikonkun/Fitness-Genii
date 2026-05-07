---
description: Create requirement worktree and move requirement to IN_PROGRESS.
---

# /vibe-master:start-work

## Preflight

1. Validate `REQ-ID` and optional base branch.
2. Ensure `scripts/start-work.sh` exists.

## Plan

1. Run `scripts/start-work.sh <REQ-ID> [base-branch]`.
2. If sibling worktree placement fails in constrained envs, retry with `VIBE_WORKTREE_ROOT=.worktrees`.

## Commands

- Primary: `scripts/start-work.sh <REQ-ID> [base-branch]`
- Fallback: `VIBE_WORKTREE_ROOT=.worktrees scripts/start-work.sh <REQ-ID> [base-branch]`

## Verification

1. Requirement status is `IN_PROGRESS`.
2. Worktree entry exists in `.worktree-manifest.json` with `ACTIVE` status.

## Summary

Return worktree ID/path/base branch.

## Next Steps

Recommend `/vibe-master:work-on <REQ-ID>`.
