import { redirect } from "next/navigation";
import { Dashboard } from "@/components/Dashboard";
import { getHongKongDate } from "@/lib/date";
import { fetchExerciseRecordsMonth, RECORDS_LOAD_ERROR } from "@/lib/exerciseRecords";
import { createClient } from "@/lib/supabase/server";
import type {
  BodyStatus,
  DailyPlan,
  ExerciseInterval,
  ExerciseRecord,
  ExerciseTarget,
  PlanItem,
  WeightLog
} from "@/lib/types";

export const dynamic = "force-dynamic";

export default async function Home() {
  if (!process.env.NEXT_PUBLIC_SUPABASE_URL || !process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY) {
    redirect("/login");
  }

  const supabase = await createClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  const todayHk = getHongKongDate();

  const [
    bodyStatusResult,
    targetResult,
    weightLogsResult,
    recordsResult,
    todayPlanResult
  ] = await Promise.all([
    supabase.from("body_status").select("*").eq("user_id", user.id).maybeSingle(),
    supabase.from("exercise_targets").select("*").eq("user_id", user.id).maybeSingle(),
    supabase
      .from("weight_logs")
      .select("*")
      .eq("user_id", user.id)
      .order("logged_on", { ascending: false })
      .limit(30),
    fetchExerciseRecordsMonth(supabase, user.id, todayHk.slice(0, 7))
      .then((data) => ({ data, error: null }))
      .catch(() => ({ data: [], error: RECORDS_LOAD_ERROR })),
    supabase
      .from("daily_plans")
      .select("*")
      .eq("user_id", user.id)
      .eq("plan_date", todayHk)
      .eq("is_current", true)
      .maybeSingle()
  ]);

  const todayPlan = (todayPlanResult.data as DailyPlan | null) ?? null;
  const todayItemsResult = todayPlan
    ? await supabase
        .from("plan_items")
        .select("*")
        .eq("plan_id", todayPlan.id)
        .order("section_position", { ascending: true })
        .order("item_position", { ascending: true })
    : { data: [] };
  const todayPlanItems = (todayItemsResult.data ?? []) as PlanItem[];
  const itemIds = todayPlanItems.map((item) => item.id);
  const todayIntervalsResult = itemIds.length
    ? await supabase
        .from("exercise_intervals")
        .select("*")
        .in("plan_item_id", itemIds)
        .order("started_at", { ascending: true })
    : { data: [] };

  return (
    <Dashboard
      data={{
        userId: user.id,
        userEmail: user.email ?? "Assigned user",
        todayHk,
        bodyStatus: (bodyStatusResult.data as BodyStatus | null) ?? null,
        target: (targetResult.data as ExerciseTarget | null) ?? null,
        weightLogs: ((weightLogsResult.data as WeightLog[] | null) ?? []).reverse(),
        records: (recordsResult.data as ExerciseRecord[] | null) ?? [],
        recordsError: recordsResult.error,
        todayPlan,
        todayPlanItems,
        todayIntervals: (todayIntervalsResult.data ?? []) as ExerciseInterval[]
      }}
    />
  );
}
