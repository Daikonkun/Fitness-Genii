---
name: vibe-master-e2e-test
description: Run Vibe Master end-to-end validation for a requirement or active worktree. Use when the user asks for /e2e-test, e2e test, end-to-end test, or lifecycle verification.
---

# Vibe Master E2E Test

Use this skill as the Codex-facing equivalent of `/e2e-test`.

## Workflow

1. Identify the active requirement/worktree from manifests or the provided `REQ-ID`.
2. Follow `.github/prompts/e2e-test.prompt.md` when present.
3. Run the smallest documented end-to-end test command first.
4. Preserve lifecycle safety: failures should not advance status.

## Report

Return exact commands run, pass/fail status, key logs, and next remediation step.
