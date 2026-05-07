---
name: "roadmap"
description: "Regenerate docs and display roadmap grouped by priority and status. Use when: reviewing delivery sequencing."
argument-hint: "(no arguments)"
agent: "Vibe Agent Orchestrator"
---

Show the latest roadmap for requirements.

Workflow:
1. Run scripts/roadmap.sh.
2. Return the roadmap output and mention the source file docs/ROADMAP.md.

Constraints:
- If regeneration fails, return the exact script error.
- Preserve the roadmap ordering from script output.
