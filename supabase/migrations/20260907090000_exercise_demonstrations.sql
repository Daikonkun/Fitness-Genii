alter table public.plan_items add column if not exists exercise_id text;

alter table public.plan_items add constraint plan_items_supported_exercise_id
  check (exercise_id is null or exercise_id in (
    'march-in-place',
    'step-jack',
    'arm-circle',
    'shoulder-roll',
    'standing-hip-hinge',
    'bodyweight-squat',
    'chair-sit-to-stand',
    'wall-push-up',
    'kneeling-push-up',
    'standard-push-up',
    'supported-reverse-lunge',
    'glute-bridge',
    'standing-calf-raise',
    'bird-dog',
    'dead-bug',
    'forearm-plank',
    'goblet-squat',
    'dumbbell-romanian-deadlift',
    'supported-dumbbell-row',
    'dumbbell-floor-press',
    'dumbbell-biceps-curl',
    'band-pull-apart',
    'standing-band-curl',
    'wall-calf-stretch',
    'seated-hamstring-stretch',
    'supported-quad-stretch',
    'cross-body-shoulder-stretch',
    'childs-pose'
  ));

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
  v_has_exercise_ids boolean;
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

  select exists (
    select 1 from jsonb_array_elements(p_plan_json -> 'sections') section,
    lateral jsonb_array_elements(section -> 'items') item
    where item ->> 'exercise_id' is not null
  ) into v_has_exercise_ids;

  -- Mixed old/new items are never a fully covered v3 plan. Reject before any updates.
  if v_has_exercise_ids and exists (
    select 1 from jsonb_array_elements(p_plan_json -> 'sections') section,
    lateral jsonb_array_elements(section -> 'items') item
    where item ->> 'exercise_id' is null
  ) then
    raise exception 'Every v3 item requires an exercise_id';
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
    case when v_has_exercise_ids then 3 else 2 end,
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
        exercise_id,
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
        v_item ->> 'exercise_id',
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
