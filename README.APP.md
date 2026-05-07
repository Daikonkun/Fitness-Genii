# Fitness Genii

Fitness Genii is a Vercel-ready Next.js MVP for assigned-login fitness tracking:

- Supabase Auth login for admin-created users.
- One-page dashboard for body status, exercise target, daily plan, completion logging, weight curve, and exercise records.
- Server-side OpenRouter plan generation using `openai/gpt-5.5` by default.
- Bilingual English/Chinese plan prompt with injury, equipment, focus, record history, and weight-loss trend context.
- Vercel Cron endpoint that marks prior-day generated plans as unfinished after the Hong Kong day ends.

See `DEPLOYMENT.md` for Supabase, OpenRouter, and Vercel setup.
