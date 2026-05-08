# Fitness Genii deployment

## Supabase

1. Create a free-tier Supabase project.
2. In Authentication settings, disable public self-signup if users must only be assigned by the app admin.
3. Apply the SQL files in `supabase/migrations/` in filename order with the Supabase SQL editor or the Supabase CLI.
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
4. Deploy with the default Next.js build command: `npm run build`.

## Local development

```bash
npm install
npm run dev
```

Local generation and auth require real Supabase and OpenRouter credentials in `.env.local`.
