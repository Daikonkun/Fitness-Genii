import { NextResponse } from "next/server";
import { getHongKongDate } from "@/lib/date";
import { createAdminClient } from "@/lib/supabase/admin";
import type { DailyPlan } from "@/lib/types";

async function finalize(request: Request) {
  const expectedSecret = process.env.CRON_SECRET;
  const authHeader = request.headers.get("authorization");

  if (expectedSecret && authHeader !== `Bearer ${expectedSecret}`) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const supabase = createAdminClient();
  const todayHk = getHongKongDate();

  const { data: stalePlans, error: selectError } = await supabase
    .from("daily_plans")
    .select("*")
    .lt("plan_date", todayHk)
    .in("status", ["generated", "regenerated"]);

  if (selectError) {
    return NextResponse.json({ error: selectError.message }, { status: 500 });
  }

  const plans = (stalePlans as DailyPlan[] | null) ?? [];
  if (plans.length === 0) {
    return NextResponse.json({ finalized: 0 });
  }

  const planIds = plans.map((plan) => plan.id);
  const { error: updateError } = await supabase
    .from("daily_plans")
    .update({
      status: "unfinished",
      completion_percentage: 0
    })
    .in("id", planIds);

  if (updateError) {
    return NextResponse.json({ error: updateError.message }, { status: 500 });
  }

  const { error: insertError } = await supabase.from("exercise_records").upsert(
    plans.map((plan) => ({
      user_id: plan.user_id,
      plan_id: plan.id,
      record_date: plan.plan_date,
      activity_summary: "Daily AI plan was not marked executed before 23:59:59 Asia/Hong_Kong.",
      duration_minutes: 0,
      completion_percentage: 0,
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
