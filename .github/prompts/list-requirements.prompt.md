---
name: "list-requirements"
description: "List requirements from the manifest with optional status filter. Use when: reviewing requirement queues by lifecycle state."
argument-hint: "[PROPOSED|IN_PROGRESS|CODE_REVIEW|MERGED|DEPLOYED|BLOCKED|BACKLOG|CANCELLED]"
agent: "Vibe Agent Orchestrator"
---

List requirements from the current workspace manifest.

Workflow:
1. Parse optional status argument.
2. Run scripts/list-requirements.sh with the status filter when provided.
3. Return the list and a short summary count.

Constraints:
- Use exact script output for IDs and statuses.
- If status is invalid, return the script error and stop.
