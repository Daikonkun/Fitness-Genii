---
name: "worktree-prune"
description: "Remove orphaned or dead git worktrees and clean up manifests. Use when: housekeeping worktrees after merges or manual deletions."
argument-hint: "(no arguments)"
agent: "Vibe Agent Orchestrator"
---

Prune orphaned git worktrees and synchronize manifests.

Workflow:
1. Run `git worktree prune` to remove stale worktree references.
2. Read `.worktree-manifest.json` and identify entries whose paths no longer exist on disk.
3. Mark those manifest entries as `PRUNED` and set `prunedAt` timestamp.
4. Report which worktrees were pruned (path, branch, linked requirement IDs).
5. If no orphaned worktrees exist, report that result clearly.

Constraints:
- Do not remove worktrees that still exist on disk — only prune stale references.
- Do not change any requirement statuses; pruning is a filesystem/manifest cleanup only.
- Surface any git errors exactly.
