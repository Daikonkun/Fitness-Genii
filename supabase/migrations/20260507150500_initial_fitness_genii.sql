create extension if not exists pgcrypto;

create schema if not exists app_private;
revoke all on schema app_private from anon, authenticated;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  role text not null default 'user' check (role in ('admin', 'user')),
  created_at timestamptz not null default now()
);

create table if not exists public.body_status (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade unique,
  gender text,
  age integer check (age between 10 and 100),
  height_cm numeric(5, 2) check (height_cm between 80 and 240),
  weight_kg numeric(6, 2) check (weight_kg between 20 and 300),
  injury text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.weight_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  weight_kg numeric(6, 2) not null check (weight_kg between 20 and 300),
  logged_on date not null,
  created_at timestamptz not null default now(),
  unique (user_id, logged_on)
);

create table if not exists public.exercise_targets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade unique,
  target_type text not null check (target_type in ('general_fitness', 'weight_loss', 'strength')),
  goal_description text not null default '',
  exercise_minutes integer not null default 30 check (exercise_minutes between 10 and 180),
  focus text,
  equipment text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.daily_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  target_id uuid references public.exercise_targets(id) on delete set null,
  plan_date date not null,
  plan_markdown text not null,
  status text not null default 'generated' check (status in ('generated', 'regenerated', 'executed', 'unfinished')),
  completion_percentage integer not null default 0 check (completion_percentage between 0 and 100),
  feedback text,
  model text not null default 'openai/gpt-5.5',
  prompt_inputs jsonb not null default '{}'::jsonb,
  generated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (user_id, plan_date)
);

create table if not exists public.exercise_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plan_id uuid references public.daily_plans(id) on delete set null unique,
  record_date date not null,
  activity_summary text not null,
  duration_minutes integer not null default 0 check (duration_minutes between 0 and 240),
  completion_percentage integer not null default 0 check (completion_percentage between 0 and 100),
  status text not null check (status in ('executed', 'unfinished')),
  created_at timestamptz not null default now()
);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists touch_body_status_updated_at on public.body_status;
create trigger touch_body_status_updated_at
before update on public.body_status
for each row execute function public.touch_updated_at();

drop trigger if exists touch_exercise_targets_updated_at on public.exercise_targets;
create trigger touch_exercise_targets_updated_at
before update on public.exercise_targets
for each row execute function public.touch_updated_at();

alter table public.profiles enable row level security;
alter table public.body_status enable row level security;
alter table public.weight_logs enable row level security;
alter table public.exercise_targets enable row level security;
alter table public.daily_plans enable row level security;
alter table public.exercise_records enable row level security;

grant usage on schema public to authenticated;
grant select, insert, update, delete on public.profiles to authenticated;
grant select, insert, update, delete on public.body_status to authenticated;
grant select, insert, update, delete on public.weight_logs to authenticated;
grant select, insert, update, delete on public.exercise_targets to authenticated;
grant select, insert, update, delete on public.daily_plans to authenticated;
grant select, insert, update, delete on public.exercise_records to authenticated;

create policy "Users can read own profile" on public.profiles
  for select using (auth.uid() = id);

create policy "Users can manage own profile" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

create policy "Users can manage own body status" on public.body_status
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Users can manage own weight logs" on public.weight_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Users can manage own exercise targets" on public.exercise_targets
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Users can manage own daily plans" on public.daily_plans
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Users can manage own exercise records" on public.exercise_records
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create or replace function app_private.create_profile_for_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do update set email = excluded.email;
  return new;
end;
$$;

drop trigger if exists create_profile_for_new_user on auth.users;
create trigger create_profile_for_new_user
after insert on auth.users
for each row execute function app_private.create_profile_for_new_user();
