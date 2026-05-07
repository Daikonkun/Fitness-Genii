---
name: "bug-fix"
description: "Wrapper for the debug skill workflow. Use when: reproducing issues, finding root cause, validating fixes, and producing a debug report."
argument-hint: "\"issue summary\" [scope]"
agent: "Vibe Agent Orchestrator"
---

Run the structured debugging workflow for the provided issue.

Workflow:
1. Parse issue summary and optional scope.
2. Load and follow the `debug` skill workflow phases: `repro`, `root-cause`, `validate`.
3. Reproduce before editing, gather evidence, and apply minimal safe fixes when requested.
4. Return a final debug report using the skill evidence template.

Constraints:
- Do not skip reproduction unless explicitly instructed.
- If unresolved, report blockers and next probes.
- Keep requirement tracking in sync when creating or updating bug-fix requirements.
