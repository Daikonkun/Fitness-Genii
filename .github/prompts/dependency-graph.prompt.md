---
name: "dependency-graph"
description: "Regenerate docs and show requirement dependency graph. Use when: checking requirement relationships and blockers."
argument-hint: "(no arguments)"
agent: "Vibe Agent Orchestrator"
---

Show the latest requirement dependency graph.

Workflow:
1. Run scripts/dependency-graph.sh.
2. Return the graph output and mention the source file docs/DEPENDENCIES.md.

Constraints:
- If regeneration fails, return the exact script error.
- Do not fabricate missing dependencies.
