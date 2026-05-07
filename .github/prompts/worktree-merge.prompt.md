---
name: "worktree-merge"
description: "Merge a feature branch into base branch, clean up worktree, and update manifests. Use when: completing a requirement branch."
argument-hint: "<branch|REQ-ID> [base-branch] [--auto-resolve-conflicts]"
agent: "Vibe Agent Orchestrator"
---

Merge and clean up a completed worktree branch.

Workflow:
1. Parse required branch-or-requirement-id and optional base branch (default main).
2. Run scripts/worktree-merge.sh with the parsed arguments.
3. Report merge outcome, removed worktree path, and updated requirement IDs.
4. On successful completion, include a concise next-command recommendation aligned to lifecycle using this format: `Next recommended command: ...`.
	- If deployment is still required, use: `Next recommended command: /work-on <REQ-ID> DEPLOYED`.
	- Otherwise, use: `Next recommended command: /status`.

Constraints:
- This operation changes git history and manifests; do not run if arguments are missing.
- Accept either a branch (e.g. `feature/REQ-...`) or requirement ID (e.g. `REQ-...`) as the first parameter.
- Hint: if generated docs/manifests/spec conflicts are expected, users can pass `--auto-resolve-conflicts`.
- If a requirement ID is provided but does not exist in `.requirement-manifest.json`, stop and surface the exact script error.
- If a requirement ID exists but has no ACTIVE mapping in `.worktree-manifest.json`, stop and surface the exact script error.
- The script enforces a strict clean working tree. If dirty, stop and report the exact script error; recommend `git status --short`, then commit/stash/discard local changes before retrying `/worktree-merge`.
- Surface script failures exactly.
- Emit the next-command recommendation only on successful completion paths; do not emit it on failures/stops.
