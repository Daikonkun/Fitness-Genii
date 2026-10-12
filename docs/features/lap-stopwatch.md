# Exercise card lap stopwatch

Each card displays Total and the current Lap. Start begins both; Pause and switching exercises preserve the current lap. Lap advances its number and resets only its elapsed display. Done closes the active interval and freezes both clocks. Unmarking Done permits a manual restart and retains the same lap. No lap history is stored.

`plan_items.lap_number` and `lap_start_total_seconds` persist the lap across refreshes and devices. The latter is an offset into cumulative active seconds, so laps do not split intervals or change workout summaries. Existing items default to Lap 1 with an offset of zero.

The authenticated `advance_plan_item_lap` RPC checks ownership, current Hong Kong day, current unexecuted plan, incomplete item and running interval. It shares the existing per-user advisory lock, and requires the expected lap number to reject duplicate/stale calls. Timer and Done RPCs capture timestamps after acquiring that lock; completed items cannot restart via the timer RPC.

All card mutations are disabled while a request is pending. Uncertain or failed responses block mutations until saved state is refreshed; mutations are never automatically retried. Obsolete reads cannot overwrite a newer action.

## Validation

- `npm test`: existing tests plus lap arithmetic, frozen Done, pause and resume tests.
- `npm run test:laps:db`: starts and removes a disposable Docker PostgreSQL 17 database, loads every migration with minimal local Supabase auth roles/UID emulation, checks lap persistence, unchanged intervals, duplicate concurrency, Done race, ownership and invalid states. Requires Docker and `postgres:17-bookworm`. This does not contact hosted Supabase.
- `npm run test:laps:browser`: browser interaction against `/dev/stopwatch` on port 3012 with intercepted Supabase requests. Verifies keyboard activation, lap reset, pause/resume/switch, stale refresh, committed-but-failed response recovery, Done, reload persistence and mobile overflow. Requires Playwright (`PLAYWRIGHT_MODULE` may point to its entry module; optional `PLAYWRIGHT_CHROMIUM_EXECUTABLE`). Start the local dev server with `NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54329 NEXT_PUBLIC_SUPABASE_ANON_KEY=local-fixture npm run dev -- --port 3012`. Browser tests validate the UI/network contract separately from the real PostgreSQL tests.
- `npm run typecheck`, `npx eslint src scripts`, `npm run build`.

Full `npm run lint` currently includes old `.next-release` generated artifacts and fails on those baseline files. Source lint passes.

## Release order

Apply `supabase/migrations/20261012133025_exercise_lap_stopwatch.sql` before releasing the application. No hosted migration or deployment was performed as part of this implementation. Existing unrelated checkout changes are retained.
