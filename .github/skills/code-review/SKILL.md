---
name: code-review
description: "Performs code review for vibe projects and generates requirement threads from findings. Use when: reviewing completed work, identifying defects or risks, creating follow-up REQ threads, and preparing code for merge."
---

# Code Review + REQ Threads Skill

Review code changes with requirement-aware output and convert actionable findings into tracked REQ threads.

## Goal

Provide high-signal review findings and ensure unresolved issues become explicit requirement threads.

## Slash Commands

### `/code-review [scope]`
Run a full review over current changes, branch, or requirement scope.

## Workflow Actions (run inside `/code-review`)

- `code-review-req <req-id>`: review code linked to a specific requirement ID.
- `code-review-create-threads`: create REQ threads for unresolved findings.

## Review Priorities

1. Correctness and behavior regressions
2. Security and data integrity risks
3. Reliability and error handling
4. Test coverage gaps
5. Maintainability and documentation drift

## Review Output Format

```markdown
## Findings (ordered by severity)
- [HIGH] <title>
  - Evidence: <file/path + symptom>
  - Impact: <why this matters>
  - Recommendation: <minimal concrete fix>

## Open Questions
- <question>

## REQ Threads Needed
- <finding-to-thread mapping>
```

## REQ Thread Generation Rules

Create a new requirement thread when a finding is:
- Not fixed in the current change
- Too large for immediate patching
- Cross-cutting across modules
- Risky and needs tracked follow-up

Use one requirement per independent concern.

## Create REQ Thread Command Pattern

```bash
./scripts/create-requirement.sh \
  "Review follow-up: <short issue title>" \
  "Source: code-review. Severity: <HIGH|MEDIUM|LOW>. Evidence: <summary>. Required outcome: <acceptance criteria>." \
  HIGH
```

For multi-step enrichment flows that must commit atomically, use:

```bash
./scripts/create-requirement.sh \
  "Review follow-up: <short issue title>" \
  "Source: code-review. Severity: <HIGH|MEDIUM|LOW>. Evidence: <summary>. Required outcome: <acceptance criteria>." \
  HIGH \
  --no-commit
```

Then enrich the generated spec and run `./scripts/regenerate-docs.sh`, followed by one final `git add` + `git commit`.

After creation:
- Link the new REQ ID in review notes
- Set dependency links if it blocks another requirement
- Recommend `/start-work <new-req-id>` when immediate action is needed

## Best Practices

1. Report only evidence-backed findings.
2. Keep recommendations minimal and testable.
3. Distinguish must-fix items from optional improvements.
4. Convert unresolved critical issues into REQ threads immediately.
5. Ensure every thread has clear acceptance criteria.

## Auto-Compaction Awareness (REQ-1776233067)

When auto-compaction fires during a code review session:
- The compaction summary replaces older conversation turns but preserves active requirement IDs and current review state.
- If previously identified findings were compacted, re-emit them from the `compactionSummary` field before continuing.
- Check `logs/compaction.log` for the full compaction record if needed.
- The review workflow continues correctly after compaction — no restart required.
