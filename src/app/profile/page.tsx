import { ArrowLeft, Dumbbell, History, LogOut, Timer, Trophy } from "lucide-react";
import Link from "next/link";
import { redirect } from "next/navigation";
import { WorkoutPlan } from "@/components/WorkoutPlan";
import { getHongKongDate } from "@/lib/date";
import { createClient } from "@/lib/supabase/server";
import { formatStopwatch } from "@/lib/workout";
import type {
  DailyPlan,
  ExerciseInterval,
  ExerciseRecord,
  PlanItem
} from "@/lib/types";

export const dynamic = "force-dynamic";

function getWindowStart(todayHk: string) {
  const date = new Date(`${todayHk}T00:00:00+08:00`);
  date.setUTCDate(date.getUTCDate() - 29);
  return date.toISOString().slice(0, 10);
}

export default async function ProfilePage() {
  if (!process.env.NEXT_PUBLIC_SUPABASE_URL || !process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY) {
    redirect("/login");
  }

  const supabase = await createClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) redirect("/login");

  const todayHk = getHongKongDate();
  const [plansResult, recordsResult] = await Promise.all([
    supabase
      .from("daily_plans")
      .select("*")
      .eq("user_id", user.id)
      .order("plan_date", { ascending: false })
      .order("revision", { ascending: false })
      .limit(120),
    supabase
      .from("exercise_records")
      .select("*")
      .eq("user_id", user.id)
      .order("record_date", { ascending: false })
      .limit(120)
  ]);

  const plans = (plansResult.data ?? []) as DailyPlan[];
  const records = (recordsResult.data ?? []) as ExerciseRecord[];
  const planIds = plans.map((plan) => plan.id);
  const itemsResult = planIds.length
    ? await supabase
        .from("plan_items")
        .select("*")
        .in("plan_id", planIds)
        .order("section_position", { ascending: true })
        .order("item_position", { ascending: true })
    : { data: [] };
  const items = (itemsResult.data ?? []) as PlanItem[];
  const itemIds = items.map((item) => item.id);
  const intervalsResult = itemIds.length
    ? await supabase
        .from("exercise_intervals")
        .select("*")
        .in("plan_item_id", itemIds)
        .order("started_at", { ascending: true })
    : { data: [] };
  const intervals = (intervalsResult.data ?? []) as ExerciseInterval[];
  const itemsByPlan = new Map<string, PlanItem[]>();
  const intervalsByItem = new Map<string, ExerciseInterval[]>();
  const recordsByPlan = new Map(
    records.filter((record) => record.plan_id).map((record) => [record.plan_id as string, record])
  );

  for (const item of items) {
    const planItems = itemsByPlan.get(item.plan_id) ?? [];
    planItems.push(item);
    itemsByPlan.set(item.plan_id, planItems);
  }

  for (const interval of intervals) {
    const itemIntervals = intervalsByItem.get(interval.plan_item_id) ?? [];
    itemIntervals.push(interval);
    intervalsByItem.set(interval.plan_item_id, itemIntervals);
  }

  const recentRecords = records.filter((record) => record.record_date >= getWindowStart(todayHk));
  const totalSeconds = recentRecords.reduce(
    (sum, record) => sum + (record.duration_seconds ?? record.duration_minutes * 60),
    0
  );
  const completionRate = recentRecords.length
    ? Math.round(
        recentRecords.reduce((sum, record) => sum + record.completion_percentage, 0) /
          recentRecords.length
      )
    : 0;
  const completedWorkouts = recentRecords.filter((record) => record.status === "executed").length;

  return (
    <main className="app-shell profile-shell">
      <header className="topbar">
        <div className="brand-lockup">
          <span className="brand-icon" aria-hidden="true">
            <History size={22} />
          </span>
          <div>
            <p className="eyebrow">Fitness Genii profile</p>
            <h1>Personal exercise record</h1>
          </div>
        </div>
        <div className="profile-nav">
          <Link className="secondary-link" href="/">
            <ArrowLeft size={16} />
            Today&apos;s workout
          </Link>
          <a className="icon-link" href="/auth/sign-out" aria-label="Sign out" title="Sign out">
            <LogOut size={16} />
          </a>
        </div>
      </header>

      <section className="profile-stat-grid" aria-label="Last 30 days">
        <article className="profile-stat">
          <Dumbbell size={20} />
          <strong>{completedWorkouts}</strong>
          <span>completed workouts</span>
        </article>
        <article className="profile-stat">
          <Timer size={20} />
          <strong>{formatStopwatch(totalSeconds)}</strong>
          <span>active exercise time</span>
        </article>
        <article className="profile-stat">
          <Trophy size={20} />
          <strong>{completionRate}%</strong>
          <span>average completion</span>
        </article>
      </section>

      <section className="panel profile-history-panel">
        <div className="panel-heading">
          <History size={18} />
          <h2>Plan and revision history</h2>
        </div>
        <p className="muted">The latest 30-day summary appears above. Historical workouts are read only.</p>
        <div className="profile-history-list">
          {plans.length ? (
            plans.map((plan) => {
              const planItems = itemsByPlan.get(plan.id) ?? [];
              const planIntervals = planItems.flatMap(
                (item) => intervalsByItem.get(item.id) ?? []
              );
              const record = recordsByPlan.get(plan.id);

              return (
                <details className="profile-day" key={plan.id} open={plan.plan_date === todayHk && plan.is_current}>
                  <summary>
                    <span>
                      <strong>{plan.plan_date}</strong>
                      <small>Revision {plan.revision}</small>
                    </span>
                    <span className={`record-badge ${plan.status}`}>{plan.status}</span>
                    <span>{record ? formatStopwatch(record.duration_seconds ?? record.duration_minutes * 60) : "00:00:00"}</span>
                    <span>{plan.completion_percentage}%</span>
                  </summary>
                  <div className="profile-day-content">
                    {plan.schema_version >= 2 && planItems.length ? (
                      <WorkoutPlan
                        planId={plan.id}
                        items={planItems}
                        intervals={planIntervals}
                      />
                    ) : (
                      <div className="legacy-plan">
                        <span className="legacy-badge">Legacy plan · read only</span>
                        <pre>{plan.plan_markdown}</pre>
                      </div>
                    )}
                  </div>
                </details>
              );
            })
          ) : (
            <div className="empty-state">
              <History size={22} />
              <p>Your generated plans and measured workouts will appear here.</p>
            </div>
          )}
        </div>
      </section>
    </main>
  );
}
