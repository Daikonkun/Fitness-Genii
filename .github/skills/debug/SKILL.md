---
name: debug
description: "Specialized debugging workflow for vibe projects. Use when: triaging runtime errors, reproducing bugs, isolating root causes, proposing fixes, validating regressions, or preparing bug-fix requirements."
---

# Debug Specialist Skill

Focused debugging workflow for AI-driven vibe projects with requirement tracking.

## Goal

Turn a bug report into a reproducible diagnosis, minimal fix plan, and tracked requirement updates.

## Slash Commands

### `/bug-fix "issue summary" [scope]`
Run full debugging workflow for a specific issue.

## Workflow Phases (run inside `/bug-fix`)

- `repro`: only reproduce and collect diagnostics.
- `root-cause`: analyze likely root cause from collected evidence.
- `validate`: validate a fix and run regression checks.

## Workflow

1. Clarify bug context
- Expected behavior
- Actual behavior
- Environment (branch, worktree, runtime)
- Reproduction steps

2. Reproduce reliably
- Run app or tests in deterministic mode
- Capture exact error output and stack traces
- Identify first failing test or first visible runtime break

3. Isolate root cause
- Narrow to smallest failing unit (module/function/input)
- Check recent requirement/worktree changes tied to impacted files
- Confirm root cause with a focused experiment

4. Propose and apply fix
- Prefer smallest safe change
- Add or update tests that fail before and pass after
- Keep requirement status in sync (IN_PROGRESS or CODE_REVIEW)

5. Validate and summarize
- Re-run targeted tests first, then broader regression checks
- Document cause, fix, and verification evidence
- If unresolved, create a blocked requirement with blockers and next probes

## Evidence Template

```markdown
## Debug Report
- Issue: <summary>
- Reproduction: <pass/fail + exact steps>
- Root Cause: <single concise statement>
- Fix Scope: <files/modules>
- Validation: <tests/commands/results>
- Regression Risk: <low/medium/high + why>
```

## Optional Requirement Threading

If no requirement exists for the bug, create one:

```bash
./scripts/create-requirement.sh \
  "Bug fix: <short title>" \
  "Debug finding: <root cause + impact + fix direction>" \
  HIGH
```

Then continue implementation in a dedicated worktree.

## Feature Escalation

During a `/bug-fix` session, if the fix requires implementing a **new function or feature** that does not yet exist in the project, do not silently build it inline. Instead, escalate it to a tracked requirement:

## Auto-Compaction Awareness (REQ-1776233067)

When auto-compaction fires during a debug session:
- The compaction summary replaces older conversation turns but preserves active requirement IDs and current task state.
- If critical debug context (stack traces, reproduction steps) was compacted, re-emit the essential state from the `compactionSummary` field.
- Check `logs/compaction.log` for the full compaction record if needed.
- The debug workflow is designed to continue correctly after compaction — no restart required.

1. **Detect the need** — While proposing or applying a fix, recognise when the solution depends on functionality that is outside the scope of the current bug (e.g., a missing utility, a new API endpoint, or an unbuilt UI component).

2. **Create a new REQ** — Run the create-requirement script to track the new work:

   ```bash
   ./scripts/create-requirement.sh \
     "<short feature title>" \
     "Needed to complete bug fix <current-REQ-ID>: <why this feature is required and what it should do>" \
     <priority>
   ```

   Choose a priority appropriate to the blocking impact (typically `HIGH` if it blocks the bug fix).

3. **Link as dependency** — Add the new REQ ID to the **Dependencies** section of the current bug-fix requirement spec so the relationship is tracked.

4. **Decide how to proceed** — Two options:
   - **Continue in the same worktree** if the feature is small and tightly coupled to the fix.
   - **Pause the bug fix** and recommend `/start-work <new-REQ-ID>` for a separate worktree if the feature is large or independently useful.

5. **Regenerate docs** — Run `./scripts/regenerate-docs.sh` after creating the new REQ to keep dashboards and dependency graphs current.

## Best Practices

1. Reproduce before editing code.
2. Prefer one proven root cause over multiple guesses.
3. Write a failing test first when practical.
4. Keep fixes minimal and traceable to evidence.
5. Record debug outcomes in requirement notes or spec files.
6. Escalate new feature needs to tracked REQs rather than building them silently.
