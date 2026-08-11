# Fitness Genii deployment

## Supabase

1. Create a free-tier Supabase project.
2. In Authentication settings, disable public self-signup if users must only be assigned by the app admin.
3. Apply the SQL files in `supabase/migrations/` in filename order with the Supabase SQL editor or the Supabase CLI.
   For an existing deployment, apply `20260806090000_interactive_workouts.sql`, deploy the new app, and then apply `20260806090100_enable_plan_revisions.sql`. The first phase preserves the legacy one-plan-per-day upsert while the application changes over; the second phase enables retained same-day revisions.
4. Create users from the Supabase dashboard under Authentication. Those assigned users can sign in at `/login`.
5. Copy the project URL, anon key, and service role key into Vercel environment variables.

## OpenRouter

Create an OpenRouter API key and set:

- `OPENROUTER_API_KEY`
- `OPENROUTER_MODEL=openai/gpt-5.5`

The app calls OpenRouter server-side at `/api/plans/generate`, using the Chat Completions endpoint.

## Vercel

1. Import the GitHub repository into Vercel on the free tier.
2. Set all variables from `.env.example`.
3. Set `CRON_SECRET` to a random string. Vercel Cron calls `/api/cron/finalize-unfinished` at `16:05 UTC`, which is `00:05` in Hong Kong, to mark prior-day unexecuted generated plans as unfinished.
4. Keep the project runtime on Node.js 24, matching `package.json` and CI.

### Guarded release

Run the application QA gate before creating a deployment:

```bash
npm test
npm run test:supabase
npm run lint
npm run build
npm run typecheck
```

Build and deploy one immutable Preview artifact:

```bash
vercel pull --yes --environment=preview
vercel build
vercel deploy --prebuilt --yes
```

Verify the Preview URL. Public previews can use the complete smoke runner; protected previews must be checked with an authenticated Vercel CLI session or a configured deployment-protection bypass token.

```bash
npm run smoke -- https://preview-url.vercel.app
```

Production promotion must point the production aliases at the verified Preview artifact without rebuilding it:

```bash
vercel promote https://preview-url.vercel.app
npm run smoke -- https://fitness-genii.vercel.app
vercel logs --project fitness-genii --environment production --level error --since 1h --no-branch
```

Do not close a reachability incident based only on a `READY` deployment state. Require successful DNS/TLS, `/api/health/live`, `/api/health/ready`, root redirect, login asset, protected-route, and post-promotion error-log checks.

### Health and monitoring contract

- `GET /api/health/live` is process-only and must stay independent of Supabase or session refresh.
- `GET /api/health/ready` performs a bounded Supabase Auth health probe and returns `503` when configuration or the dependency is unavailable.
- Both endpoints return the deployed Git commit in the response body and `X-Fitness-Genii-Commit` header.
- Configure an external uptime service from at least two network regions to check DNS, TLS, liveness, readiness, `/login`, and one static asset every minute. Retain status, response headers, latency, DNS answers, and the Vercel request ID for every failure.
- Treat an identical-commit redeploy as temporary containment until the captured evidence identifies and removes the underlying DNS, edge, runtime, or dependency failure.

## Local development

```bash
npm install
npm run dev
npm test
npm run test:supabase
```

Local generation and auth require Supabase and OpenRouter credentials in `.env.local`. The Supabase integration suite uses the isolated `SUPABASE_TEST_URL`, `SUPABASE_TEST_ANON_KEY`, and `SUPABASE_TEST_SERVICE_ROLE_KEY` variables and deletes its temporary users when it finishes.
