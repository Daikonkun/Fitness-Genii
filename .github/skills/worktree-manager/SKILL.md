---
name: worktree-manager
description: "Manages git worktrees for parallel development. Use when: creating worktrees for requirements, managing multiple features, pruning abandoned worktrees, checking worktree status, or orchestrating merges."
---

# Worktree Manager Skill

Automated management of git worktrees to enable safe, isolated parallel development.

## Core Commands

### List Active Worktrees
```bash
git worktree list --porcelain
```
Returns: `path branch detached`

### Create a New Worktree
```bash
git worktree add <path> -b <branch>
```

Example:
```bash
git worktree add ../feature/REQ-001-auth-system -b feature/REQ-001-auth-system
```

### Remove a Worktree
```bash
git worktree remove <path>
```

### Prune Dead Worktrees
```bash
git worktree prune
```

---

## Orchestrator Functions

### 1. Create Worktree for Requirement

**When to use**: User starts work on a requirement

**Input**:
- Requirement ID (REQ-XXX)
- Base branch (main/develop)
- Requirement name

**Output**:
- Worktree path
- Branch name
- Updated `.worktree-manifest.json`

**Implementation**:
```bash
#!/bin/bash
REQ_ID=$1
SLUG=$2
BASE_BRANCH=${3:-main}
PROJECT_ROOT=$(git rev-parse --show-toplevel)

# Branch name format: feature/REQ-001-auth-system
BRANCH_NAME="feature/${REQ_ID}-${SLUG}"
WORKTREE_PATH="${PROJECT_ROOT}/../${BRANCH_NAME}"

# Create worktree
git worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME" "$BASE_BRANCH"

# Update manifest
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq --arg id "$BRANCH_NAME" \
   --arg path "$WORKTREE_PATH" \
   --arg branch "$BRANCH_NAME" \
   --arg base "$BASE_BRANCH" \
   --arg reqId "$REQ_ID" \
   --arg ts "$TIMESTAMP" \
   '.worktrees += [{
     id: $id,
     path: $path,
     branch: $branch,
     baseBranch: $base,
     requirementIds: [$reqId],
     createdAt: $ts,
     status: "ACTIVE"
   }]' .worktree-manifest.json > .worktree-manifest.json.tmp && \
  mv .worktree-manifest.json.tmp .worktree-manifest.json

echo "Worktree created: $WORKTREE_PATH"
```

### 2. List All Worktrees with Requirements

**Output**: Table of active worktrees and linked requirements

```bash
#!/bin/bash
echo "Active Worktrees:"
echo "================"

jq -r '.worktrees[] | select(.status == "ACTIVE") | 
  "Branch: \(.branch)\nPath: \(.path)\nRequirements: \(.requirementIds | join(", "))\n"' \
  .worktree-manifest.json
```

### 3. Merge and Cleanup

**When to use**: User completes work and wants to merge

**Input**: Requirement ID or branch name

**Steps**:
1. Check out base branch
2. Merge feature branch (with squash option available)
3. Delete remote branch
4. Remove local worktree
5. Update both requirement and worktree manifests
6. Regenerate documentation

```bash
#!/bin/bash
BRANCH=$1
BASE_BRANCH=${2:-main}

# Ensure clean state
cd "$(git rev-parse --show-toplevel)"

# Get worktree info
WORKTREE_PATH=$(jq -r --arg branch "$BRANCH" '.worktrees[] | select(.branch == $branch) | .path' .worktree-manifest.json)
REQ_IDS=$(jq -r --arg branch "$BRANCH" '.worktrees[] | select(.branch == $branch) | .requirementIds[]' .worktree-manifest.json)

# Merge
git checkout $BASE_BRANCH
git merge --no-ff $BRANCH -m "Merge $BRANCH"

# Cleanup
git worktree remove "$WORKTREE_PATH" 2>/dev/null || true
git branch -d $BRANCH

# Update manifests
MERGE_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq --arg branch "$BRANCH" --arg ts "$MERGE_TS" \
   '.worktrees[] |= if .branch == $branch then .status = "MERGED" | .mergedAt = $ts else . end' \
  .worktree-manifest.json > .worktree-manifest.json.tmp && \
  mv .worktree-manifest.json.tmp .worktree-manifest.json

# Update requirement status
for REQ_ID in $REQ_IDS; do
  jq --arg id "$REQ_ID" --arg ts "$MERGE_TS" \
     '.requirements[] |= if .id == $id then .status = "MERGED" | .updatedAt = $ts else . end' \
    .requirement-manifest.json > .requirement-manifest.json.tmp && \
    mv .requirement-manifest.json.tmp .requirement-manifest.json
done

echo "Merged $BRANCH and cleaned up worktree"
```

### 4. Detect Conflicts

Check if multiple requirements modify the same files:

```bash
#!/bin/bash
REQ_1=$1
REQ_2=$2

BRANCH_1=$(jq -r --arg id "$REQ_1" '.worktrees[] | select(.requirementIds[] == $id) | .branch' .worktree-manifest.json)
BRANCH_2=$(jq -r --arg id "$REQ_2" '.worktrees[] | select(.requirementIds[] == $id) | .branch' .worktree-manifest.json)

# Show conflicting files
git diff --name-only $BRANCH_1..$BRANCH_2
```

---

## Slash Commands

### `/worktree-create <req-id>`
Create a worktree for the given requirement

### `/worktree-list`
List all active worktrees with their linked requirements

### `/worktree-merge <branch>`
Merge a feature branch and clean up its worktree

### `/worktree-prune`
Remove orphaned/dead worktrees

### `/worktree-status`
Show comprehensive worktree status dashboard

---

## Best Practices

1. **One worktree per major feature** — avoid mixing independent requirements
2. **Group related features** — if REQ-001 and REQ-002 are tightly coupled, use one worktree with both IDs
3. **Check conflicts before creating** — use `/worktree-status` to see potential merge conflicts
4. **Clean immediately after merge** — keeps filesystem and manifests in sync
5. **Use meaningful branch names** — `feature/REQ-001-auth-system` is clearer than `feature/work1`
