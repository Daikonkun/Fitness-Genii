---
description: Run Vibe Master requirement implementation workflow in Codex-trusted auto mode.
---

# /vibe-master:work-on

## Preflight

1. Validate required `REQ-ID` argument format `REQ-<digits>`.
2. Ensure `.requirement-manifest.json` exists.
3. Ensure `.github/prompts/work-on.prompt.md` exists to preserve workflow contract.

## Plan

1. Set `VIBE_CALLER=codex` and `VIBE_AUTO_MODE=1`.
2. Execute the existing `/work-on` workflow contract from `.github/prompts/work-on.prompt.md`.
3. Preserve lifecycle/no-op guards exactly as documented.

## Commands

No dedicated shell wrapper exists for `/work-on` by design.
Execute the prompt workflow semantics from `.github/prompts/work-on.prompt.md` with the provided arguments.

## Verification

1. Verify requirement status transition only occurs through `scripts/update-requirement-status.sh`.
2. Verify docs regeneration occurs when status changes.

## Summary

Report:
- requirement ID
- status before/after
- key implementation evidence checks outcome

## Next Steps

Recommend `/vibe-master:code-review <REQ-ID>` after successful advance to `CODE_REVIEW`.
