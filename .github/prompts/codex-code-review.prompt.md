---
name: "codex-code-review"
description: "Codex-friendly wrapper for /code-review with consistent skill context and follow-up guidance. Use when: running review quickly from Codex after /work-on or /worktree-merge prep."
argument-hint: "[scope]"
agent: "Vibe Agent Orchestrator"
---

Run `/code-review` from Codex with review-skill context and predictable follow-up guidance.

Workflow:
1. Parse optional `scope` argument.
2. Set caller metadata:
   - `VIBE_CALLER=codex`
   - `VIBE_AUTO_MODE=1`
3. Invoke `/code-review [scope]` and follow the `code-review` skill workflow.
4. If the review succeeds and unresolved findings remain, recommend `/start-work <REQ-ID>` for created follow-up threads.

Constraints:
- Do not weaken severity ordering, evidence requirements, or REQ-thread generation rules from `/code-review`.
- Surface script or workflow failures exactly and stop.
- Keep behavior aligned with `/code-review`; this command is a Codex usability wrapper.
