---
name: "worktree-create"
description: "Manually create a git worktree for a requirement without changing its status. Use when: setting up an isolated workspace for a requirement before starting implementation."
argument-hint: "<REQ-ID> [base-branch]"
agent: "Vibe Agent Orchestrator"
---

Create a git worktree for a requirement without transitioning its status.

Workflow:
1. Parse required `REQ-ID` and optional base branch (default `main`).
2. Look up the requirement name from `.requirement-manifest.json`.
3. Generate the branch name: `feature/{REQ-ID}-{slug}`.
4. Run `git worktree add` with the generated branch name and base branch.
5. Register the worktree in `.worktree-manifest.json` with status `ACTIVE` and link the `REQ-ID`.
6. Update the requirement's `worktreeId` field in `.requirement-manifest.json` (do NOT change its status).
7. Report the created worktree path, branch name, and linked requirement.

Constraints:
- If the requirement already has an active worktree, report it and stop.
- If the worktree path already exists on disk, report the conflict and stop.
- Do not change the requirement's lifecycle status — use `/start-work` for that.
- Surface any git errors exactly.

Note: Prefer `/start-work <REQ-ID>` to create a worktree AND move the requirement to IN_PROGRESS in one step.
