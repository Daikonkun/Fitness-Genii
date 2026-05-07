---
description: Run structured debugging workflow and produce root-cause-driven fixes or REQ escalation.
---

# /vibe-master:bug-fix

## Preflight

1. Confirm issue summary is provided.
2. Ensure `.github/skills/debug/SKILL.md` and `.github/prompts/bug-fix.prompt.md` exist.

## Plan

1. Run debug workflow phases: reproduce, root-cause, validate.
2. Apply minimal safe fix when feasible.
3. If fix requires net-new feature, create follow-up requirement.

## Commands

Follow `.github/prompts/bug-fix.prompt.md` and `.github/skills/debug/SKILL.md`.
Potential script calls include:
- `scripts/create-requirement.sh`
- `scripts/regenerate-docs.sh`

## Verification

1. Reproduction before fix is demonstrated.
2. Validation after fix is captured.
3. Escalated REQs are linked when unresolved.

## Summary

Return root cause, fix scope, validation result, and risk.

## Next Steps

Recommend `/vibe-master:work-on <REQ-ID>` for tracked follow-up implementation.
