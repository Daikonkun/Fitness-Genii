---
name: "worktree-list"
description: "List active git worktrees and linked requirement IDs. Use when: checking active parallel development branches."
argument-hint: "(no arguments)"
agent: "Vibe Agent Orchestrator"
---

Show active worktree mappings.

Workflow:
1. Run scripts/worktree-list.sh.
2. Return active worktree IDs, paths, base branches, and linked requirement IDs.
3. Include a concise active count summary.

Constraints:
- If no active worktrees exist, return that result clearly.
- Do not infer mappings; use manifest-backed output.
