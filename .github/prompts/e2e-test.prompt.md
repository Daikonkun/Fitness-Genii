---
name: "e2e-test"
description: "Run end-to-end testing with screenshot-based cross-border visual validation; propose new skill REQs when gaps are found."
argument-hint: "[scope]"
agent: "Vibe Agent Orchestrator"
---

Perform an end-to-end test of a vibe-master project, leveraging existing skills and surfacing gaps. Includes screenshot-based cross-border testing to detect visual regressions at UI transition boundaries.

Workflow:
1. **Parse scope**: Accept an optional `[scope]` argument — a requirement ID (e.g., `REQ-1234567890`), a feature area name, or nothing (implies whole project). If scope is a requirement ID, validate it exists in `.requirement-manifest.json`.
2. **Inventory skills**: Read every `.github/skills/*/SKILL.md` file and collect each skill's `name` and `description` from the YAML frontmatter. Build a capability list from these descriptions.
3. **Define e2e test requirements**: An end-to-end test needs these capabilities:
   - **Build / lint**: compile or lint the project source
   - **Test execution**: run unit, integration, or e2e test suites
   - **Screenshot-capable test runner**: capture screenshots at UI boundaries for visual regression detection (e.g., Playwright with `page.screenshot()`, Cypress with `cy.screenshot()`, Selenium)
   - **Code review**: static analysis and pattern review
   - **Requirement validation**: verify that acceptance criteria from the spec are met
   - **Manual / docs check**: confirm documentation is up to date
4. **Detect UI framework**: Before gap analysis, determine whether the project has a UI:
   - Check for UI framework indicators: `playwright.config.*`, `cypress.config.*`, `selenium` in dependencies, or front-end framework packages (React, Vue, Angular, Svelte, etc.) in `package.json`, `requirements.txt`, or similar dependency files.
   - If **no UI framework is detected**, mark the screenshot capability as **not applicable** and skip the cross-border screenshot phase entirely. Proceed with the remaining e2e test cycle.
   - If **a UI framework is detected but no screenshot-capable test runner** (Playwright, Cypress with screenshot plugin, Selenium, etc.), mark the screenshot capability as **missing** and include it in the gap analysis (step 6).
5. **Gap analysis**: Compare the capability list (step 2) against the e2e test requirements (step 3), taking into account the UI detection result (step 4). Classify each requirement as **covered**, **missing**, or **not applicable** (for screenshot capability when no UI is present).
6. **If all applicable capabilities are covered** — orchestrate the full e2e cycle:
   a. Invoke the build/lint skill to compile or lint the project source.
   b. Invoke the test-execution skill to run the test suite.
   c. **Screenshot capture & cross-border validation** (only if UI framework was detected in step 4):
      - **Identify UI borders**: Scan the codebase for UI transition points — route definitions (e.g., React Router `<Route>`, Vue Router routes), modal/dialog triggers, form submission handlers, navigation links, and component boundary crossings in SPAs. Enumerate the discovered borders.
      - **Capture screenshots**: At each identified border, use the project's test runner screenshot API (Playwright `page.screenshot()`, Cypress `cy.screenshot()`, etc.) to capture a screenshot immediately after the transition occurs.
      - **Store screenshots**: Save screenshots under `docs/e2e-screenshots/{scope}/current/` using the naming convention `{border-name}-{timestamp}.png` (e.g., `login-to-dashboard-20260413T064200Z.png`). Create the directory if it does not exist.
      - **Baseline comparison**: Check if a baseline exists at `docs/e2e-screenshots/{scope}/baselines/`. If no baseline exists, copy the current screenshot as the baseline and note it as a **new baseline** in the report. If a baseline exists, compare the current screenshot against it. Flag any visual drift (pixel-level differences) and include the diff in the pass/fail summary. If no dedicated diff tool is available, propose an appropriate one based on the project stack (e.g., `pixelmatch` for Node.js, `Pillow` for Python), and mark the comparison result as **inconclusive — manual review required** rather than pass or fail.
      - **Report results**: Include a screenshot comparison section in the pass/fail summary listing each border, whether a baseline existed, whether a visual drift was detected, and the file paths of current/baseline/diff images.
   d. Run `/code-review [scope]` to perform a code review.
   e. If scope is a requirement ID, read its spec and verify each Success Criterion is satisfied.
   f. Report a **pass / fail** summary with evidence for each step, including the screenshot comparison results.
7. **If any capability is missing** — for each gap:
   a. Explain what capability is missing and why it blocks e2e testing.
   b. Construct a concrete `/add-requirement` invocation that would create a new skill to fill the gap. Examples:
      ```
      /add-requirement "test-runner skill" "Create a test-runner skill for vibe master that can discover and execute unit/integration/e2e test suites, report results, and integrate with the e2e-test command." HIGH
      /add-requirement "screenshot-test-runner skill" "Create a screenshot-test-runner skill for vibe master that can capture screenshots at UI boundaries using Playwright/Cypress, compare against baselines, and report visual regressions." HIGH
      ```
   c. Present the proposed `/add-requirement` to the user for approval. Do not auto-create.
8. **Summarize**: Report which capabilities were covered, which had gaps, what tests passed/failed, screenshot comparison results (if applicable), and any proposed new REQs.

Constraints:
- Never assume a test framework exists — verify by checking for config files (e.g., `jest.config.*`, `pytest.ini`, `vitest.config.*`, `package.json` scripts) before attempting to run tests.
- Never assume a screenshot-capable test runner exists — verify by checking for Playwright, Cypress, or Selenium config files and dependencies before attempting screenshot capture.
- If scope is ambiguous or the project type is unclear, ask the user to clarify rather than guessing.
- Do not auto-create requirements for missing skills — always present proposals and wait for approval.
- Surface any failures with exact error output.
- When a gap is found, the proposed `/add-requirement` must include a clear description with acceptance criteria so the resulting REQ is actionable.
- Screenshot baselines are environment-dependent (OS, browser, resolution) — note this in the report and recommend running e2e tests in a consistent CI environment to avoid false-positive drift.
- If the project has no UI framework, skip the entire screenshot/cross-border phase without reporting it as a gap.
- Large screenshot sets may bloat the repository — consider adding `docs/e2e-screenshots/*/current/` to `.gitignore` and only committing baselines, or using artifact storage in CI.
