---
name: update-manual
description: "Generates and updates user manuals for vibe projects. Use when: documenting new features, refreshing usage guides after requirement changes, creating quickstart docs, or syncing manuals with current behavior."
---

# Manual Updater Skill

Generate and maintain user-facing documentation that stays aligned with implemented requirements.

## Goal

Keep project manuals accurate after every meaningful feature, workflow, or command change.

## Slash Commands

### `/update-manual [scope]`
Regenerate and update user manual sections for the selected scope.

## Optional Output Sections (produced by `/update-manual`)

- `manual-audit`: compare docs against implemented behavior and list drift.
- `manual-changelog`: produce user-facing release notes from recently merged requirements.

## Default Manual Targets

- `README.md` (quickstart and key commands)
- `REQUIREMENTS.md` (current requirement overview)
- `docs/STATUS.md` (state dashboard)
- `docs/ROADMAP.md` (forward plan)
- `docs/DEPENDENCIES.md` (feature relationships)

## Workflow

1. Gather change context
- Read requirement/worktree updates since last manual update
- Identify user-visible behavior changes

2. Detect documentation drift
- Missing command docs
- Outdated examples
- Wrong status/state transitions

3. Update manuals
- Keep examples executable and current
- Reflect real slash commands and scripts
- Preserve concise onboarding flow

4. Validate docs
- Ensure referenced files/commands exist
- Ensure command names match current skills/agents

5. Publish summary
- What changed
- Why it changed
- What users should do differently

## User Manual Section Template

```markdown
## <Feature Name>

### What It Does
<one-paragraph description>

### How To Use
1. <step one>
2. <step two>
3. <step three>

### Commands
- /<command>
- ./scripts/<script>.sh

### Output
<expected result>

### Troubleshooting
- <common issue>: <resolution>
```

## Best Practices

1. Document behavior, not internal implementation details.
2. Prefer short runnable examples over abstract text.
3. Keep command and state names exact.
4. Update manuals in the same change where behavior changed.
5. Explicitly call out breaking or changed workflows.
