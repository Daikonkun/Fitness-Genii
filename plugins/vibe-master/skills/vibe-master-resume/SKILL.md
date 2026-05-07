---
name: vibe-master-resume
description: Resume an existing Vibe Master project in Codex. Use when the user asks to resume, hydrate, detect active requirement/worktree state, or run /codex-resume.
---

# Vibe Master Resume

Use this skill as the Codex-facing equivalent of `/codex-resume`.

## Workflow

1. Run `scripts/codex-resume.sh --json` by default.
2. If the user provides a requirement ID, run `scripts/codex-resume.sh --req-id <REQ-ID> --json`.
3. Treat the JSON snapshot as authoritative for active requirement, status, worktree linkage, and next command.
4. Set `VIBE_CALLER=codex` and `VIBE_AUTO_MODE=1` for any follow-on orchestrated command.

## Report

Summarize the active `REQ-ID`, current status, linked worktree path if any, and the recommended next Vibe Master action.
