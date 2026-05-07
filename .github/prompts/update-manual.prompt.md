---
name: "update-manual"
description: "Wrapper for the manual update skill workflow. Use when: syncing README/manual docs with current command and feature behavior."
argument-hint: "[scope]"
agent: "Vibe Agent Orchestrator"
---

Run the manual update workflow for the selected scope.

Workflow:
1. Parse optional scope.
2. Load and follow the `update-manual` skill workflow.
3. Detect documentation drift, update impacted docs, and validate command/file references.
4. Return a concise summary of changed docs and user-visible updates.

Constraints:
- Keep command names and workflow states exact.
- Prefer minimal, behavior-accurate documentation edits.
- Include manual-audit and manual-changelog sections when relevant.
