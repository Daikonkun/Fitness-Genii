---
name: "show-requirement"
description: "Display complete requirement details and linked spec file for a given requirement ID. Use when: inspecting a requirement before planning or coding."
argument-hint: "<REQ-ID>"
agent: "Vibe Agent Orchestrator"
---

Display a requirement with all known metadata and specification content.

Workflow:
1. Parse one required argument: requirement ID like `REQ-1774630000`.
2. Run `scripts/show-requirement.sh` with that requirement ID.
3. Summarize status, priority, worktree, and last updated timestamp.
4. If the spec contains a `## Development Plan` section, surface the first pending step (or "Plan is up to date") as the recommended restart point.
5. Include the spec file path when present.

Constraints:
- If the requirement ID is missing or invalid, ask for a valid `REQ-<digits>` value.
- If the requirement does not exist, return the script output and stop.
