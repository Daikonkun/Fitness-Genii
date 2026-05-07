---
name: vibe-master-worktree-merge
description: Merge a Vibe Master requirement worktree back to the canonical branch. Use when the user asks for /worktree-merge, merge worktree, or finish requirement work.
---

# Vibe Master Worktree Merge

Use this skill as the Codex-facing equivalent of `/worktree-merge <REQ-ID>`.

## Workflow

1. Validate the target requirement and active worktree from `.worktree-manifest.json`.
2. Follow `.github/prompts/worktree-merge.prompt.md` when present.
3. Run the repository merge script if available; otherwise perform only the documented safe merge steps.
4. Preserve lifecycle status rules and do not bypass review/test gates.

## Report

Summarize merge target, commits merged, manifest updates, and any manual follow-up.
