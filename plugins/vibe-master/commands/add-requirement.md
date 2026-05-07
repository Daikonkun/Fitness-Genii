---
description: Create a new requirement and regenerate project docs.
---

# /vibe-master:add-requirement

## Preflight

1. Validate input args: name, description, optional priority.
2. Ensure `scripts/create-requirement.sh` exists.

## Plan

1. Run `scripts/create-requirement.sh` with `--no-commit`.
2. Enrich generated requirement spec if placeholders remain.
3. Run `scripts/regenerate-docs.sh`.

## Commands

- `scripts/create-requirement.sh "<name>" "<description>" [priority] --no-commit`
- `scripts/regenerate-docs.sh`

## Verification

1. New REQ appears in `.requirement-manifest.json`.
2. Corresponding file exists in `docs/requirements/`.
3. `REQUIREMENTS.md` and `docs/STATUS.md` include the new REQ.

## Summary

Return new REQ ID and spec path.

## Next Steps

Recommend `/vibe-master:start-work <REQ-ID>`.
