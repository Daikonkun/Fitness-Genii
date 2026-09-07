# Exercise demonstrations

New generated plans use catalogue version 3 and plan schema version 3. All 35 IDs in
`src/lib/exercises/catalogue.ts` have authored SVG key poses in `poses.ts`. These
are original diagrams rendered locally, with no remote media, generated video,
or paid animation API. IDs identify exact variants: do not reuse an ID for a
materially different movement. Extend the database allowlist and tests when
adding an exercise.

The catalogue supplies authoritative names and movement instructions; the model
selects IDs and prescribes sets, repetitions, rest and duration. It must return an
explicit unavailable response when the library cannot meet user constraints.
Injury/equipment suitability remains part of the coaching model's selection;
ID validation guarantees catalogue coverage, not medical suitability.

Historical v2 items are left intact. Demonstrations without a saved ID require
both exact canonical titles and exact canonical descriptions, deliberately
excluding ambiguous variants. Legacy Markdown rendering is unchanged.

## Local verification

Use Node 24 and the locked dependencies. Run `npm test`, `npm run typecheck`,
`npm run lint`, and `npm run build`. `npm run test:supabase` uses the existing
`SUPABASE_TEST_URL`, `SUPABASE_TEST_ANON_KEY`, and
`SUPABASE_TEST_SERVICE_ROLE_KEY` variables; point them at an isolated local
Supabase stack with all migrations applied. It creates and removes test users.

With `npm run dev`, open `/dev/exercises` to review all 35 illustrations,
completed/read-only cards, keyboard expansion, playback and reduced motion.
This route returns not found in production. Normal workouts use the same
WorkoutPlan / PlanItemCard components. The demonstration speed control never
changes the workout prescription or stopwatch.

Tests cover ID coverage, interpolation bounds, canonicalization, unsupported
responses without writes, historical compatibility, v2/v3 persistence, timer
switching, RLS and invalid-revision rollback. Browser checks additionally cover
one expanded card, animation pause/resume, hidden-page suspension, half speed,
mobile overflow and reduced-motion static poses. Provider responses in route
tests are fixtures; no live OpenRouter call is required by this suite.

## Review references

The [ACE exercise library](https://www.acefitness.org/resources/everyone/exercise-library/)
is retained with each catalogue entry as a movement-review starting point.
The drawings and bilingual wording are original; they are not ACE artwork or
an endorsement. Review each specific movement and its support/equipment before
changing its key poses. Front, side, and three-quarter views are schematic;
near and far limbs use different fill/stroke colors. Held movements demonstrate
entry, a hold, and release; the loop is not a prescribed hold duration.

## Release order

1. Apply `20260907090000_exercise_demonstrations.sql` before deploying the app.
   It adds nullable IDs and updates the invoker revision function; old callers
   still write v2. Invalid or mixed IDs roll back the full transaction.
2. Deploy the application and smoke-test generation, regeneration, saved IDs,
   current/historical demonstrations and stopwatch behavior.
3. Application rollback can retain the additive migration and saved v3 records;
   old clients ignore the extra field. Do not remove IDs or rewrite plan history.

No production migration or deployment is included in this change.

Handled-tube setup selection, historical compatibility findings, and the forward migration are described in [handled-tube-review.md](handled-tube-review.md).
