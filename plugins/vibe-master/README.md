# Vibe Master Codex Plugin

Local Codex plugin surface for Vibe Master workflows.

## Commands

These are exposed through plugin command routing (namespace format depends on Codex UI, typically `/vibe-master:<command>`):

- `resume`
- `work-on`
- `code-review`
- `add-requirement`
- `start-work`
- `worktree-merge`
- `e2e-test`
- `bug-fix`

## Source of Truth

Commands are wrappers around existing Vibe Master contracts:

- `.github/prompts/*.prompt.md`
- `.github/skills/*/SKILL.md`
- `scripts/*.sh`

This avoids duplicating lifecycle behavior while making command discovery feasible in Codex plugin surfaces.
