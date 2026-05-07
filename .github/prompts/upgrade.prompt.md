---
name: "upgrade"
description: "Safely upgrade Vibe Master workflow files from the latest GitHub template using an isolated worktree."
argument-hint: "[--template-repo <github-url>] [--base-branch <branch>] [--apply]"
agent: "Vibe Agent Orchestrator"
---

Upgrade Vibe Master safely without touching the currently edited project tree.

Workflow:
1. Parse optional arguments:
   - `--template-repo <github-url>`: template source repo (defaults to `VIBE_MASTER_TEMPLATE_REPO`, then GitHub `origin`, then built-in Vibe Master template fallback)
   - `--base-branch <branch>`: base branch for upgrade worktree (default: `main`)
   - `--apply`: apply template files after preview diff (requires explicit confirmation)
2. Run `scripts/upgrade.sh --command-name upgrade` with parsed arguments.
3. Surface script output, including:
   - command conflict check results,
   - created/reused upgrade worktree path,
   - generated diff preview file path.
4. If `--apply` was not passed, recommend rerunning `/upgrade --apply` after reviewing the diff.
5. If `--apply` completed, recommend post-upgrade validation:
   - `jq . .requirement-manifest.json >/dev/null`
   - `jq . .worktree-manifest.json >/dev/null`
   - `bash scripts/regenerate-docs.sh`
   - `bash scripts/check-upgrade-manifest-history.sh`

Constraints:
- Never write upgrade changes directly into the currently edited project tree.
- Preflight slash-command conflict checks must run before any upgrade file operations.
- If a conflict is detected, stop and return the rename recommendation from the script.
- Always show or reference the generated diff preview before any apply step.
- Surface script failures exactly and stop.

**Superpowers Alignment** (REQ-1774685792): Compatible with `using-git-worktrees` for isolated upgrade execution.