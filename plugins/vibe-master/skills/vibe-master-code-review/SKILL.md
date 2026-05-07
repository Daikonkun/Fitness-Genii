---
name: vibe-master-code-review
description: Run requirement-aware Vibe Master code review. Use when the user asks for /code-review, code-review, review a REQ, or create follow-up requirements from findings.
---

# Vibe Master Code Review

Use this skill as the Codex-facing equivalent of `/code-review <REQ-ID>`.

## Workflow

1. Validate the target `REQ-ID` when provided.
2. Read `.github/prompts/code-review.prompt.md` and `.github/skills/code-review/SKILL.md`.
3. Prioritize evidence-backed findings, ordered by severity, with file/line references.
4. If follow-up requirements are needed, create them with `scripts/create-requirement.sh`.
5. Run `scripts/regenerate-docs.sh` after creating requirements.

## Report

Findings come first. Then include open questions, follow-up REQ IDs, and residual test gaps.
