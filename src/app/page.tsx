import { redirect } from "next/navigation";
import { Dashboard } from "@/components/Dashboard";
import { getHongKongDate } from "@/lib/date";
import { createClient } from "@/lib/supabase/server";
import type { BodyStatus, DailyPlan, ExerciseRecord, ExerciseTarget, WeightLog } from "@/lib/types";

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
    supabase
      .from("exercise_records")
      .select("*")
      .eq("user_id", user.id)
      .order("record_date", { ascending: false })
      .limit(20),
    supabase
      .from("daily_plans")
      .select("*")
      .eq("user_id", user.id)
      .eq("plan_date", todayHk)
      .maybeSingle()
  ]);

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
        todayPlan: (todayPlanResult.data as DailyPlan | null) ?? null
      }}
    />
  );
}
