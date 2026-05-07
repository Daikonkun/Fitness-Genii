---
name: "rollback"
description: "Roll back a merged or deployed requirement by reverting its merge commit and restoring manifests. Use when: undoing a completed requirement merge."
argument-hint: "<REQ-ID> [base-branch]"
agent: "Vibe Agent Orchestrator"
---

Roll back a merged requirement to restore the project to its pre-merge state.

Workflow:
1. Parse required `REQ-ID` and optional base branch (default `main`).
2. Validate that the requirement exists and is in `MERGED` or `DEPLOYED` status.
3. Run `scripts/rollback-requirement.sh` with the parsed arguments.
4. Report the reverted merge commit, restored branch/worktree, and updated status.

Constraints:
- Only requirements in MERGED or DEPLOYED status can be rolled back.
- The script will refuse to revert if newer merge commits exist after the target merge (safety check).
- This operation changes git history and manifests; do not run if arguments are missing.
- Surface script failures exactly.
