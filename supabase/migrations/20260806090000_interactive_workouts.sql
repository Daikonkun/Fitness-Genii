alter table public.daily_plans
  add column if not exists plan_json jsonb,
  add column if not exists schema_version integer not null default 1,
  add column if not exists revision integer not null default 1,
  add column if not exists is_current boolean not null default true,
  add column if not exists superseded_at timestamptz;

alter table public.exercise_records
  add column if not exists duration_seconds integer not null default 0
  check (duration_seconds between 0 and 86400);

update public.exercise_records
set duration_seconds = duration_minutes * 60
where duration_seconds = 0 and duration_minutes > 0;

alter table public.daily_plans drop constraint if exists daily_plans_status_check;
alter table public.daily_plans
  add constraint daily_plans_status_check
  check (status in ('generated', 'regenerated', 'in_progress', 'executed', 'unfinished', 'superseded'));

create table if not exists public.plan_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plan_id uuid not null references public.daily_plans(id) on delete cascade,
  section_type text not null check (section_type in ('warm_up', 'main_workout', 'cool_down')),
  section_title_en text not null,
  section_title_zh text not null,
  section_position integer not null check (section_position >= 0),
  item_position integer not null check (item_position >= 0),
  title_en text not null,
  title_zh text not null,
  description_en text not null,
  description_zh text not null,
  prescription text not null,
  planned_seconds integer not null default 0 check (planned_seconds between 0 and 10800),
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (plan_id, section_position, item_position)
);

create table if not exists public.exercise_intervals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plan_item_id uuid not null references public.plan_items(id) on delete cascade,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  duration_seconds integer not null default 0 check (duration_seconds between 0 and 86400),
  stop_reason text check (stop_reason in ('pause', 'switch', 'done', 'regenerate', 'finish', 'day_end')),
  created_at timestamptz not null default now(),
  check ((ended_at is null and stop_reason is null) or (ended_at is not null and stop_reason is not null))
);

create index if not exists idx_plan_items_plan_id on public.plan_items(plan_id);
create index if not exists idx_plan_items_user_id on public.plan_items(user_id);
create index if not exists idx_exercise_intervals_item_id on public.exercise_intervals(plan_item_id);
create index if not exists idx_exercise_intervals_user_id on public.exercise_intervals(user_id);
create unique index if not exists exercise_intervals_one_active_per_user_key
  on public.exercise_intervals(user_id)
  where ended_at is null;

alter table public.plan_items enable row level security;
alter table public.exercise_intervals enable row level security;

grant select, insert, update, delete on public.plan_items to authenticated;
grant select, insert, update, delete on public.exercise_intervals to authenticated;
revoke all on public.plan_items from anon;
revoke all on public.exercise_intervals from anon;

grant usage on schema public to service_role;
grant all on table
  public.profiles,
  public.body_status,
  public.weight_logs,
  public.exercise_targets,
  public.daily_plans,
  public.exercise_records,
  public.plan_items,
  public.exercise_intervals
to service_role;

create policy "Users can manage own plan items" on public.plan_items
  for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create policy "Users can manage own exercise intervals" on public.exercise_intervals
  for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create or replace function public.create_structured_plan_revision(
  p_target_id uuid,
  p_plan_date date,
  p_plan_json jsonb,
  p_plan_markdown text,
  p_feedback text,
  p_model text,
  p_prompt_inputs jsonb
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_plan_id uuid;
  v_previous_plan_id uuid;
  v_revision integer;
  v_section jsonb;
  v_item jsonb;
  v_section_position integer;
  v_item_position integer;
begin
  if v_user_id is null then
    raise exception 'Unauthorized';
  end if;

  if p_target_id is not null and not exists (
    select 1 from public.exercise_targets
    where id = p_target_id and user_id = v_user_id
  ) then
    raise exception 'Invalid exercise target';
  end if;

  if jsonb_typeof(p_plan_json -> 'sections') is distinct from 'array' then
    raise exception 'Invalid structured plan';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text || ':' || p_plan_date::text, 0));

  select id into v_previous_plan_id
  from public.daily_plans
  where user_id = v_user_id and plan_date = p_plan_date and is_current
  for update;

  if v_previous_plan_id is not null then
    update public.exercise_intervals interval_row
    set ended_at = now(),
        duration_seconds = greatest(0, floor(extract(epoch from (now() - interval_row.started_at)))::integer),
        stop_reason = 'regenerate'
    where interval_row.user_id = v_user_id
      and interval_row.ended_at is null
      and exists (
        select 1 from public.plan_items item
        where item.id = interval_row.plan_item_id and item.plan_id = v_previous_plan_id
      );

    delete from public.plan_items
    where plan_id = v_previous_plan_id and user_id = v_user_id;

    update public.daily_plans
    set target_id = p_target_id,
        plan_markdown = p_plan_markdown,
        plan_json = p_plan_json,
        schema_version = 2,
        revision = revision + 1,
        is_current = true,
        status = 'regenerated',
        completion_percentage = 0,
        feedback = nullif(trim(p_feedback), ''),
        model = p_model,
        prompt_inputs = p_prompt_inputs,
        generated_at = now(),
        superseded_at = null
    where id = v_previous_plan_id
    returning id, revision into v_plan_id, v_revision;
  else
    v_revision := 1;

    insert into public.daily_plans (
      user_id,
      target_id,
      plan_date,
      plan_markdown,
      plan_json,
      schema_version,
      revision,
      is_current,
      status,
      completion_percentage,
      feedback,
      model,
      prompt_inputs,
      generated_at
    ) values (
      v_user_id,
      p_target_id,
      p_plan_date,
      p_plan_markdown,
      p_plan_json,
      2,
      v_revision,
      true,
      'generated',
      0,
      nullif(trim(p_feedback), ''),
      p_model,
      p_prompt_inputs,
      now()
    ) returning id into v_plan_id;
  end if;

  for v_section, v_section_position in
    select value, (ordinality - 1)::integer
    from jsonb_array_elements(p_plan_json -> 'sections') with ordinality
  loop
    for v_item, v_item_position in
      select value, (ordinality - 1)::integer
      from jsonb_array_elements(v_section -> 'items') with ordinality
    loop
      insert into public.plan_items (
        user_id,
        plan_id,
        section_type,
        section_title_en,
        section_title_zh,
        section_position,
        item_position,
        title_en,
        title_zh,
        description_en,
        description_zh,
        prescription,
        planned_seconds
      ) values (
        v_user_id,
        v_plan_id,
        v_section ->> 'section_type',
        v_section ->> 'title_en',
        v_section ->> 'title_zh',
        v_section_position,
        v_item_position,
        v_item ->> 'title_en',
        v_item ->> 'title_zh',
        v_item ->> 'description_en',
        v_item ->> 'description_zh',
        v_item ->> 'prescription',
        coalesce((v_item ->> 'planned_seconds')::integer, 0)
      );
    end loop;
  end loop;

  return v_plan_id;
end;
$$;

create or replace function public.toggle_plan_item_timer(p_plan_item_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_plan_id uuid;
  v_active_item_id uuid;
  v_interval_id uuid;
begin
  if v_user_id is null then
    raise exception 'Unauthorized';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text, 0));

  select item.plan_id into v_plan_id
  from public.plan_items item
  join public.daily_plans plan on plan.id = item.plan_id
  where item.id = p_plan_item_id
    and item.user_id = v_user_id
    and plan.user_id = v_user_id
    and plan.is_current
    and plan.status <> 'executed'
    and plan.plan_date = (now() at time zone 'Asia/Hong_Kong')::date;

  if v_plan_id is null then
    raise exception 'Plan item is not editable';
  end if;

  select plan_item_id into v_active_item_id
  from public.exercise_intervals
  where user_id = v_user_id and ended_at is null
  for update;

  update public.exercise_intervals interval_row
  set ended_at = now(),
      duration_seconds = greatest(0, floor(extract(epoch from (now() - interval_row.started_at)))::integer),
      stop_reason = case when interval_row.plan_item_id = p_plan_item_id then 'pause' else 'switch' end
  where interval_row.user_id = v_user_id and interval_row.ended_at is null;

  if v_active_item_id = p_plan_item_id then
    return jsonb_build_object('state', 'paused', 'plan_item_id', p_plan_item_id);
  end if;

  insert into public.exercise_intervals (user_id, plan_item_id)
  values (v_user_id, p_plan_item_id)
  returning id into v_interval_id;

  update public.daily_plans
  set status = 'in_progress'
  where id = v_plan_id and status in ('generated', 'regenerated');

  return jsonb_build_object(
    'state', 'active',
    'plan_item_id', p_plan_item_id,
    'interval_id', v_interval_id
  );
end;
$$;

create or replace function public.set_plan_item_done(p_plan_item_id uuid, p_done boolean)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_plan_id uuid;
begin
  if v_user_id is null then
    raise exception 'Unauthorized';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text, 0));

  select item.plan_id into v_plan_id
  from public.plan_items item
  join public.daily_plans plan on plan.id = item.plan_id
  where item.id = p_plan_item_id
    and item.user_id = v_user_id
    and plan.is_current
    and plan.status <> 'executed'
    and plan.plan_date = (now() at time zone 'Asia/Hong_Kong')::date;

  if v_plan_id is null then
    raise exception 'Plan item is not editable';
  end if;

  if p_done then
    update public.exercise_intervals interval_row
    set ended_at = now(),
        duration_seconds = greatest(0, floor(extract(epoch from (now() - interval_row.started_at)))::integer),
        stop_reason = 'done'
    where interval_row.user_id = v_user_id
      and interval_row.plan_item_id = p_plan_item_id
      and interval_row.ended_at is null;
  end if;

  update public.plan_items
  set completed_at = case when p_done then coalesce(completed_at, now()) else null end
  where id = p_plan_item_id and user_id = v_user_id;

  update public.daily_plans
  set status = 'in_progress'
  where id = v_plan_id and status in ('generated', 'regenerated');

  return jsonb_build_object('plan_item_id', p_plan_item_id, 'done', p_done);
end;
$$;

create or replace function public.finish_workout(p_plan_id uuid, p_activity_summary text default null)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_plan_date date;
  v_total_items integer;
  v_completed_items integer;
  v_duration_seconds integer;
  v_completion_percentage integer;
begin
  if v_user_id is null then
    raise exception 'Unauthorized';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text, 0));

  select plan_date into v_plan_date
  from public.daily_plans
  where id = p_plan_id
    and user_id = v_user_id
    and is_current
    and plan_date = (now() at time zone 'Asia/Hong_Kong')::date
  for update;

  if v_plan_date is null then
    raise exception 'Workout is not editable';
  end if;

  update public.exercise_intervals interval_row
  set ended_at = now(),
      duration_seconds = greatest(0, floor(extract(epoch from (now() - interval_row.started_at)))::integer),
      stop_reason = 'finish'
  where interval_row.user_id = v_user_id
    and interval_row.ended_at is null
    and exists (
      select 1 from public.plan_items item
      where item.id = interval_row.plan_item_id and item.plan_id = p_plan_id
    );

  select count(*), count(*) filter (where completed_at is not null)
  into v_total_items, v_completed_items
  from public.plan_items
  where plan_id = p_plan_id and user_id = v_user_id;

  select coalesce(sum(interval_row.duration_seconds), 0)::integer
  into v_duration_seconds
  from public.exercise_intervals interval_row
  join public.plan_items item on item.id = interval_row.plan_item_id
  where item.plan_id = p_plan_id and interval_row.user_id = v_user_id;

  v_completion_percentage := case
    when v_total_items = 0 then 0
    else round((v_completed_items::numeric / v_total_items::numeric) * 100)::integer
  end;

  update public.daily_plans
  set status = 'executed', completion_percentage = v_completion_percentage
  where id = p_plan_id;

  insert into public.exercise_records (
    user_id,
    plan_id,
    record_date,
    activity_summary,
    duration_minutes,
    duration_seconds,
    completion_percentage,
    status
  ) values (
    v_user_id,
    p_plan_id,
    v_plan_date,
    coalesce(nullif(trim(p_activity_summary), ''), 'Completed a timed Fitness Genii workout.'),
    round(v_duration_seconds::numeric / 60)::integer,
    v_duration_seconds,
    v_completion_percentage,
    'executed'
  )
  on conflict (plan_id) do update set
    activity_summary = excluded.activity_summary,
    duration_minutes = excluded.duration_minutes,
    duration_seconds = excluded.duration_seconds,
    completion_percentage = excluded.completion_percentage,
    status = excluded.status;

  return jsonb_build_object(
    'duration_seconds', v_duration_seconds,
    'completed_items', v_completed_items,
    'total_items', v_total_items,
    'completion_percentage', v_completion_percentage
  );
end;
$$;

revoke execute on function public.create_structured_plan_revision(uuid, date, jsonb, text, text, text, jsonb) from public, anon;
revoke execute on function public.toggle_plan_item_timer(uuid) from public, anon;
revoke execute on function public.set_plan_item_done(uuid, boolean) from public, anon;
revoke execute on function public.finish_workout(uuid, text) from public, anon;

grant execute on function public.create_structured_plan_revision(uuid, date, jsonb, text, text, text, jsonb) to authenticated;
grant execute on function public.toggle_plan_item_timer(uuid) to authenticated;
grant execute on function public.set_plan_item_done(uuid, boolean) to authenticated;
grant execute on function public.finish_workout(uuid, text) to authenticated;
