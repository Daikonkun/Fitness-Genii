# Vibe Agent Orchestrator

A VS Code AI-driven development orchestrator for managing requirements, git worktrees, and parallel development in "vibe coding" projects (AI-only development driven through VS Code).

## 🚀 Quick Start

### 1. Clone This Template
```bash
git clone <this-repo-url> my-vibe-project
cd my-vibe-project
git remote remove origin  # Detach from template
git remote add origin <your-new-repo>
```

### 2. Bootstrap Dependencies (Recommended)
Manifest-mutating workflows use lock-safe writes.
If `flock` is available, scripts use advisory `flock` locking.
If `flock` is unavailable (common on fresh macOS), scripts fall back to a portable `mkdir` lock.

Verify prerequisites:
```bash
bash scripts/bootstrap-deps.sh
```

Install automatically on macOS with Homebrew:
```bash
bash scripts/bootstrap-deps.sh --install
```

### 2b. Install Local Git Hooks (Recommended)
Enable the repository-managed pre-push guard so drift is blocked before remote pushes:
```bash
bash scripts/install-git-hooks.sh
```

### 3. Initialize Your Project
Run the init script to reset manifests and remove Vibe Master's own requirement history:
```bash
bash scripts/init-project.sh "My Project Name"
```
This will:
- Reset `.requirement-manifest.json` and `.worktree-manifest.json` to empty
- Remove historical `REQ-*.md` files from `docs/requirements/` (example files are preserved)
- Regenerate clean `REQUIREMENTS.md`, `STATUS.md`, `ROADMAP.md`, and `DEPENDENCIES.md`

### 4. Open in VS Code
Open the project in VS Code. The orchestrator agent will auto-load from `.github/agents/orchestrator.agent.md`.

### 5. Submit Your First Requirement
```
/add-requirement "User Authentication" "Implement email/password authentication system"
```

This slash command is provided by `.github/prompts/add-requirement.prompt.md`.

The agent will:
- Create requirement record (unique ID: `REQ-{timestamp}`)
- Create detailed spec file (`docs/requirements/REQ-XXX-user-authentication.md`)
- Update `REQUIREMENTS.md` summary
- Suggest creating a git worktree

### 6. Start Work
```
/start-work REQ-001
```

The agent will:
- Create a git worktree: `feature/REQ-001-user-authentication`
- Update requirement status to `IN_PROGRESS`
- Provide context on what to build

### 7. Check Status Anytime
```
/status
```

Shows current dashboard with all requirements, worktrees, and progress.

---

## 🔄 Upgrading Existing Projects

Use this when your repo already uses an older Vibe Master layout and you want the latest agents/skills/workflows without losing requirement history.

### Automated Slash Command (Recommended)

Use `/upgrade` to run a conflict-aware, worktree-isolated upgrade workflow.

Preview only (safe default):
```
/upgrade
```

Apply after review:
```
/upgrade --apply
```

Optional template source override:
```
/upgrade --template-repo https://github.com/<org>/vibe-master.git
```

What this command guarantees:
- Preflight slash-command name conflict checks before file operations
- Upgrade preparation in an isolated sibling worktree (not the currently edited tree)
- A generated diff preview before any apply step
- Explicit confirmation before applying template files
- Post-upgrade validation guidance for manifest checks, docs regeneration, and upgrade-history regression coverage

### Safe Upgrade Workflow

1. Tag the current state as a safety point.
```bash
git tag "pre-vibe-upgrade-$(date +%Y%m%d-%H%M)"
```

2. Create an isolated worktree for the migration.
```bash
git worktree add ../upgrade/vibe-master-latest -b chore/vibe-master-upgrade
cd ../upgrade/vibe-master-latest
```

3. Fetch the latest Vibe Master template and compare before replacing files.
```bash
# Replace <org> with the GitHub org or user hosting your Vibe Master template
git clone --depth 1 https://github.com/<org>/vibe-master.git .upgrade-template/latest
# Compare template against your current project:
diff -ruN --exclude='.git' --exclude='.upgrade-template' .upgrade-template/latest . | less
```

4. Merge files by category (replace vs merge) using the table below.

5. Validate manifests and regenerate docs.
```bash
jq . .requirement-manifest.json >/dev/null
jq . .worktree-manifest.json >/dev/null
bash scripts/regenerate-docs.sh
bash scripts/check-upgrade-manifest-history.sh
```

6. Run a quick behavior check and review.
```bash
git status --short
```

Then run these in Copilot Chat or Codex plugin chat:
```
/status
/code-review README.md
```

7. Clean up the temporary template folder.
```bash
rm -rf .upgrade-template
```

### Replace vs Merge Guide

| Path | Recommended Action | Why |
|---|---|---|
| `.github/agents/orchestrator.agent.md` | Replace, then re-apply local custom prompts | Agent mode and orchestration behavior changes most often here |
| `.github/prompts/` | Replace prompt files from latest template, then keep local custom prompts with unique names | Slash commands appear in Copilot Chat and Codex plugin chat only when backed by prompt files |
| `.github/skills/` | Replace skill folders from latest template | Keeps slash-command workflows and guidance current |
| `copilot-instructions.md` | Merge carefully (do not blindly replace) | Local policy/tool constraints are often customized |
| `scripts/regenerate-docs.sh` | Replace with latest, then verify project-specific edits | Fixes to generation logic accumulate over time |
| `scripts/create-requirement.sh` | Replace with latest, then confirm ID format expectations | Prevents manifest drift caused by old creation logic |
| `.requirement-manifest.json` | Merge data only; never replace with template stub | This file contains your real requirement history |
| `.worktree-manifest.json` | Merge data only; keep active worktree entries | Replacing can orphan valid worktrees |
| `README.md` | Merge sections selectively | Keep project-specific onboarding while adding new workflows |
| `docs/` generated files | Regenerate, do not hand-copy from template | Generated docs should reflect your local manifests |

### Compatibility Notes

- Old repos may lack newer status values or fields (for example `worktreeId`, `dependsOn`, `deployedAt`); add missing fields incrementally rather than rewriting history.
- Slash command behavior is driven by agent + skill files. If commands behave differently after upgrade, check `.github/agents/` and `.github/skills/` first.
- If your project uses `develop` instead of `main`, update base-branch references in agent/instruction docs after template updates.
- If your team added custom skills, move them back after template refresh and verify command names do not conflict.
- Always run `bash scripts/regenerate-docs.sh` after manifest or workflow file changes so `REQUIREMENTS.md` and `docs/*.md` stay aligned.

### Post-upgrade Verification Checklist

- `git diff --name-only` shows expected workflow files only (`.github/agents`, `.github/prompts`, `.github/skills`, `copilot-instructions.md`, `scripts/*`).
- All required slash command prompt files exist under `.github/prompts/` for the commands your team expects.
- `jq . .requirement-manifest.json` and `jq . .worktree-manifest.json` both pass.
- `bash scripts/regenerate-docs.sh` completes successfully without jq parse errors.
- `bash scripts/check-upgrade-manifest-history.sh` passes so upgrade apply behavior does not wipe manifest history.
- `/status`, `/show-requirement <req-id>`, and `/worktree-list` return expected output after refresh.

---

## 📁 Project Structure

```
.
├── .github/
│   ├── agents/
│   │   └── orchestrator.agent.md          # Main orchestrator agent
│   ├── workflows/
│   │   └── docs-sync-guard.yml            # CI: fail if generated docs drift from manifests
│   ├── prompts/
│   │   ├── add-requirement.prompt.md      # Slash command for requirement creation
│   │   ├── bug-fix.prompt.md              # Wrapper prompt for debug workflow skill
│   │   ├── codex-resume.prompt.md         # Slash command for Codex resume preflight
│   │   ├── codex-work-on.prompt.md        # Codex wrapper for /work-on
│   │   ├── codex-code-review.prompt.md    # Codex wrapper for /code-review
│   │   ├── code-review.prompt.md          # Wrapper prompt for review skill
│   │   ├── dependency-graph.prompt.md     # Slash command for dependency visualization
│   │   ├── e2e-test.prompt.md             # Slash command for end-to-end testing
│   │   ├── init.prompt.md                 # Slash command for project initialization
│   │   ├── list-requirements.prompt.md    # Slash command for requirement listings
│   │   ├── regen-docs.prompt.md           # Slash command for manual doc regeneration
│   │   ├── roadmap.prompt.md              # Slash command for roadmap view
│   │   ├── rollback.prompt.md             # Slash command for reverting a merged requirement
│   │   ├── show-requirement.prompt.md     # Slash command for requirement details
│   │   ├── start-work.prompt.md           # Slash command for worktree start
│   │   ├── status.prompt.md               # Slash command for status dashboard
│   │   ├── upgrade.prompt.md              # Slash command for safe Vibe Master upgrades
│   │   ├── update-manual.prompt.md        # Wrapper prompt for manual update skill
│   │   ├── update-requirement.prompt.md   # Slash command for lifecycle status transitions
│   │   ├── work-on.prompt.md              # Slash command for iterative requirement work
│   │   ├── worktree-create.prompt.md      # Slash command for manual worktree creation
│   │   ├── worktree-list.prompt.md        # Slash command for active worktrees
│   │   ├── worktree-merge.prompt.md       # Slash command for merge and cleanup
│   │   ├── worktree-prune.prompt.md       # Slash command for orphan worktree cleanup
│   │   └── worktree-status.prompt.md      # Slash command for worktree dashboard
│   ├── instructions/
│   ├── skills/
│   │   ├── agent-customization/SKILL.md    # Agent/prompt/skill file maintenance
│   │   ├── code-review/SKILL.md            # Code review + REQ thread creation
│   │   ├── debug/SKILL.md                  # Structured debugging workflow
│   │   ├── requirement-tracker/SKILL.md    # Requirement lifecycle
│   │   ├── update-manual/SKILL.md          # User manual generation/refresh
│   │   └── worktree-manager/SKILL.md       # Git worktree management
│   
├── .githooks/
│   └── pre-push                            # Local push guard: run docs sync validation
│
├── copilot-instructions.md                 # Global agent instructions
│
├── REQUIREMENTS.md                         # Summary of all requirements
├── .requirement-manifest.json              # Structured requirement data
├── .worktree-manifest.json                 # Worktree-to-requirement mapping
│
├── docs/
│   ├── requirements/                       # Detailed requirement specs
│   ├── STATUS.md                          # Auto-generated kanban board
│   ├── ROADMAP.md                         # Timeline view
│   └── DEPENDENCIES.md                    # Dependency graph
│
└── scripts/
    ├── bootstrap-deps.sh                  # CLI: verify/install optional flock dependency
  ├── check-upgrade-manifest-history.sh  # Regression: ensure upgrade apply preserves manifest history
    ├── check-docs-sync.sh                 # Guard: verify generated docs are synced with manifests
    ├── check-manifest-lock-race.sh        # Regression: concurrent manifest writers do not lose updates
    ├── codex-resume.sh                    # CLI: detect resumable REQ/worktree context for Codex
    ├── create-requirement.sh               # CLI: create new requirement
    ├── dependency-graph.sh                 # CLI: regenerate + show dependency graph
    ├── generate-plan.sh                    # CLI: generate/update Development Plan in a spec
    ├── init-project.sh                     # CLI: initialize project from template
    ├── install-git-hooks.sh                # CLI: activate repository-managed hooks (.githooks)
    ├── list-requirements.sh                # CLI: list requirements by optional status
    ├── regenerate-docs.sh                  # CLI: regenerate all docs
    ├── roadmap.sh                          # CLI: regenerate + show roadmap
    ├── rollback-requirement.sh             # CLI: revert a merged requirement
    ├── show-requirement.sh                 # CLI: display requirement details
    ├── start-work.sh                       # CLI: create worktree + set IN_PROGRESS
    ├── status.sh                           # CLI: regenerate + show status summary
    ├── upgrade.sh                          # CLI: isolated template upgrade preview/apply helper
    ├── update-requirement-status.sh        # CLI: validate and update requirement status
    ├── worktree-list.sh                    # CLI: list active worktrees from manifest
    └── worktree-merge.sh                   # CLI: merge branch + clean worktree
```

---

## 🎯 Core Workflows

### Adding a Requirement
Best via slash command for interactive guidance:
```
/add-requirement "<Feature name>" "<Description>" "[CRITICAL|HIGH|MEDIUM|LOW]"
```

Or CLI:
```bash
./scripts/create-requirement.sh "User Authentication" "Email/password login system" HIGH
```

### Starting Work on a Requirement
```
/start-work REQ-001
```

This:
1. Creates a git worktree: `feature/REQ-001-{slug}`
2. Sets requirement status to `IN_PROGRESS`
3. Provides development context

### Checking Project Status
```
/status
```

Displays:
- Kanban board (all requirements by status)
- Completion stats
- Active worktrees
- Blocked items

### Resuming in Codex
```
/codex-resume --auto-detect
```

This:
1. Detects canonical project/worktree context
2. Validates requirement/worktree manifests
3. Recommends the next lifecycle command (usually `/start-work <REQ-ID>` or `/work-on <REQ-ID>`)

For full-auto Codex orchestration, set:
```bash
export VIBE_CALLER=codex
export VIBE_AUTO_MODE=1
```

Fast Codex flow for orchestration-heavy commands:
```bash
/codex-work-on <REQ-ID>
/codex-code-review <REQ-ID>
```

### Completing Work
```
/worktree-merge feature/REQ-001-user-authentication
```

This:
1. Merges the feature branch to `main`/`develop`
2. Updates requirement status to `MERGED`
3. Removes the worktree
4. Regenerates documentation

### Viewing Requirement Details
```
/show-requirement REQ-001
```

Shows manifest data + full specification from `docs/requirements/REQ-001-*.md`

---

## 🔄 Requirement Lifecycle

```
PROPOSED
  ↓
IN_PROGRESS (work started, worktree created)
  ↓
CODE_REVIEW (ready for review)
  ↓
MERGED (merged to main/develop)
  ↓
DEPLOYED (shipped to production)
```

Alternative paths:
- Any state → `BLOCKED` (with reason)
- Any state → `BACKLOG` (deprioritized)
- Any state → `CANCELLED` (abandoned)

---

## 🌿 Git Worktree Convention

Each requirement gets an isolated git worktree for parallel development:

```
project-root/
├── .git/
├── (main branch files)
└── ..

../feature/REQ-001-auth-system/
├── .git (worktree)
├── (feature files)

../feature/REQ-002-dashboard/
├── .git (worktree)
├── (feature files)
```

**Naming**: `{type}/{req-ids}-{slug}`
- Types: `feature`, `fix`, `refactor`, `docs`
- Example: `feature/REQ-001-user-auth`
- Grouped: `feature/REQ-003+REQ-004-related-features`

---

## 📊 Automated Documentation

The orchestrator auto-generates these files:

### `REQUIREMENTS.md`
Table of all requirements with status, priority, dates

### `docs/STATUS.md`
Kanban board showing requirements grouped by status

### `docs/ROADMAP.md`
Timeline view ordered by priority

### `docs/DEPENDENCIES.md`
Graph showing which requirements depend on others

**Regenerate manually**:
```bash
./scripts/regenerate-docs.sh
```

---

## 🛠 Key Slash Commands

These commands are designed to work in both Copilot Chat and Codex plugin chat in VS Code. Keep prompt metadata (`name`, `description`, `agent`) aligned with prompt filenames so slash command routing remains discoverable across both clients.

Slash commands only show up in chat when they are backed by a prompt file or by a valid skill definition. This template ships prompt files for every command listed below and loads workflow skills through valid lowercase-hyphenated skill names.

Quick compatibility check:
```bash
bash scripts/check-command-entrypoints.sh
```

| Command | Purpose |
|---------|---------|
| `/add-requirement` | Submit new requirement |
| `/codex-resume [req-id|--auto-detect]` | Hydrate Codex session context and recommend the next command |
| `/codex-work-on <req-id> [target-status] [--no-auto] [--no-diff-reason "reason"]` | Codex-friendly wrapper for `/work-on` that pre-sets Codex trusted metadata |
| `/codex-code-review [scope]` | Codex-friendly wrapper for `/code-review` with skill-aligned review output |
| `/update-requirement <req-id> <new-status> [--force] [--no-refresh]` | Update requirement lifecycle status with transition validation |
| `/start-work <req-id>` | Begin work (create worktree + set IN_PROGRESS) |
| `/upgrade [--template-repo <github-url>] [--base-branch <branch>] [--apply]` | Safely preview/apply Vibe Master template upgrades in an isolated worktree with preflight command-conflict checks |
| `/work-on <req-id> [target-status] [--auto|--no-auto] [--no-diff-reason "reason"]` | Iteratively implement a requirement until next lifecycle status; no-op transitions are blocked by default, and no-diff `CODE_REVIEW` advances require an explicit persisted reason |
| `/status` | Show current dashboard |
| `/show-requirement <req-id>` | View requirement details |
| `/list-requirements [status]` | List requirements by status |
| `/init [project-name]` | Initialize a new project from the Vibe Master template |
| `/rollback <req-id> [base-branch]` | Roll back a merged/deployed requirement by reverting its merge commit |
| `/e2e-test [scope]` | Run end-to-end test; surfaces skill gaps as new REQs |
| `/worktree-list` | Show all active worktrees |
| `/worktree-merge <branch>` | Merge and cleanup (requires a clean working tree) |
| `/worktree-create <req-id> [base-branch]` | Create a worktree without changing requirement status |
| `/worktree-prune` | Remove orphaned worktrees and clean manifests |
| `/worktree-status` | Show comprehensive worktree status dashboard |
| `/dependency-graph` | Visualize dependencies |
| `/roadmap` | Show timeline |
| `/regen-docs` | Force doc regeneration |
| `/bug-fix "issue summary" [scope]` | Run structured debug workflow |
| `/update-manual [scope]` | Generate/update user manual content |
| `/code-review [scope]` | Review code and generate REQ follow-up threads |

---

## 🧠 Agent Capabilities

The orchestrator can:

1. **Create & manage requirements** — record, track, update lifecycle
2. **Create & manage git worktrees** — auto-create, detect conflicts, prune, cleanup
3. **Execute development workflows** — scaffold code, run tests, create PRs
4. **Work on requirements iteratively** — implement a req end-to-end via `/work-on`
5. **Run end-to-end tests** — validate features and surface missing skills via `/e2e-test`
6. **Roll back changes** — revert merged requirements via `/rollback`
7. **Generate documentation** — auto-update dashboards, timelines, graphs
8. **Detect conflicts** — warn if multiple requirements modify same files
9. **Suggest sequencing** — recommend order for dependent requirements

---

## 💡 Best Practices

1. **Be specific in requirements** — vague descriptions lead to rework
2. **Set priorities** — helps agent triage work
3. **Link dependencies** — prevents blocked work downstream
4. **Check `/status` regularly** — catch bottlenecks early
5. **One worktree per major feature** — avoid mixing independent work
6. **Group related features** — if tightly coupled, link them in one worktree
7. **Use meaningful branch names** — `feature/REQ-001-auth` not `feature/work1`
8. **Keep specs updated** — sync with actual implementation

---

## 🔧 Customization

### Change Default Base Branch
Edit `copilot-instructions.md` and `.github/agents/orchestrator.agent.md` to reference `develop` instead of `main`.

### Adjust Requirement ID Format
Currently uses timestamp: `REQ-{unix-timestamp}` (e.g., `REQ-1704067200`)

To use sequential IDs instead, modify `scripts/create-requirement.sh`:
```bash
# Current: REQ-$(date +%s)
# Alternative: REQ-$(printf "%03d" $COUNT)
```

### Add Custom Status Types
Edit:
- `.requirement-manifest.json` (enum values)
- `copilot-instructions.md` (state transitions)

---

## 📝 Requirements Manifest Format

### `.requirement-manifest.json`
```json
{
  "version": "1.0",
  "projectName": "My Vibe Project",
  "requirements": [
    {
      "id": "REQ-1704067200",
      "name": "User Authentication",
      "description": "Email/password login system",
      "status": "IN_PROGRESS",
      "priority": "HIGH",
      "worktreeId": "feature/REQ-1704067200-user-auth",
      "dependsOn": [],
      "createdAt": "2024-01-01T12:00:00Z",
      "updatedAt": "2024-01-02T15:30:00Z",
      "notes": "Using bcrypt for password hashing"
    }
  ]
}
```

### `.worktree-manifest.json`
```json
{
  "version": "1.0",
  "worktrees": [
    {
      "id": "feature/REQ-1704067200-user-auth",
      "path": "../feature/REQ-1704067200-user-auth",
      "branch": "feature/REQ-1704067200-user-auth",
      "baseBranch": "main",
      "requirementIds": ["REQ-1704067200"],
      "createdAt": "2024-01-01T12:00:00Z",
      "status": "ACTIVE"
    }
  ]
}
```

---

## 🚨 Troubleshooting

**Agent not responding to `/` commands?**
- Check that `copilot-instructions.md` is loaded (should be auto-loaded)
- Confirm the command has a backing prompt or skill file; command prompts live in `.github/prompts/`
- Ensure agent contextis fresh (close/reopen chat)

**Worktree creation failed?**
- Check git is initialized: `git status`
- Ensure no other process is holding the directory
- Run `git worktree prune` to clean stale worktrees

**Documentation not updating?**
- Manually regenerate: `./scripts/regenerate-docs.sh`
- Or use: `/regen-docs` slash command

**Manifest files out of sync?**
- Both are authoritative sources; if conflicted, prefer `.requirement-manifest.json`
- Manually fix `.worktree-manifest.json` if entries are stale

---

## 📚 Resources

- Agent docs: `.github/agents/orchestrator.agent.md`
- Requirement skill: `.github/skills/requirement-tracker/SKILL.md`
- Worktree skill: `.github/skills/worktree-manager/SKILL.md`
- Debug skill: `.github/skills/debug/SKILL.md`
- Manual updater skill: `.github/skills/update-manual/SKILL.md`
- Code review skill: `.github/skills/code-review/SKILL.md`
- Agent customization skill: `.github/skills/agent-customization/SKILL.md`
- Global instructions: `copilot-instructions.md`

---

## 📄 License

This template is open source. Customize freely for your projects.

---

**Happy vibe coding! 🎉**
