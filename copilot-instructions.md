---
name: Vibe Project Instructions
description: "Global instructions for all agents in vibe coding projects. Ensures consistent behavior, requirement tracking, and worktree management across all development workflows."
---

# Vibe Project Instructions

## Core Principles
- **User-centric AI coding**: The user only interfaces via VS Code and this agent
- **Transparent requirement tracking**: Every product requirement is visible, versioned, and linked to code
- **Parallel development**: Git worktrees enable safe, isolated feature work
- **Automated orchestration**: Minimal manual git/CLI work; agent handles branching, tracking, docs

## Best Practices

### When accepting a requirement:
1. Ask clarifying questions if vague
2. Identify dependencies on other requirements  
3. Suggest a worktree strategy (standalone vs. grouped)
4. Record the requirement with a unique ID (REQ-{timestamp-based})

### Before creating code:
1. Check if a related worktree already exists
2. If not, create one with a clear naming convention: `feature/{req-id}-{slug}`
3. Document the requirement link in the worktree

### During development:
1. Keep requirement status updated in `.requirement-manifest.json`
2. Tag commits with requirement ID: `feat(REQ-123): description`
3. On state changes, auto-regenerate documentation

### On merge/deployment:
1. Move requirement to MERGED/DEPLOYED
2. Clean up associated worktree
3. Regenerate all dashboards and timelines

## Key Files (Keep Updated)
- `REQUIREMENTS.md` — Human-readable requirement list
- `.requirement-manifest.json` — Structured requirement data (machine-readable)
- `docs/requirements/{id}-{name}.md` — Detailed requirement specs
- `.worktree-manifest.json` — Map of worktrees to requirements
- `docs/STATUS.md` — Auto-generated status dashboard
- `docs/e2e-screenshots/{scope}/` — E2e screenshot baselines and current runs (baselines are committed; `current/` is gitignored)

## Documentation Auto-Generation
After any state change, regenerate:
- `docs/STATUS.md` (kanban board + stats)
- `docs/ROADMAP.md` (timeline + milestones)
- `docs/DEPENDENCIES.md` (requirement dependency graph)
- Root `REQUIREMENTS.md` (summary table)

## Slash Commands Available

| Command | Purpose |
|---------|---------|
| `/add-requirement` | Submit new product requirement |
| `/status` | View current project status |
| `/start-work <req-id>` | Move requirement to IN_PROGRESS, create worktree |
| `/upgrade [--template-repo <github-url>] [--base-branch <branch>] [--apply]` | Safely preview/apply Vibe Master template upgrades in an isolated worktree with preflight command-conflict checks |
| `/update-requirement <req-id> <new-status> [--force] [--no-refresh]` | Update requirement status using validated lifecycle transitions |
| `/show-requirement <req-id>` | Show detailed requirement info |
| `/list-requirements [status]` | List all requirements, optionally filtered by status |
| `/rollback <req-id> [base-branch]` | Roll back a merged/deployed requirement by reverting its merge commit |
| `/worktree-list` | Show all active worktrees and their linked requirements |
| `/worktree-create <req-id>` | Manually create a worktree for a requirement |
| `/worktree-prune` | Remove orphaned worktrees |
| `/worktree-status` | Show comprehensive worktree status dashboard |
| `/worktree-merge <branch|REQ-ID> [base-branch] [--auto-resolve-conflicts]` | Merge associated worktree and update docs (requires clean working tree; optional safe auto-resolution for generated docs/manifests/spec conflicts) |
| `/dependency-graph` | Visualize requirement dependencies |
| `/roadmap` | Show timeline view of all requirements |
| `/regen-docs` | Force regeneration of REQUIREMENTS and dashboard docs |
| `/bug-fix "issue summary" [scope]` | Run structured debugging workflow and root-cause analysis |
| `/codex-work-on <req-id> [target-status] [--no-auto] [--no-diff-reason "reason"]` | Codex-friendly wrapper for `/work-on` that pre-sets trusted Codex caller metadata |
| `/codex-code-review [scope]` | Codex-friendly wrapper for `/code-review` with the same severity/threading contract |
| `/codex-resume [req-id|--auto-detect]` | Hydrate Codex session context, detect resumable requirement/worktree, and recommend next command |
| `/update-manual [scope]` | Generate and refresh user manual content |
| `/code-review [scope]` | Review code and create REQ follow-up threads for unresolved findings |
| `/work-on <req-id> [target-status] [--auto|--no-auto] [--no-diff-reason "reason"]` | Work on a requirement until it reaches its next lifecycle status; no-op transitions are blocked by default, and no-diff `CODE_REVIEW` advances require an explicit persisted reason |
| `/e2e-test [scope]` | Run end-to-end testing with screenshot-based cross-border visual validation; propose new skill REQs when gaps are found |
| `/init [project-name]` | Clear Vibe Master template REQs and initialize clean project manifests |

Slash commands appear in Copilot Chat and Codex plugin chat only when they are backed by prompt files or valid skill definitions. `/add-requirement`, `/list-requirements`, `/update-requirement`, `/start-work`, `/show-requirement`, `/status`, `/worktree-list`, `/worktree-create`, `/worktree-prune`, `/worktree-status`, `/worktree-merge`, `/dependency-graph`, `/roadmap`, `/regen-docs`, `/bug-fix`, `/codex-resume`, `/codex-work-on`, `/codex-code-review`, `/update-manual`, `/code-review`, `/work-on`, `/upgrade`, `/rollback`, `/e2e-test`, and `/init` are implemented by prompt files in `.github/prompts/`; skill files must keep lowercase hyphenated `name` values that match their folder names.

Note: Use `/worktree-merge <branch-name>` (not `/merge-requirement`) to complete a requirement.

## Git Worktree Convention
```
main/develop (default)
  ├── feature/REQ-001-auth-system
  ├── feature/REQ-002-user-dashboard
  ├── fix/REQ-003-login-bug
  └── feature/REQ-004+REQ-005-related-features (grouped)
```

Naming: `{type}/{req-ids}-{slug}`  
Types: `feature`, `fix`, `refactor`, `docs`

## Conflict Resolution
If multiple requirements:
- Conflict in files → flag and suggest sequential or grouped worktrees
- Dependency chain → order them in worktree creation
- Same goal, different users → consolidate into single requirement with variants

## Notes for AI-Only Workflow
- No manual git cherry-pick or complex rebasing — agent handles it
- No context switching between files and CLI — everything happens here
- Clear requirement → worktree → code → merge pipeline
- User reviews agent decisions; agent auto-executes approved work

## Auto-Compaction (REQ-1776233067)

When the context window approaches the LLM's token limit, auto-compaction triggers automatically:
- **Threshold**: Configurable in `.vibe-config.json` (default: 80% of context window)
- **What's preserved**: System prompt, active requirement IDs, current task state, and the last N turns (default: 3)
- **What's compacted**: Older conversation turns are replaced with a structured summary
- **Notification**: A `⚠️ Auto-compaction triggered` message appears with pre/post token counts
- **Logging**: Every compaction event is logged to `logs/compaction.log` with timestamp, token counts, and summary
- **Workflow continuity**: Multi-step workflows (e.g., `/start-work`, `/code-review`, `/bug-fix`) continue correctly after compaction
- **Config**: See `.vibe-config.json` for `contextWindowLimit`, `compactionThreshold`, `preservedTurns`, and per-model overrides
- **Manual check**: Run `scripts/compact-context.sh check` to see if compaction is needed
- **Manual compact**: Run `scripts/compact-context.sh compact < input.json` to force compaction

If critical context was lost during compaction, re-emit essential state from the `compactionSummary` field in the compacted output.

### Agent-Driven Compaction
The AI agent (not bash scripts) is responsible for invoking compaction, because only the agent has access to the conversation context JSON. When the agent detects its context is growing large:
1. Pipe the conversation JSON to `scripts/compact-context.sh check` to see if compaction is needed.
2. If `COMPACTION_NEEDED`, pipe the JSON to `scripts/compact-context.sh compact` to produce a compacted version.
3. Use the compacted output as the new conversation context going forward.
4. Re-emit any critical state from `compactionSummary` before continuing the current workflow.

### User-Specific Config
`.vibe-config.json` is tracked in the repo with sensible defaults. For personal overrides (e.g., different model preferences), create `.vibe-config.local.json` (gitignored) — the script will check for it first.

## Superpowers Alignment (REQ-1774685792)
Compatible references (minimal, non-breaking):
- `systematic-debugging` → aligns with `debug/SKILL.md` workflow
- `using-git-worktrees` → aligns with `worktree-manager/SKILL.md` + `start-work.prompt.md`
- `writing-plans` / `brainstorming` → aligns with requirement-tracker and `generate-plan.sh`
- `test-driven-development` → aligns with code-review and execution standards
- `agent-customization` skill now created (with matching prompt registration below) to handle prompt/SKILL.md updates

These enhance documentation and consistency without changing slash commands, manifest logic, or orchestrator mode.

**Slash command registry update**: `agent-customization` skill is now available via its SKILL.md (no dedicated prompt needed for single-file edits per its own guidelines).
