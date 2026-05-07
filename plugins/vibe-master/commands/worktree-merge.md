---
description: Merge a requirement worktree branch and reconcile lifecycle docs.
---

# /vibe-master:worktree-merge

## Preflight

1. Validate merge target argument (`branch` or `REQ-ID`).
2. Ensure working tree is clean if command contract requires it.
3. Ensure `scripts/worktree-merge.sh` exists.

## Plan

1. Run `scripts/worktree-merge.sh <branch|REQ-ID> [base-branch] [--auto-resolve-conflicts]`.
2. Preserve manifest/doc regeneration behavior from script.

## Commands

- `scripts/worktree-merge.sh <branch|REQ-ID> [base-branch] [--auto-resolve-conflicts]`

## Verification

1. Merge commit exists or branch fast-forward completed.
2. Worktree entry is cleaned up/updated in `.worktree-manifest.json`.
3. Requirement status reflects merge lifecycle.

## Summary

Return merge outcome and cleaned worktree details.

## Next Steps

Recommend `/status` and deployment follow-up if required.
