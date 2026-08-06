alter table public.daily_plans drop constraint if exists daily_plans_user_id_plan_date_key;

create unique index if not exists daily_plans_user_date_revision_key
  on public.daily_plans(user_id, plan_date, revision);

create unique index if not exists daily_plans_one_current_per_day_key
  on public.daily_plans(user_id, plan_date)
  where is_current;

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

    update public.daily_plans
    set is_current = false,
        status = 'superseded',
        superseded_at = now()
    where id = v_previous_plan_id;
  end if;

  select coalesce(max(revision), 0) + 1 into v_revision
  from public.daily_plans
  where user_id = v_user_id and plan_date = p_plan_date;

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
    case when v_previous_plan_id is null then 'generated' else 'regenerated' end,
    0,
    nullif(trim(p_feedback), ''),
    p_model,
    p_prompt_inputs,
    now()
  ) returning id into v_plan_id;

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

revoke execute on function public.create_structured_plan_revision(uuid, date, jsonb, text, text, text, jsonb) from public, anon;
grant execute on function public.create_structured_plan_revision(uuid, date, jsonb, text, text, text, jsonb) to authenticated;
