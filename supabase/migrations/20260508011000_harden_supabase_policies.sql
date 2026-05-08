create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create index if not exists idx_daily_plans_target_id on public.daily_plans(target_id);
create index if not exists idx_exercise_records_user_id on public.exercise_records(user_id);

drop policy if exists "Users can read own profile" on public.profiles;
drop policy if exists "Users can manage own profile" on public.profiles;
drop policy if exists "Users can manage own body status" on public.body_status;
drop policy if exists "Users can manage own weight logs" on public.weight_logs;
drop policy if exists "Users can manage own exercise targets" on public.exercise_targets;
drop policy if exists "Users can manage own daily plans" on public.daily_plans;
drop policy if exists "Users can manage own exercise records" on public.exercise_records;

create policy "Users can read own profile" on public.profiles
  for select using ((select auth.uid()) = id);

create policy "Users can manage own profile" on public.profiles
  for update using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

create policy "Users can manage own body status" on public.body_status
  for all using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create policy "Users can manage own weight logs" on public.weight_logs
  for all using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create policy "Users can manage own exercise targets" on public.exercise_targets
  for all using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create policy "Users can manage own daily plans" on public.daily_plans
  for all using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create policy "Users can manage own exercise records" on public.exercise_records
  for all using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
