---
name: agent-customization
description: "**WORKFLOW SKILL** — Create, update, review, fix, or debug VS Code agent customization files (.instructions.md, .prompt.md, .agent.md, SKILL.md, copilot-instructions.md, AGENTS.md). USE FOR: saving coding preferences; troubleshooting why instructions/skills/agents are ignored or not invoked; configuring applyTo patterns; defining tool restrictions; creating custom agent modes or specialized workflows; packaging domain knowledge; fixing YAML frontmatter syntax. DO NOT USE FOR: general coding questions (use default agent); runtime debugging or error diagnosis; MCP server configuration (use MCP docs directly); VS Code extension development. INVOKES: file system tools (read/write customization files), ask-questions tool (interview user for requirements), subagents for codebase exploration. FOR SINGLE OPERATIONS: For quick YAML frontmatter fixes or creating a single file from a known pattern, edit the file directly — no skill needed."
---

# Agent Customization Skill

Specialized workflow for maintaining Vibe Master agent instructions, prompts, and skills.

## When to Use
- Updating `copilot-instructions.md`, `.github/prompts/*.prompt.md`, or `SKILL.md` files
- Adding references to external frameworks like obra/superpowers while preserving Vibe standards
- Fixing inconsistencies between slash commands and implemented skills

## Best Practices
- Keep changes minimal and backward-compatible
- Reference superpowers skills only where they directly enhance existing Vibe patterns (e.g. systematic-debugging aligns with debug/SKILL.md)
- Always regenerate docs after changes
- Test with `/status` and `/show-requirement`

**Related**: See `copilot-instructions.md` for global slash command registry.