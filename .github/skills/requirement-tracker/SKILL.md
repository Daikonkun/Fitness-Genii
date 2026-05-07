---
name: requirement-tracker
description: "Manages product requirements lifecycle, tracking, and documentation. Use when: adding new requirements, updating requirement status, viewing requirement details, generating reports, or managing requirement dependencies."
---

# Requirement Tracker Skill

Comprehensive management of product requirements with automatic documentation generation.

## Core Workflows

### 1. Add New Requirement

**Dedicated prompt**: `/add-requirement "Name" "Description" [priority]`

**Skill invocation**: `/requirement-tracker`

**Process**:
1. Validate input (non-empty name, description)
2. Generate unique ID: `REQ-{timestamp}` (e.g., `REQ-1704067200`)
3. Create requirement record in `.requirement-manifest.json`
4. Create detailed spec file: `docs/requirements/{id}-{slug}.md`
5. Update root `REQUIREMENTS.md` summary
6. Prompt user for worktree creation

**Superpowers Alignment** (REQ-1774685792): Compatible with `brainstorming` and `writing-plans` skills for spec enrichment.

**Implementation**:
```bash
#!/bin/bash
NAME=$1
DESCRIPTION=$2
PRIORITY=${3:-MEDIUM}

REQ_ID="REQ-$(date +%s)"
SLUG=$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//; s/-$//')

# Add to manifest
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq --arg id "$REQ_ID" \
   --arg name "$NAME" \
   --arg desc "$DESCRIPTION" \
   --arg priority "$PRIORITY" \
   --arg ts "$TIMESTAMP" \
   '.requirements += [{
     id: $id,
     name: $name,
     description: $desc,
     status: "PROPOSED",
     priority: $priority,
     createdAt: $ts,
     updatedAt: $ts
   }]' .requirement-manifest.json > .requirement-manifest.json.tmp && \
  mv .requirement-manifest.json.tmp .requirement-manifest.json

# Create spec file
cat > "docs/requirements/${REQ_ID}-${SLUG}.md" << EOF
# $NAME

**ID**: $REQ_ID  
**Status**: PROPOSED  
**Priority**: $PRIORITY  
**Created**: $(date -u +%Y-%m-%dT%H:%M:%SZ)

## Description

$DESCRIPTION

## Success Criteria

- [ ] Item 1
- [ ] Item 2
- [ ] Item 3

## Technical Notes

(Add implementation notes here)

## Dependencies

(List other requirement IDs if applicable)

## Worktree

(Will be populated when work starts)

EOF

echo "Requirement $REQ_ID created"
```

### 2. Update Requirement Status

**Slash command**: `/update-requirement <req-id> [new-status]`

**Valid transitions**:
- PROPOSED → IN_PROGRESS, BACKLOG, CANCELLED
- IN_PROGRESS → CODE_REVIEW, BLOCKED, BACKLOG
- CODE_REVIEW → MERGED, BLOCKED
- MERGED → DEPLOYED (when requiresDeployment=true; default), CANCELLED
- Any → CANCELLED

**Implementation**:
```bash
#!/bin/bash
REQ_ID=$1
NEW_STATUS=$2

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq --arg id "$REQ_ID" \
   --arg status "$NEW_STATUS" \
   --arg ts "$TIMESTAMP" \
   '.requirements[] |= if .id == $id
     then .status = $status | .updatedAt = $ts
     else . end' .requirement-manifest.json > .requirement-manifest.json.tmp && \
  mv .requirement-manifest.json.tmp .requirement-manifest.json

echo "Updated $REQ_ID to $NEW_STATUS"
```

### 3. Show Requirement Details

**Slash command**: `/show-requirement <req-id>`

**Output**: Read the detailed spec file and display

```bash
#!/bin/bash
REQ_ID=$1

# Get from manifest
REQ_DATA=$(jq --arg id "$REQ_ID" '.requirements[] | select(.id == $id)' .requirement-manifest.json)

echo "=== Requirement $REQ_ID ==="
echo "$REQ_DATA" | jq '.'

# Show spec file if exists
SPEC_FILE=$(find docs/requirements -name "${REQ_ID}-*.md" 2>/dev/null | head -1)
if [ -f "$SPEC_FILE" ]; then
  echo ""
  echo "=== Specification ==="
  cat "$SPEC_FILE"
fi
```

### 4. Generate Documentation

**Workflow**: After any requirement change, auto-regenerate docs

**Files updated**:
- `REQUIREMENTS.md` — Summary table
- `docs/STATUS.md` — Kanban board + stats
- `docs/ROADMAP.md` — Timeline view
- `docs/DEPENDENCIES.md` — Dependency graph

**Implementation**: See templates below

---

## Documentation Templates

### REQUIREMENTS.md (Summary)
```markdown
# Product Requirements

| ID | Name | Status | Priority | Created | Updated |
|----|------|--------|----------|---------|---------|
| REQ-001 | Feature Name | PROPOSED | HIGH | 2024-01-01 | 2024-01-01 |
...

## Status Breakdown
- Proposed: N
- In Progress: N
- Code Review: N
- Merged: N
- Deployed: N
- Blocked: N
```

### docs/STATUS.md (Kanban Board)
```markdown
# Project Status

## PROPOSED (3)
- REQ-001: Feature A
- REQ-002: Feature B
- REQ-003: Bug Fix

## IN_PROGRESS (2)
- REQ-004: User Dashboard (Worktree: feature/REQ-004-dashboard)
- REQ-005: Auth System (Worktree: feature/REQ-005-auth)

## CODE_REVIEW (1)
- REQ-006: API Integration

## MERGED (2)
- REQ-007: Database Schema
- REQ-008: CI/CD Setup

## DEPLOYED (1)
- REQ-009: Initial Release

## BLOCKED (0)

## BACKLOG (0)

## CANCELLED (0)

---

### Stats
- Total Requirements: 9
- Completion Rate: 22% (2/9 deployed)
- In Progress: 22% (2/9)
```

### docs/ROADMAP.md (Timeline)
```markdown
# Roadmap

## Q1 2024
- [ ] REQ-001: Phase 1 Foundation
- [ ] REQ-002: Phase 1 Foundation
- [ ] REQ-003: Phase 1 Polish

## Q2 2024
- [ ] REQ-004: Phase 2 Features
- [ ] REQ-005: Phase 2 Features

## Q3 2024+
- [ ] REQ-006: Phase 3 Expansion
```

### docs/DEPENDENCIES.md (Graph)
```
REQ-001 (Auth)
  ├─ REQ-002 (User Model)
  │  └─ REQ-003 (Database)
  └─ REQ-004 (Login UI)

REQ-005 (Dashboard)
  └─ REQ-001 (Auth) ← must complete before dashboard
```

---

## Slash Commands

Use `/requirement-tracker` to load this skill directly. Specific commands such as `/add-requirement` need their own prompt files to appear after typing `/` in chat.

### `/add-requirement "Name" "Description" [priority]`
Submit a new product requirement

### `/show-requirement <req-id>`
Display detailed requirement information

### `/update-requirement <req-id> <new-status>`
Change requirement status

### `/list-requirements [status]`
List all requirements, optionally filtered by status

### `/dependency-graph`
Visualize requirement dependencies

### `/roadmap`
Show timeline view

### `/status`
Display comprehensive project status dashboard

### `/regen-docs`
Force regeneration of all documentation

---

## Best Practices

1. **Be specific in descriptions** — vague requirements lead to rework
2. **Set priorities early** — helps agent triage and sequence work
3. **Link dependencies** — prevents blocked work downstream
4. **Visit `/status` regularly** — catch bottlenecks early
5. **Keep specs updated** — sync with actual implementation
6. **Use tags for grouping** — if implementing requirements in batches
