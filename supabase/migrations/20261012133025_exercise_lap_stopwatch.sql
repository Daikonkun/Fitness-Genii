-- Lap boundaries use cumulative active seconds; existing intervals and summaries stay intact.
alter table public.plan_items
  add column lap_number integer not null default 1 check (lap_number >= 1),
  add column lap_start_total_seconds integer not null default 0 check (lap_start_total_seconds >= 0);

create or replace function public.advance_plan_item_lap(
  p_plan_item_id uuid,
  p_expected_lap_number integer
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_item public.plan_items%rowtype;
  v_now timestamptz;
  v_total integer;
begin
  if v_user_id is null then
    raise exception 'Unauthorized';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text, 0));
  v_now := clock_timestamp();

  select item.* into v_item
  from public.plan_items item
  join public.daily_plans plan on plan.id = item.plan_id
  where item.id = p_plan_item_id
    and item.user_id = v_user_id
    and plan.user_id = v_user_id
    and item.completed_at is null
    and plan.is_current
    and plan.status <> 'executed'
    and plan.plan_date = (v_now at time zone 'Asia/Hong_Kong')::date
  for update of item;

  if not found then
    raise exception 'Plan item is not editable';
  end if;
  if p_expected_lap_number is distinct from v_item.lap_number then
    raise exception 'Lap has changed. Refresh the stopwatch.';
  end if;
  if not exists (
    select 1 from public.exercise_intervals
    where plan_item_id = p_plan_item_id and user_id = v_user_id and ended_at is null
  ) then
    raise exception 'Start the stopwatch before adding a lap';
  end if;

  select coalesce(sum(case when ended_at is null
    then greatest(0, floor(extract(epoch from (v_now - started_at)))::integer)
    else duration_seconds end), 0)::integer into v_total
  from public.exercise_intervals
  where plan_item_id = p_plan_item_id and user_id = v_user_id;

  update public.plan_items
  set lap_number = lap_number + 1, lap_start_total_seconds = v_total
  where id = p_plan_item_id;
  return jsonb_build_object('plan_item_id', p_plan_item_id,
    'lap_number', v_item.lap_number + 1, 'lap_start_total_seconds', v_total);
end;
$$;

-- Capture one timestamp after the shared lock, so concurrent actions cannot backdate a stop.
create or replace function public.toggle_plan_item_timer(p_plan_item_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_plan_id uuid;
  v_now timestamptz;
  v_active_item_id uuid;
  v_interval_id uuid;
begin
  if v_user_id is null then
    raise exception 'Unauthorized';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text, 0));
  v_now := clock_timestamp();

  select item.plan_id into v_plan_id
  from public.plan_items item
  join public.daily_plans plan on plan.id = item.plan_id
  where item.id = p_plan_item_id
    and item.user_id = v_user_id
    and item.completed_at is null
    and plan.user_id = v_user_id
    and plan.is_current
    and plan.status <> 'executed'
    and plan.plan_date = (v_now at time zone 'Asia/Hong_Kong')::date;

  if v_plan_id is null then
    raise exception 'Plan item is not editable';
  end if;

  select plan_item_id into v_active_item_id
  from public.exercise_intervals
  where user_id = v_user_id and ended_at is null
  for update;

  update public.exercise_intervals interval_row
  set ended_at = v_now,
      duration_seconds = greatest(0, floor(extract(epoch from (v_now - interval_row.started_at)))::integer),
      stop_reason = case when interval_row.plan_item_id = p_plan_item_id then 'pause' else 'switch' end
  where interval_row.user_id = v_user_id and interval_row.ended_at is null;

  if v_active_item_id = p_plan_item_id then
    return jsonb_build_object('state', 'paused', 'plan_item_id', p_plan_item_id);
  end if;

  insert into public.exercise_intervals (user_id, plan_item_id, started_at)
  values (v_user_id, p_plan_item_id, v_now)
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
  v_now timestamptz;
begin
  if v_user_id is null then
    raise exception 'Unauthorized';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text, 0));
  v_now := clock_timestamp();

  select item.plan_id into v_plan_id
  from public.plan_items item
  join public.daily_plans plan on plan.id = item.plan_id
  where item.id = p_plan_item_id
    and item.user_id = v_user_id
    and plan.is_current
    and plan.status <> 'executed'
    and plan.plan_date = (v_now at time zone 'Asia/Hong_Kong')::date;

  if v_plan_id is null then
    raise exception 'Plan item is not editable';
  end if;

  if p_done then
    update public.exercise_intervals interval_row
    set ended_at = v_now,
        duration_seconds = greatest(0, floor(extract(epoch from (v_now - interval_row.started_at)))::integer),
        stop_reason = 'done'
    where interval_row.user_id = v_user_id
      and interval_row.plan_item_id = p_plan_item_id
      and interval_row.ended_at is null;
  end if;

  update public.plan_items
  set completed_at = case when p_done then coalesce(completed_at, v_now) else null end
  where id = p_plan_item_id and user_id = v_user_id;

  update public.daily_plans
  set status = 'in_progress'
  where id = v_plan_id and status in ('generated', 'regenerated');

  return jsonb_build_object('plan_item_id', p_plan_item_id, 'done', p_done);
end;
$$;

revoke execute on function public.advance_plan_item_lap(uuid, integer) from public, anon;
grant execute on function public.advance_plan_item_lap(uuid, integer) to authenticated;
