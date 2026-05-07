---
description: Run Vibe Master end-to-end test workflow and report visual/behavioral gaps.
---

# /vibe-master:e2e-test

## Preflight

1. Confirm `.github/prompts/e2e-test.prompt.md` exists.
2. Confirm test scope argument (if provided).

## Plan

1. Execute the existing `/e2e-test` workflow contract from prompt guidance.
2. Capture failures, evidence artifacts, and proposed follow-up REQs.

## Commands

Follow `.github/prompts/e2e-test.prompt.md` workflow and any repo test scripts it references.

## Verification

1. Test commands complete or fail with captured evidence.
2. Any proposed follow-up REQs include clear acceptance criteria.

## Summary

Return pass/fail scope, key failures, and artifact paths.

## Next Steps

Recommend `/vibe-master:bug-fix` or `/vibe-master:add-requirement` for uncovered gaps.
