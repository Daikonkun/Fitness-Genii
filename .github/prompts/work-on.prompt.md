---
name: "work-on"
description: "Work on a specific requirement until it reaches its next status. Use when: iteratively implementing a requirement and advancing it through the lifecycle."
argument-hint: "<REQ-ID> [target-status] [--auto|--no-auto] [--no-diff-reason \"reason\"]"
agent: "Vibe Agent Orchestrator"
---

Work on a requirement by implementing its spec until the next lifecycle status is reached.

Workflow:
1. Parse required `REQ-ID`, optional `target-status`, optional `--auto` / `--no-auto`, and optional `--no-diff-reason "<reason>"` from arguments. Validate format (`REQ-<digits>`). If `target-status` is provided, validate it is a known status.
   - Determine caller trust first (for example by verifying the prompt `agent:` is `Vibe Agent Orchestrator`, or by validating Codex caller metadata `VIBE_CALLER=codex` and `VIBE_AUTO_MODE=1`).
   - If both `--auto` and `--no-auto` are passed, report an argument conflict and stop.
   - Trusted orchestrator callers default to auto mode even when `--auto` is omitted; `--no-auto` explicitly opts back into interactive confirmation.
   - Untrusted callers must use interactive confirmation. If an untrusted caller passes `--auto`, report an authorization error and stop.
   - If `--no-diff-reason` is provided, require a non-empty reason string.
2. Read `.requirement-manifest.json` and look up the requirement's current status.
3. **Determine the next status** using the lifecycle transition map (or use the explicit `target-status` if provided):
   - PROPOSED → IN_PROGRESS, BACKLOG, CANCELLED
   - IN_PROGRESS → CODE_REVIEW, BLOCKED, BACKLOG, CANCELLED
   - CODE_REVIEW → MERGED, BLOCKED, CANCELLED
   - MERGED → DEPLOYED, CANCELLED *(DEPLOYED only when `requiresDeployment` is `true` or unset in the manifest — default behavior)*
   - DEPLOYED → CANCELLED
   - BLOCKED → IN_PROGRESS, BACKLOG, CANCELLED
   - BACKLOG → PROPOSED, IN_PROGRESS, CANCELLED
   - CANCELLED → terminal
   If the current status is DEPLOYED or CANCELLED, report that the requirement is in a terminal state and stop.
   If the current status is MERGED **and** the requirement's `requiresDeployment` flag is `false` in `.requirement-manifest.json`, treat MERGED as a terminal state (no further transition) and stop.
4. **Check worktree using canonical manifests**: Resolve the canonical tracker root independently of the current worktree (`git rev-parse --git-common-dir` then `dirname`) and read `<canonical-root>/.worktree-manifest.json` to verify the requirement has an active worktree.
   - If the requirement is PROPOSED (or BACKLOG) and has no worktree, perform a race-safe bootstrap:
     - Re-read `.requirement-manifest.json` and `.worktree-manifest.json` immediately before invoking `/start-work`.
     - If a worktree now exists for the requirement, skip `/start-work` and continue from step 5.
     - Otherwise, **auto-invoke `/start-work <REQ-ID>`** to create the worktree and advance to IN_PROGRESS.
     - If `/start-work` fails with an already-exists style error (for example existing worktree/branch/path), re-read both manifests and continue from step 5 if an active worktree is now present; if none is found, surface the script failure exactly and stop.
   - If the requirement is in any other status and has no worktree, tell the user to run `/start-work <REQ-ID>` first and stop.
5. **Load the spec**: Find the requirement spec file in `docs/requirements/` matching the `REQ-ID`. Read Description, Success Criteria, Technical Notes, and Development Plan.
6. **Iterate on implementation**:
   - Follow the Development Plan steps in order.
   - For each step, implement the required changes in the worktree.
   - After each step, check the Success Criteria — mark items done as they are satisfied.
   - Continue until all Success Criteria are met or the user intervenes.
7. **Enforce no-op evidence guard before status advancement**:
   - Resolve the requirement's active worktree from `<canonical-root>/.worktree-manifest.json` and read its `path` and `baseBranch` (default `main` if `baseBranch` is missing).
   - If canonical mapping is unavailable or stale, fall back by matching the current repository identity (`git rev-parse --show-toplevel`) and checked-out branch (`git rev-parse --abbrev-ref HEAD`) against entries loaded from `<canonical-root>/.worktree-manifest.json`.
   - If both canonical and fallback resolution fail, stop with a clear diagnostic and include actionable recovery commands: `./scripts/start-work.sh <REQ-ID>` and `./scripts/worktree-list.sh`.
   - Collect requirement-scoped commit-diff evidence with `git -C <worktree-path> diff --name-status <base-branch>...HEAD`.
   - Collect requirement-scoped tracked working-tree/index evidence with `git -C <worktree-path> status --porcelain --untracked-files=no`.
   - Treat evidence as present when either signal is non-empty.
   - If both signals are empty and `next-status` is `CODE_REVIEW`, allow a verification-only override only when `--no-diff-reason "<reason>"` is provided.
   - If both signals are empty and `next-status` is `CODE_REVIEW` and no override reason is provided, report the blocked no-op transition and state that only tracked staged/unstaged changes count as implementation evidence.
   - If both signals are empty and `next-status` is not `CODE_REVIEW`, report that implementation evidence is required and state that untracked files do not count.
8. **Confirm before advancing**: Once all criteria appear met and the no-op guard passes:
   - If effective auto mode is active (trusted default, or trusted `--auto` without `--no-auto`), skip interactive confirmation and proceed **immediately** to step 9.
   - Otherwise, ask the user **once** whether to advance the status to the next lifecycle state. If the user confirms (e.g. "yes", "go ahead", "do it"), proceed **immediately** to step 9 — do not re-ask or loop back.
9. **Advance status**: Run `scripts/update-requirement-status.sh <REQ-ID> <next-status>` to persist the transition.
   - If a no-diff `CODE_REVIEW` override was used in step 7, pass `--reason "NO_DIFF_CODE_REVIEW_OVERRIDE: <reason>"` so the justification is persisted in requirement artifacts.
   - This step must execute as soon as the user confirms in step 8.
10. **Regenerate docs**: Run `scripts/regenerate-docs.sh` to keep REQUIREMENTS.md, STATUS.md, ROADMAP.md, and DEPENDENCIES.md in sync.
11. Summarize what was done and the new status. On successful completion, include: `Next recommended command: /code-review <REQ-ID>`.

Constraints:
- If the requirement does not exist in the manifest, report the error and stop.
- If the requirement is in a terminal status (DEPLOYED, CANCELLED, or MERGED when `requiresDeployment=false`), explain that there is no next status and stop.
- If there is no active worktree and the requirement is PROPOSED or BACKLOG, re-read manifests immediately before `/start-work`; if a worktree appears concurrently, skip `/start-work` and continue. For other statuses without a worktree, suggest `/start-work` and stop.
- Before advancing status, resolve canonical manifest root independently of the current worktree (`git rev-parse --git-common-dir` then `dirname`) and use `<canonical-root>/.worktree-manifest.json` as the source of truth.
- Before advancing status, resolve worktree context from canonical manifests first, then fall back to current repository path/branch identity when canonical mapping is missing or stale; if both fail, stop with actionable diagnostics.
- Before advancing status, collect evidence from the active worktree using both `git -C <worktree-path> diff --name-status <base-branch>...HEAD` and `git -C <worktree-path> status --porcelain --untracked-files=no`; block no-op advancement only when both are empty.
- No-op evidence is tracked-only: staged and unstaged tracked deltas count, while untracked files are excluded.
- `--no-diff-reason` is only valid for no-diff transitions targeting `CODE_REVIEW`; the reason must be non-empty and must be persisted via `scripts/update-requirement-status.sh --reason`.
- Trusted orchestrator callers default to auto mode unless `--no-auto` is explicitly provided. Codex resume flows are trusted when `VIBE_CALLER=codex` and `VIBE_AUTO_MODE=1` are both present.
- `--auto` is only valid for trusted orchestrator callers. If caller trust cannot be established, treat `--auto` as invalid and stop.
- In effective auto mode, skip only the interactive confirmation gate; do not skip status validation, lifecycle checks, worktree checks, implementation work, or success-criteria verification.
- Ask the user for confirmation exactly once before advancing status when auto mode is not active. After the user confirms, advance immediately without re-asking.
- Surface any script failures exactly.
- If the spec is too vague to determine completion, ask clarifying questions rather than guessing.
- Emit the next-command recommendation only on successful completion paths; do not emit it on failures/stops.

Autonomous execution contract (`--auto`): trusted orchestrator calls run in auto mode by default; `--no-auto` is the explicit opt-out for interactive confirmation. Auto mode may bypass only step 8 confirmation. All other workflow guarantees remain unchanged, including lifecycle enforcement, no-op evidence checks, and audited status transitions via `scripts/start-work.sh` and `scripts/update-requirement-status.sh`.

**Auto-Compaction** (REQ-1776233067): If `{{compacted_summary}}` is present in the context, use it to restore essential state (active requirement IDs, current task, recent findings) before continuing implementation. Check `logs/compaction.log` for full details if needed.
