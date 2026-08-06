import { NextResponse } from "next/server";
import { getHongKongDate } from "@/lib/date";
import { createAdminClient } from "@/lib/supabase/admin";
import type { DailyPlan, ExerciseInterval, PlanItem } from "@/lib/types";

async function finalize(request: Request) {
  const expectedSecret = process.env.CRON_SECRET;
  const authHeader = request.headers.get("authorization");

  if (!expectedSecret) {
    return NextResponse.json({ error: "CRON_SECRET is not configured." }, { status: 503 });
  }

  if (authHeader !== `Bearer ${expectedSecret}`) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const supabase = createAdminClient();
  const todayHk = getHongKongDate();

  const { data: stalePlans, error: selectError } = await supabase
    .from("daily_plans")
    .select("*")
    .lt("plan_date", todayHk)
    .eq("is_current", true)
    .in("status", ["generated", "regenerated", "in_progress"]);

  if (selectError) {
    return NextResponse.json({ error: selectError.message }, { status: 500 });
  }

  const plans = (stalePlans as DailyPlan[] | null) ?? [];
  if (plans.length === 0) {
    return NextResponse.json({ finalized: 0 });
  }

  const planIds = plans.map((plan) => plan.id);
  const { data: itemRows, error: itemError } = await supabase
    .from("plan_items")
    .select("*")
    .in("plan_id", planIds);

  if (itemError) {
    return NextResponse.json({ error: itemError.message }, { status: 500 });
  }

  const items = (itemRows as PlanItem[] | null) ?? [];
  const itemIds = items.map((item) => item.id);
  const { data: intervalRows, error: intervalError } = itemIds.length
    ? await supabase.from("exercise_intervals").select("*").in("plan_item_id", itemIds)
    : { data: [], error: null };

  if (intervalError) {
    return NextResponse.json({ error: intervalError.message }, { status: 500 });
  }

  const intervals = (intervalRows as ExerciseInterval[] | null) ?? [];
  const itemById = new Map(items.map((item) => [item.id, item]));

  for (const interval of intervals.filter((row) => !row.ended_at)) {
    const item = itemById.get(interval.plan_item_id);
    const plan = plans.find((candidate) => candidate.id === item?.plan_id);
    if (!plan) continue;

    const dayEnd = new Date(`${plan.plan_date}T23:59:59+08:00`);
    const durationSeconds = Math.max(
      0,
      Math.floor((dayEnd.getTime() - new Date(interval.started_at).getTime()) / 1000)
    );
    const { error } = await supabase
      .from("exercise_intervals")
      .update({
        ended_at: dayEnd.toISOString(),
        duration_seconds: Math.min(durationSeconds, 86_400),
        stop_reason: "day_end"
      })
      .eq("id", interval.id)
      .is("ended_at", null);

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    interval.ended_at = dayEnd.toISOString();
    interval.duration_seconds = Math.min(durationSeconds, 86_400);
    interval.stop_reason = "day_end";
  }

  const records = plans.map((plan) => {
    const planItems = items.filter((item) => item.plan_id === plan.id);
    const planItemIds = new Set(planItems.map((item) => item.id));
    const durationSeconds = intervals
      .filter((interval) => planItemIds.has(interval.plan_item_id))
      .reduce((sum, interval) => sum + interval.duration_seconds, 0);
    const completedItems = planItems.filter((item) => item.completed_at).length;
    const completionPercentage = planItems.length
      ? Math.round((completedItems / planItems.length) * 100)
      : plan.completion_percentage;

    return {
      plan,
      durationSeconds,
      completionPercentage
    };
  });

  for (const record of records) {
    const { error } = await supabase
      .from("daily_plans")
      .update({
        status: "unfinished",
        completion_percentage: record.completionPercentage
      })
      .eq("id", record.plan.id);

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }
  }

  const { error: insertError } = await supabase.from("exercise_records").upsert(
    records.map(({ plan, durationSeconds, completionPercentage }) => ({
      user_id: plan.user_id,
      plan_id: plan.id,
      record_date: plan.plan_date,
      activity_summary: "Daily AI plan was not marked executed before 23:59:59 Asia/Hong_Kong.",
      duration_minutes: Math.round(durationSeconds / 60),
      duration_seconds: durationSeconds,
      completion_percentage: completionPercentage,
      status: "unfinished"
    })),
    { onConflict: "plan_id" }
  );

  if (insertError) {
    return NextResponse.json({ error: insertError.message }, { status: 500 });
  }

  return NextResponse.json({ finalized: plans.length });
}

export async function GET(request: Request) {
  return finalize(request);
}

export async function POST(request: Request) {
  return finalize(request);
}
