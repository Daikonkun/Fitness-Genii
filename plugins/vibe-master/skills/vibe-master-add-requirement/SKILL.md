---
name: vibe-master-add-requirement
description: Add a new Vibe Master requirement. Use when the user asks for /add-requirement, add requirement, create REQ, or capture new work.
---

# Vibe Master Add Requirement

Use this skill as the Codex-facing equivalent of `/add-requirement`.

## Workflow

1. Gather or infer a concise requirement title and description.
2. Run `scripts/create-requirement.sh "<title>" "<description>" [priority] --no-commit`.
3. Fill or refine the generated requirement file if placeholders remain.
4. Run `scripts/regenerate-docs.sh`.

## Report

Return the new `REQ-ID`, requirement file path, manifest update, and recommended next action.
