---
name: "add-requirement"
description: "Create a new product requirement, regenerate requirement docs, and suggest the next worktree step. Use when: submitting a new requirement via slash command."
argument-hint: "\"Feature name\" \"Detailed description\" [CRITICAL|HIGH|MEDIUM|LOW]"
agent: "Vibe Agent Orchestrator"
---

Create a new requirement in the current workspace.

Workflow:
1. Parse the arguments as `name`, `description`, and optional `priority` with a default of `MEDIUM`.
2. Validate that `name` and `description` are present and that `priority` is one of `CRITICAL`, `HIGH`, `MEDIUM`, or `LOW`.
3. Run [create-requirement.sh](../../scripts/create-requirement.sh) with the parsed arguments and `--no-commit`.
4. Read the generated spec file and enrich placeholder sections:
   - **Success Criteria**: Replace the placeholder items (`Criterion 1/2/3`) with 3–5 testable acceptance criteria derived from the description.
   - **Technical Notes**: Analyze the description and write implementation considerations — approach, affected areas, and risks.
   - **Dependencies**: Scan the description for references to other requirement IDs (e.g., `REQ-XXXXXXXXXX`). List any found; otherwise write "None".
   - **Worktree**: Leave as-is (populated later by `/start-work`).
   - Update the requirement's `notes` field in `.requirement-manifest.json` with a one-line technical summary.
5. Run [regenerate-docs.sh](../../scripts/regenerate-docs.sh) so [REQUIREMENTS.md](../../REQUIREMENTS.md) and the docs remain in sync.
6. Perform a single atomic commit after enrichment and docs regeneration:
   - `git add .requirement-manifest.json docs/requirements/ REQUIREMENTS.md docs/STATUS.md docs/ROADMAP.md docs/DEPENDENCIES.md`
   - `git commit -m "chore: create requirement <REQ-ID>" --no-verify`
7. Summarize the created requirement ID, the generated spec path, and the next recommended step.

Constraints:
- Do not invent a requirement ID; use the script output.
- If validation fails, explain what argument is missing or invalid.
- If a script fails, surface the exact failure and stop.
- If the final commit step fails, surface the exact failure and stop.
- Keep the final response concise and action-oriented.
- Success criteria must be specific and testable, not generic placeholders.
- Technical notes must reference concrete files, modules, or patterns when possible.

**Superpowers Alignment** (REQ-1774685792): Compatible with `writing-plans` and `brainstorming` for the enrichment step (step 4). Keep workflow unchanged.