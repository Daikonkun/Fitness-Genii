---
description: Resume Vibe Master context in Codex and recommend the next lifecycle command.
---

# /vibe-master:resume

## Preflight

1. Ensure repository root contains `.requirement-manifest.json` and `.worktree-manifest.json`.
2. Ensure `scripts/codex-resume.sh` exists and is executable.

## Plan

1. Bootstrap Codex caller metadata (`VIBE_CALLER=codex`, `VIBE_AUTO_MODE=1`).
2. Run `scripts/codex-resume.sh --auto-detect --json` (or use provided REQ ID via `--req-id`).
3. Summarize selected requirement, linked worktree, and next command.

## Commands

- Auto-detect:
  - `VIBE_CALLER=codex VIBE_AUTO_MODE=1 scripts/codex-resume.sh --auto-detect --json`
- Explicit requirement:
  - `VIBE_CALLER=codex VIBE_AUTO_MODE=1 scripts/codex-resume.sh --req-id <REQ-ID> --json`

## Verification

1. Confirm JSON output parses via `jq`.
2. Confirm `nextRecommendedCommand` exists in output.

## Summary

Return:
- canonical root
- selected requirement/worktree (if any)
- `nextRecommendedCommand`

## Next Steps

- If requirement is selected: recommend `/vibe-master:work-on <REQ-ID>`.
- If none selected: recommend `/vibe-master:add-requirement` or `/status`.
