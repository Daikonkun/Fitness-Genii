---
name: vibe-master-start-work
description: Start work on a Vibe Master requirement and create/link its worktree. Use when the user asks for /start-work, start work, or create a requirement worktree.
---

# Vibe Master Start Work

Use this skill as the Codex-facing equivalent of `/start-work <REQ-ID>`.

## Workflow

1. Validate the argument looks like `REQ-<digits>`.
2. Run `scripts/start-work.sh <REQ-ID> [base-branch]`.
3. If sibling worktree creation fails in a constrained environment, retry with `VIBE_WORKTREE_ROOT=.worktrees`.
4. Preserve manifest schema and branch naming rules.

## Report

Return the requirement status, worktree ID/path, branch, and next recommended command.
