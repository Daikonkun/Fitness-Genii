# Command Map (Canonical)

Canonical source of truth for slash-command entrypoints.

- **Prompt-backed command**: implemented by `.github/prompts/<name>.prompt.md`.
- **Script entrypoint**: a single `scripts/*.sh` file that is the command's primary shell entrypoint.
- **Primary Skill (Codex)**: preferred skill context when invoking from Codex. `none` means prompt-only orchestration.
- **`none (prompt-driven)`** means there is intentionally no dedicated `scripts/<name>.sh` wrapper.
- This mapping is consumed for command discoverability parity across Copilot Chat and Codex plugin chat in VS Code.

| Command | Prompt File | Script Entrypoint | Primary Skill (Codex) | Notes |
|---|---|---|---|---|
| `/add-requirement` | `.github/prompts/add-requirement.prompt.md` | `scripts/create-requirement.sh` | `requirement-tracker` | Regenerates docs via `scripts/regenerate-docs.sh` |
| `/bug-fix` | `.github/prompts/bug-fix.prompt.md` | none (prompt-driven) | `debug` | Workflow-oriented prompt |
| `/codex-code-review` | `.github/prompts/codex-code-review.prompt.md` | none (prompt-driven) | `code-review` | Codex-friendly wrapper that runs `/code-review` in Codex-trusted mode |
| `/codex-resume` | `.github/prompts/codex-resume.prompt.md` | `scripts/codex-resume.sh` | `requirement-tracker` | Hydrates Codex session context and recommends next command |
| `/codex-work-on` | `.github/prompts/codex-work-on.prompt.md` | none (prompt-driven) | `requirement-tracker` | Codex-friendly wrapper that runs `/work-on` in Codex-trusted mode |
| `/code-review` | `.github/prompts/code-review.prompt.md` | none (prompt-driven) | `code-review` | May run `scripts/regenerate-docs.sh` |
| `/dependency-graph` | `.github/prompts/dependency-graph.prompt.md` | `scripts/dependency-graph.sh` | `requirement-tracker` |  |
| `/e2e-test` | `.github/prompts/e2e-test.prompt.md` | none (prompt-driven) | none | Workflow-oriented prompt |
| `/init` | `.github/prompts/init.prompt.md` | `scripts/init-project.sh` | `requirement-tracker` |  |
| `/list-requirements` | `.github/prompts/list-requirements.prompt.md` | `scripts/list-requirements.sh` | `requirement-tracker` |  |
| `/regen-docs` | `.github/prompts/regen-docs.prompt.md` | `scripts/regenerate-docs.sh` | `update-manual` |  |
| `/roadmap` | `.github/prompts/roadmap.prompt.md` | `scripts/roadmap.sh` | `requirement-tracker` |  |
| `/rollback` | `.github/prompts/rollback.prompt.md` | `scripts/rollback-requirement.sh` | `worktree-manager` |  |
| `/show-requirement` | `.github/prompts/show-requirement.prompt.md` | `scripts/show-requirement.sh` | `requirement-tracker` |  |
| `/start-work` | `.github/prompts/start-work.prompt.md` | `scripts/start-work.sh` | `worktree-manager` |  |
| `/status` | `.github/prompts/status.prompt.md` | `scripts/status.sh` | `requirement-tracker` |  |
| `/update-manual` | `.github/prompts/update-manual.prompt.md` | none (prompt-driven) | `update-manual` | Workflow-oriented prompt |
| `/update-requirement` | `.github/prompts/update-requirement.prompt.md` | `scripts/update-requirement-status.sh` | `requirement-tracker` |  |
| `/upgrade` | `.github/prompts/upgrade.prompt.md` | `scripts/upgrade.sh` | `worktree-manager` | Uses `scripts/check-upgrade-manifest-history.sh` and `scripts/regenerate-docs.sh` |
| `/work-on` | `.github/prompts/work-on.prompt.md` | none (prompt-driven) | `requirement-tracker` | Uses `scripts/start-work.sh`, `scripts/update-requirement-status.sh`, `scripts/regenerate-docs.sh`, `scripts/worktree-list.sh` inside workflow; **do not call a dedicated work-on shell wrapper** |
| `/worktree-create` | `.github/prompts/worktree-create.prompt.md` | none (prompt-driven) | `worktree-manager` | Workflow-oriented prompt |
| `/worktree-list` | `.github/prompts/worktree-list.prompt.md` | `scripts/worktree-list.sh` | `worktree-manager` |  |
| `/worktree-merge` | `.github/prompts/worktree-merge.prompt.md` | `scripts/worktree-merge.sh` | `worktree-manager` | Supports optional `--auto-resolve-conflicts` |
| `/worktree-prune` | `.github/prompts/worktree-prune.prompt.md` | none (prompt-driven) | `worktree-manager` | Workflow-oriented prompt |
| `/worktree-status` | `.github/prompts/worktree-status.prompt.md` | none (prompt-driven) | `worktree-manager` | Workflow-oriented prompt |
