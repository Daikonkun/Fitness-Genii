---
name: "start-work"
description: "Create a dedicated git worktree for a requirement and move it to IN_PROGRESS. Use when: beginning implementation for a tracked requirement."
argument-hint: "<REQ-ID> [base-branch]"
agent: "Vibe Agent Orchestrator"
---

Start implementation work for a requirement in an isolated git worktree.

Workflow:
1. Parse required `REQ-ID` and optional base branch (default `main`).
2. Run `scripts/start-work.sh` with those arguments.
3. Locate the requirement spec file in `docs/requirements/` for that `REQ-ID` and read its Description, Success Criteria, and Technical Notes.
4. Create or update a `## Development Plan` section in that spec file with 3-5 ordered, actionable steps tied to concrete repo files/scripts/commands.
5. Keep the plan idempotent: if `## Development Plan` already exists, update that section instead of adding a duplicate header.
6. Confirm the created worktree ID and filesystem path.
7. Confirm requirement status was updated to `IN_PROGRESS`.
8. In the final response (on successful completion), include: `Next recommended command: /work-on <REQ-ID>`.

Constraints:
- Never create multiple worktrees for the same requirement unless explicitly requested.
- If sibling-directory worktree creation fails in constrained environments, retry with `VIBE_WORKTREE_ROOT=.worktrees` (or another writable path) while preserving branch naming and manifest linkage.
- If the requirement already has an active worktree, report it and stop.
- Surface script failures exactly.
- If the requirement spec file cannot be found, report the missing spec and stop before claiming plan persistence.

**Superpowers Alignment** (REQ-1774685792): Compatible with `using-git-worktrees` skill. No changes to core logic or worktree-manager/SKILL.md.

**Auto-Compaction** (REQ-1776233067): If `{{compacted_summary}}` is present in the context, use it to restore essential state (active requirement IDs, current task) before continuing. Check `logs/compaction.log` for full details if needed.
