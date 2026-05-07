---
name: "update-requirement"
description: "Update a requirement lifecycle status with transition validation. Use when: moving a requirement through PROPOSED, IN_PROGRESS, CODE_REVIEW, MERGED, DEPLOYED, BLOCKED, BACKLOG, or CANCELLED."
argument-hint: "<REQ-ID> <NEW-STATUS> [--force] [--no-refresh]"
agent: "Vibe Agent Orchestrator"
---

Update a requirement status using the dedicated lifecycle validator.

Workflow:
1. Parse required `REQ-ID` and `NEW-STATUS`, plus optional flags `--force` and `--no-refresh`.
2. Run `scripts/update-requirement-status.sh` with the provided arguments.
3. Return the transition result (from -> to) and whether docs were regenerated.
4. If successful, confirm where to verify output: `REQUIREMENTS.md` and `docs/STATUS.md`.

Constraints:
- If required arguments are missing, ask for: `/update-requirement REQ-<digits> <status>`.
- If the script rejects the transition, surface the exact allowed transitions from script output.
- Do not bypass validation unless the user explicitly includes `--force`.
