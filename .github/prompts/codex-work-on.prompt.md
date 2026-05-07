---
name: "codex-work-on"
description: "Codex-friendly wrapper for /work-on with trusted auto-mode metadata. Use when: resuming implementation flow in Codex with minimal friction."
argument-hint: "<REQ-ID> [target-status] [--no-auto] [--no-diff-reason \"reason\"]"
agent: "Vibe Agent Orchestrator"
---

Run `/work-on` from Codex with the expected caller metadata already set.

Workflow:
1. Parse required `REQ-ID`, optional `target-status`, optional `--no-auto`, and optional `--no-diff-reason "reason"`.
2. Set caller metadata:
   - `VIBE_CALLER=codex`
   - `VIBE_AUTO_MODE=1`
3. Invoke `/work-on` with the same parsed arguments.
4. Return the `/work-on` result unchanged, including failures and next recommended command.

Constraints:
- Do not bypass `/work-on` lifecycle checks, no-op guards, or worktree checks.
- If `/work-on` fails, surface the exact failure and stop.
- Keep behavior identical to `/work-on` except for Codex caller metadata bootstrap.
