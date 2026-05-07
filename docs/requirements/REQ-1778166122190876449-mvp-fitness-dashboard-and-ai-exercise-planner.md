# MVP fitness dashboard and AI exercise planner

**ID**: REQ-1778166122190876449  
**Status**: IN_PROGRESS  
**Priority**: high  
**Created**: 2026-05-07T15:02:02Z  

## Description

Build the Fitness Genii MVP as a Vercel-ready web app backed by Supabase. Admins assign user logins. Authenticated users land on a one-page dashboard where they can maintain body status (gender, age, height, weight, injury), set exercise targets (type toggle, goal description, exercise time, focus, equipment), view weight curve and exercise records, generate a customized bilingual English/Chinese daily exercise plan through OpenRouter using default model openai/gpt-5.5, provide feedback for regeneration, and mark plan execution percentage. Exercise records must store daily activities, duration, plan completion status, and unfinished plans when not executed by end of day at 23:59:59 Asia/Hong_Kong. MVP should include Supabase schema/migrations, OpenRouter API integration, responsive modern UI, and deployment documentation for free-tier Vercel/Supabase.

## Success Criteria

- [x] Supabase-backed authentication supports admin-created user accounts, with application pages protected from unauthenticated access.
- [x] Authenticated users have a single responsive dashboard for body status, exercise target inputs, AI plan generation/regeneration, weight trend, and exercise records.
- [x] Body status captures gender, age, height, weight, and optional injury notes; weight entries are stored over time for charting.
- [x] Exercise target captures type toggle, goal description, available exercise time, optional focus area, and equipment.
- [x] Daily plan generation calls OpenRouter with default model `openai/gpt-5.5` and a prompt that includes body status, target, injury, equipment, prior exercise records, and weight history when weight loss is selected.
- [x] Generated plans are bilingual English/Chinese and include move descriptions plus time, reps, or cycle guidance for each item.
- [x] Users can provide feedback and regenerate the daily plan with that feedback included in the next OpenRouter prompt.
- [x] Users can mark a generated daily plan as executed with completion percentage; daily exercise records store activity details, duration, completion status, and unfinished plans.
- [x] Plans not marked executed by `23:59:59` Asia/Hong_Kong are modeled for automatic unfinished recording through a Supabase/Vercel scheduled job.
- [x] The project includes free-tier-oriented Vercel and Supabase setup documentation, environment variable examples, and a migration schema.

## Technical Notes

- Use Next.js App Router with TypeScript for a Vercel-friendly frontend and server API routes.
- Use Supabase Auth for assigned logins; the app admin creates users from the Supabase dashboard or admin API outside the public signup flow.
- Store profile/body status, weight logs, exercise targets, generated daily plans, and exercise records in Supabase Postgres with RLS policies scoped to `auth.uid()`.
- Keep OpenRouter calls server-side only. Required env vars: `OPENROUTER_API_KEY`, `OPENROUTER_MODEL`, `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, and a server-only Supabase service role key for scheduled unfinished-plan maintenance.
- Add a Vercel cron endpoint for unfinished-plan finalization; MVP should also expose a manual-safe implementation so the behavior is clear before deployment credentials exist.


## Development Plan

1. Review Description, Success Criteria, and Technical Notes in `docs/requirements/REQ-1778166122190876449-mvp-fitness-dashboard-and-ai-exercise-planner.md`.
   - **Summary**: Build the Fitness Genii MVP as a Vercel-ready web app backed by Supabase. Admins
   - **Key criteria**: - [ ] Supabase-backed authentication supports admin-created user accounts, with application pages pr
2. Analyse Technical Notes and identify implementation approach.
   - **Notes**: - Use Next.js App Router with TypeScript for a Vercel-friendly frontend and server API routes.
3. Implement changes in the files/scripts referenced by the requirement spec.
4. Run `./scripts/regenerate-docs.sh` to update manifests and generated docs.
5. Validate with `./scripts/show-requirement.sh REQ-1778166122190876449` and verify success criteria are met.

## Verification

- `npm run lint`
- `npm run typecheck`
- `npm run build`
- `curl -I http://localhost:3000/login`

**Last updated**: 2026-05-07T15:02:39Z

## Dependencies

None.

## Worktree

(Will be populated when work starts: feature/REQ-ID-slug)

---

* **Linked Worktree**: feature/REQ-1778166122190876449-mvp-fitness-dashboard-and-ai-exercise-planner
* **Branch**: feature/REQ-1778166122190876449-mvp-fitness-dashboard-and-ai-exercise-planner
* **Merged**: No
* **Deployed**: No
