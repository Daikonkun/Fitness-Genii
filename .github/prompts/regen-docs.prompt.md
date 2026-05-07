---
name: "regen-docs"
description: "Force regeneration of requirement documentation artifacts. Use when: manifests changed and docs need synchronization."
argument-hint: "(no arguments)"
agent: "Vibe Agent Orchestrator"
---

Regenerate all requirement documentation files.

Workflow:
1. Run scripts/regenerate-docs.sh.
2. Confirm generated artifacts were updated.
3. Provide a concise success summary.

Constraints:
- Return exact script failures if regeneration does not complete.
- Do not claim generated files unless script confirms success.
