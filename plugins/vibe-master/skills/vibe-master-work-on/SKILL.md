---
name: vibe-master-work-on
description: Run Vibe Master requirement implementation in Codex auto mode. Use when the user asks for /work-on, work-on, implement a REQ, continue a requirement, or advance active work.
---

# Vibe Master Work On

Use this skill as the Codex-facing equivalent of `/work-on <REQ-ID>`.

## Workflow

1. Validate the argument looks like `REQ-<digits>`.
2. Export `VIBE_CALLER=codex` and `VIBE_AUTO_MODE=1` for shell commands that participate in orchestration.
3. Follow `.github/prompts/work-on.prompt.md` as the source of truth.
4. Preserve existing no-op, lifecycle, docs regeneration, and status-transition guards.
5. Use `scripts/update-requirement-status.sh` for status changes; do not edit manifests directly.

## Report

Return the requirement ID, status before and after, files changed, and verification evidence.
