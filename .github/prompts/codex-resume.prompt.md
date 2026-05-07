---
name: "codex-resume"
description: "Hydrate Codex session context for an existing Vibe Master project and recommend the next command. Use when: resuming work in Codex on a previously tracked requirement/worktree."
argument-hint: "[REQ-ID|--auto-detect]"
agent: "Vibe Agent Orchestrator"
---

Resume a Vibe Master project session in Codex without changing lifecycle semantics.

Workflow:
1. Parse optional argument:
   - `REQ-ID` to resume a specific requirement.
   - `--auto-detect` (or no argument) to infer from current context.
2. Set Codex orchestration metadata before running follow-up workflows:
   - `VIBE_CALLER=codex`
   - `VIBE_AUTO_MODE=1`
3. Run `scripts/codex-resume.sh`:
   - `scripts/codex-resume.sh --req-id <REQ-ID> --json` when explicit REQ is provided.
   - `scripts/codex-resume.sh --auto-detect --json` otherwise.
4. Parse the JSON snapshot and return:
   - selected requirement (if any),
   - linked active worktree (if any),
   - next recommended slash command.
5. For Codex convenience, prefer wrapper recommendations when applicable:
   - use `/codex-work-on <REQ-ID>` instead of `/work-on <REQ-ID>`.
   - use `/codex-code-review [scope]` instead of `/code-review [scope]`.
6. If no requirement can be inferred, direct the user to run `/status` or `/list-requirements` and then `/codex-resume <REQ-ID>`.

Constraints:
- Do not mutate manifests or requirement statuses in this command.
- Surface script failures exactly and stop.
- Keep command recommendations aligned with existing slash commands (`/start-work`, `/work-on`, `/status`, `/update-requirement`, `/add-requirement`).
- Preserve compatibility-first behavior; do not rename existing workflow commands.
