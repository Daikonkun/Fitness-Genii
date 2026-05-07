---
name: "init"
description: "Initialize a vibe project by clearing Vibe-Master-internal REQs while preserving project-specific ones. Use when: setting up a new project from the Vibe Master template."
argument-hint: "[project-name]"
agent: "Vibe Agent Orchestrator"
---

Initialize a vibe project by clearing Vibe Master template REQs and preparing clean manifests.

Workflow:
1. **Parse arguments**: Accept an optional `[project-name]` (default: "My Vibe Project").
2. **Self-protection check**: Verify that `.vibe-master-source` does **not** exist in the project root. If it does, report that this is the Vibe Master source repository and refuse to execute. This prevents accidental clearing of the template's own REQ history.
3. **Run `scripts/init-project.sh`** with the project name argument. The script will:
   a. Remove only REQs tagged with `"origin": "vibe-master"` from `.requirement-manifest.json`.
   b. Delete only the corresponding `docs/requirements/REQ-*.md` spec files for those REQs.
   c. Preserve all REQs where `origin` is `"project"` or absent (treated as project-owned).
   d. Reset `.worktree-manifest.json` to an empty worktrees array.
   e. Update the `projectName` in `.requirement-manifest.json`.
   f. Regenerate docs and commit.
4. **Report**: Summarize how many Vibe Master REQs were cleared, how many project REQs were preserved, and the new project name.
5. **Recommend next steps**: Suggest `/add-requirement` to create the first project requirement, or `/status` to view the clean slate.

Constraints:
- Never run on the Vibe Master source repo (detected by `.vibe-master-source` sentinel).
- Never delete REQs where `origin` is `"project"` or where `origin` is missing/null.
- If `init-project.sh` fails, surface the exact error and stop.
- If there are no Vibe Master REQs to clear, report that the project is already initialized.
