---
name: "worktree-status"
description: "Show comprehensive worktree status dashboard including linked requirements and potential conflicts. Use when: reviewing parallel development state before creating or merging worktrees."
argument-hint: "(no arguments)"
agent: "Vibe Agent Orchestrator"
---

Display a comprehensive worktree status dashboard.

Workflow:
1. Run `git worktree list` to get current filesystem state.
2. Read `.worktree-manifest.json` for manifest-tracked worktrees.
3. Cross-reference filesystem worktrees with manifest entries; flag any mismatches.
4. For each active worktree, show: branch name, linked requirement IDs, base branch, creation date, and current git status (clean/dirty).
5. Summarize: total active, total merged/pruned, any orphaned entries.

Constraints:
- Do not modify any files; this is a read-only status command.
- If no worktrees exist beyond the main working tree, report that clearly.
- Use manifest-backed data; do not infer requirement links.
