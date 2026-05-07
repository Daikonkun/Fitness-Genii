---
description: Run requirement-aware code review workflow and create follow-up REQs when needed.
---

# /vibe-master:code-review

## Preflight

1. Confirm `.github/skills/code-review/SKILL.md` exists.
2. Confirm `.github/prompts/code-review.prompt.md` exists.

## Plan

1. Set Codex metadata (`VIBE_CALLER=codex`, `VIBE_AUTO_MODE=1`).
2. Run the `/code-review` workflow using the `code-review` skill contract.
3. If follow-up REQs are created, run docs regeneration.

## Commands

Follow `.github/prompts/code-review.prompt.md` and `.github/skills/code-review/SKILL.md`.
Use:
- `scripts/create-requirement.sh ...` for unresolved findings
- `scripts/regenerate-docs.sh` when new REQs are created

## Verification

1. Findings are evidence-based and severity ordered.
2. Any generated REQ IDs exist in `.requirement-manifest.json`.

## Summary

Return findings, open questions, and follow-up REQ links.

## Next Steps

Recommend `/vibe-master:start-work <new-REQ-ID>` for newly created high-priority follow-ups.
