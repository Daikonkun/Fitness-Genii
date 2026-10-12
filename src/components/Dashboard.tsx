"use client";

import {
  Activity,
  CalendarCheck,
  Dumbbell,
  Loader2,
  LogOut,
  RefreshCw,
  Save,
  Sparkles,
  Target,
  TrendingDown,
  UserRound
} from "lucide-react";
import { useCallback, useMemo, useReducer, useRef, useState } from "react";
import {
  Area,
  AreaChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis
} from "recharts";
import { createClient } from "@/lib/supabase/client";
import { formatStopwatch, workoutMetrics } from "@/lib/workout";
import { bandSetup, equipmentDescription } from "@/lib/exercises/equipment";
import { EquipmentInput } from "@/components/EquipmentInput";
import { readEquipmentConfig, isStructuredEquipment, emptyEquipment, equipmentConfigSchema, serializeEquipment, type EquipmentConfig } from "@/lib/equipmentConfig";
import { WorkoutPlan } from "@/components/WorkoutPlan";
import { ExerciseRecordsCalendar } from "@/components/ExerciseRecordsCalendar";
import { calendarReducer, createCalendarState } from "@/lib/exerciseCalendar";
import { fetchExerciseRecordsMonth, RECORDS_LOAD_ERROR } from "@/lib/exerciseRecords";
import type {
  BodyStatus,
  DailyPlan,
  DashboardData,
  ExerciseInterval,
  ExerciseRecord,
  ExerciseTarget,
  PlanItem,
  TargetType
} from "@/lib/types";

type Notice = {
  type: "success" | "error";
  message: string;
};

const targetOptions: Array<{ value: TargetType; label: string }> = [
  { value: "general_fitness", label: "General fitness" },
  { value: "weight_loss", label: "Weight loss" },
  { value: "strength", label: "Strength" }
];

export function Dashboard({ data }: { data: DashboardData }) {
  const [bodyStatus, setBodyStatus] = useState<BodyStatus>(
    data.bodyStatus ?? {
      user_id: data.userId,
      gender: "",
      age: null,
      height_cm: null,
      weight_kg: null,
      injury: ""
    }
  );
  const [target, setTarget] = useState<ExerciseTarget>(
    data.target ?? {
      user_id: data.userId,
      target_type: "general_fitness",
      goal_description: "",
      exercise_minutes: 30,
      focus: "",
      equipment: "none"
    }
  );
  const [equipment, setEquipment] = useState<EquipmentConfig>(() => {
    const saved=readEquipmentConfig(data.target?.equipment);
    if (saved) return saved;
    const initial=emptyEquipment();
    if (bandSetup(data.target?.equipment) === "innstar_primary") return {...initial,selected:["kit","bodyweight"],primary:"kit",kit:{rating:null,unit:"kg",basis:"unknown",tubesPerSide:null}};
    if (data.target?.equipment && !/^(none|bodyweight|無|无)$/i.test(data.target.equipment.trim())) initial.selected=[];
    return initial;
  });
  const equipmentResult=equipmentConfigSchema.safeParse(equipment);
  const equipmentDirty=!equipmentResult.success || serializeEquipment(equipmentResult.data) !== target.equipment;
  const [todayPlan, setTodayPlan] = useState<DailyPlan | null>(data.todayPlan);
  const [planItems, setPlanItems] = useState<PlanItem[]>(data.todayPlanItems);
  const [intervals, setIntervals] = useState<ExerciseInterval[]>(data.todayIntervals);
  const [calendar, dispatchCalendar] = useReducer(calendarReducer, data, (initial) =>
    createCalendarState(initial.todayHk.slice(0, 7), initial.records, initial.recordsError)
  );
  const calendarRequestId = useRef(0);
  const [feedback, setFeedback] = useState("");
  const [executed, setExecuted] = useState(false);
  const [completion, setCompletion] = useState(todayPlan?.completion_percentage ?? 0);
  const [activitySummary, setActivitySummary] = useState("Completed today's AI exercise plan.");
  const [durationMinutes, setDurationMinutes] = useState(target.exercise_minutes);
  const [notice, setNotice] = useState<Notice | null>(null);
  const [saving, setSaving] = useState(false);
  const [generating, setGenerating] = useState(false);
  const [finishing, setFinishing] = useState(false);

  async function loadRecordsMonth(month: string) {
    const requestId = ++calendarRequestId.current;
    dispatchCalendar({ type: "load", month, requestId });
    try {
      const records = await fetchExerciseRecordsMonth(createClient(), data.userId, month);
      dispatchCalendar({ type: "loaded", requestId, records });
    } catch {
      dispatchCalendar({ type: "failed", requestId, error: RECORDS_LOAD_ERROR });
    }
  }

  const chartData = useMemo(
    () =>
      data.weightLogs.map((log) => ({
        date: log.logged_on.slice(5),
        weight: Number(log.weight_kg)
      })),
    [data.weightLogs]
  );

  const measuredMetrics = useMemo(
    () => workoutMetrics(planItems, intervals),
    [intervals, planItems]
  );

  const updateWorkoutData = useCallback(
    (nextItems: PlanItem[], nextIntervals: ExerciseInterval[]) => {
      setPlanItems(nextItems);
      setIntervals(nextIntervals);
    },
    []
  );

  async function saveInputs() {
    setNotice(null);
    if (!equipmentResult.success) {
      setNotice({type:"error",message:"Select equipment and enter positive dumbbell weights where required. / 請選擇器材，並填寫所需的正數啞鈴重量。"});
      return;
    }
    setSaving(true);
    const supabase = createClient();

    try {
      const normalizedBody = {
        user_id: data.userId,
        gender: bodyStatus.gender || null,
        age: bodyStatus.age,
        height_cm: bodyStatus.height_cm,
        weight_kg: bodyStatus.weight_kg,
        injury: bodyStatus.injury || null
      };

      const normalizedTarget = {
        user_id: data.userId,
        target_type: target.target_type,
        goal_description: target.goal_description,
        exercise_minutes: target.exercise_minutes,
        focus: target.focus || null,
        equipment: serializeEquipment(equipmentResult.data)
      };

      const { error: bodyError } = await supabase
        .from("body_status")
        .upsert(normalizedBody, { onConflict: "user_id" });

      if (bodyError) {
        setNotice({ type: "error", message: bodyError.message });
        return;
      }

      if (bodyStatus.weight_kg) {
        const { error: weightError } = await supabase.from("weight_logs").insert({
          user_id: data.userId,
          weight_kg: bodyStatus.weight_kg,
          logged_on: data.todayHk
        });

        if (weightError && !weightError.message.includes("duplicate key")) {
          setNotice({ type: "error", message: weightError.message });
          return;
        }
      }

      const { error: targetError } = await supabase
        .from("exercise_targets")
        .upsert(normalizedTarget, { onConflict: "user_id" });

      if (targetError) {
        setNotice({ type: "error", message: targetError.message });
        return;
      }

      setTarget({...target, equipment:normalizedTarget.equipment});
      setNotice({ type: "success", message: "Inputs saved. You can generate today's plan." });
    } finally {
      setSaving(false);
    }
  }

  async function generatePlan() {
    if (equipmentDirty) { setNotice({type:"error",message:"Save equipment inputs before generating. / 請先儲存器材設定再產生計劃。"}); return; }
    setGenerating(true);
    setNotice(null);

    try {
      const response = await fetch("/api/plans/generate", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ feedback })
      });

      const payload = await response.json();
      if (!response.ok) {
        throw new Error(payload.error ?? "Plan generation failed.");
      }

      setTodayPlan(payload.plan);
      setPlanItems(payload.items ?? []);
      setIntervals(payload.intervals ?? []);
      setFeedback("");
      setNotice({ type: "success", message: "Today's bilingual plan is ready." });
    } catch (error) {
      setNotice({
        type: "error",
        message: error instanceof Error ? error.message : "Plan generation failed."
      });
    } finally {
      setGenerating(false);
    }
  }

  async function recordExecution() {
    if (!todayPlan) {
      setNotice({ type: "error", message: "Generate a plan before recording execution." });
      return;
    }

    const supabase = createClient();
    const status = executed ? "executed" : "unfinished";
    const percentage = executed ? completion : 0;

    const { error: planError } = await supabase
      .from("daily_plans")
      .update({
        status,
        completion_percentage: percentage
      })
      .eq("id", todayPlan.id)
      .eq("user_id", data.userId);

    if (planError) {
      setNotice({ type: "error", message: planError.message });
      return;
    }

    const { data: savedRecord, error: recordError } = await supabase
      .from("exercise_records")
      .upsert(
        {
          user_id: data.userId,
          plan_id: todayPlan.id,
          record_date: data.todayHk,
          activity_summary: executed
            ? activitySummary || "Completed today's AI exercise plan."
            : "Plan was marked unfinished by the user.",
          duration_minutes: executed ? durationMinutes : 0,
          duration_seconds: executed ? durationMinutes * 60 : 0,
          completion_percentage: percentage,
          status
        },
        { onConflict: "plan_id" }
      )
      .select("*")
      .single();

    if (recordError) {
      setNotice({ type: "error", message: recordError.message });
      return;
    }

    dispatchCalendar({ type: "saved", record: savedRecord as ExerciseRecord });
    setTodayPlan({ ...todayPlan, status, completion_percentage: percentage });
    setNotice({ type: "success", message: "Exercise record saved." });
  }

  async function finishWorkout() {
    if (!todayPlan || todayPlan.schema_version < 2) return;
    setFinishing(true);
    setNotice(null);
    const supabase = createClient();

    try {
      const { data: result, error } = await supabase.rpc("finish_workout", {
        p_plan_id: todayPlan.id,
        p_activity_summary: activitySummary
      });
      if (error) throw new Error(error.message);

      const metrics = result as {
        completion_percentage: number;
        duration_seconds: number;
      };
      setTodayPlan({
        ...todayPlan,
        status: "executed",
        completion_percentage: metrics.completion_percentage
      });

      const itemIds = planItems.map((item) => item.id);
      const [intervalResult, recordResult] = await Promise.all([
        itemIds.length
          ? supabase
              .from("exercise_intervals")
              .select("*")
              .in("plan_item_id", itemIds)
              .order("started_at", { ascending: true })
          : Promise.resolve({ data: [], error: null }),
        supabase.from("exercise_records").select("*").eq("plan_id", todayPlan.id).single()
      ]);
      if (intervalResult.error) throw new Error(intervalResult.error.message);
      if (recordResult.error) throw new Error(recordResult.error.message);
      setIntervals((intervalResult.data ?? []) as ExerciseInterval[]);
      dispatchCalendar({ type: "saved", record: recordResult.data as ExerciseRecord });

      setNotice({
        type: "success",
        message: `Workout saved: ${metrics.completion_percentage}% complete, ${formatStopwatch(metrics.duration_seconds)} active time.`
      });
    } catch (error) {
      setNotice({
        type: "error",
        message: error instanceof Error ? error.message : "Could not finish the workout."
      });
    } finally {
      setFinishing(false);
    }
  }

  return (
    <main className="app-shell">
      <header className="topbar">
        <div className="brand-lockup">
          <span className="brand-icon" aria-hidden="true">
            <Dumbbell size={22} />
          </span>
          <div>
            <p className="eyebrow">Fitness Genii</p>
            <h1>Daily training dashboard</h1>
          </div>
        </div>
        <div className="user-pill">
          <UserRound size={16} />
          <span>{data.userEmail}</span>
          <a className="profile-link" href="/profile">
            Profile
          </a>
          <a className="icon-link" href="/auth/sign-out" aria-label="Sign out" title="Sign out">
            <LogOut size={16} />
          </a>
        </div>
      </header>

      {notice ? <div className={`notice ${notice.type}`}>{notice.message}</div> : null}

      <section className="dashboard-grid">
        <section className="panel input-panel">
          <div className="panel-heading">
            <Activity size={18} />
            <h2>Body status</h2>
          </div>
          <div className="form-grid">
            <label>
              Gender
              <select
                value={bodyStatus.gender ?? ""}
                onChange={(event) =>
                  setBodyStatus({ ...bodyStatus, gender: event.target.value })
                }
              >
                <option value="">Prefer not to say</option>
                <option value="female">Female</option>
                <option value="male">Male</option>
                <option value="non_binary">Non-binary</option>
              </select>
            </label>
            <label>
              Age
              <input
                type="number"
                min="10"
                max="100"
                value={bodyStatus.age ?? ""}
                onChange={(event) =>
                  setBodyStatus({
                    ...bodyStatus,
                    age: event.target.value ? Number(event.target.value) : null
                  })
                }
              />
            </label>
            <label>
              Height (cm)
              <input
                type="number"
                min="80"
                max="240"
                value={bodyStatus.height_cm ?? ""}
                onChange={(event) =>
                  setBodyStatus({
                    ...bodyStatus,
                    height_cm: event.target.value ? Number(event.target.value) : null
                  })
                }
              />
            </label>
            <label>
              Weight (kg)
              <input
                type="number"
                min="20"
                max="300"
                step="0.1"
                value={bodyStatus.weight_kg ?? ""}
                onChange={(event) =>
                  setBodyStatus({
                    ...bodyStatus,
                    weight_kg: event.target.value ? Number(event.target.value) : null
                  })
                }
              />
            </label>
          </div>
          <label>
            Injury notes
            <textarea
              value={bodyStatus.injury ?? ""}
              onChange={(event) => setBodyStatus({ ...bodyStatus, injury: event.target.value })}
              rows={3}
              placeholder="Knee discomfort, shoulder recovery, none..."
            />
          </label>
        </section>

        <section className="panel input-panel">
          <div className="panel-heading">
            <Target size={18} />
            <h2>Exercise target</h2>
          </div>
          <div className="segmented" role="group" aria-label="Exercise target type">
            {targetOptions.map((option) => (
              <button
                key={option.value}
                className={target.target_type === option.value ? "active" : ""}
                type="button"
                aria-pressed={target.target_type === option.value}
                onClick={() => setTarget({ ...target, target_type: option.value })}
              >
                {option.label}
              </button>
            ))}
          </div>
          <label>
            Goal description
            <textarea
              value={target.goal_description}
              onChange={(event) => setTarget({ ...target, goal_description: event.target.value })}
              rows={3}
              placeholder="Lose 5 kg in two months, improve posture, build leg strength..."
            />
          </label>
          <div className="form-grid">
            <label>
              Time (minutes)
              <input
                type="number"
                min="10"
                max="180"
                value={target.exercise_minutes}
                onChange={(event) => {
                  const minutes = Number(event.target.value);
                  setTarget({ ...target, exercise_minutes: minutes });
                  setDurationMinutes(minutes);
                }}
              />
            </label>
            <label>
              Focus
              <input
                value={target.focus ?? ""}
                onChange={(event) => setTarget({ ...target, focus: event.target.value })}
                placeholder="Chest, legs, core..."
              />
            </label>
          </div>
          {!readEquipmentConfig(target.equipment) && target.equipment && <p className="muted">Previous equipment / 原有器材：{isStructuredEquipment(target.equipment) ? "Settings could not be read / 設定無法讀取" : equipmentDescription(target.equipment)}. Review the selections and weights before saving / 請確認選項及重量後儲存。</p>}
          <EquipmentInput value={equipment} onChange={setEquipment} />
          {equipmentDirty && <p className="muted">Save inputs to use these equipment settings / 儲存後才會使用新器材設定。</p>}
          <button
            className="secondary-button"
            type="button"
            onClick={saveInputs}
            disabled={saving}
          >
            {saving ? <Loader2 className="spin" size={16} /> : <Save size={16} />}
            Save inputs
          </button>
        </section>

        <section className="panel plan-panel">
          <div className="panel-heading">
            <Sparkles size={18} />
            <h2>Plan for {data.todayHk}</h2>
          </div>
          <div className="plan-actions">
            <button
              className="primary-button"
              type="button"
              onClick={generatePlan}
              disabled={generating || equipmentDirty || saving}
            >
              {generating ? <Loader2 className="spin" size={16} /> : <Sparkles size={16} />}
              {todayPlan ? "Regenerate plan" : "Generate plan"}
            </button>
          </div>
          <label>
            Feedback for regeneration
            <textarea
              value={feedback}
              onChange={(event) => setFeedback(event.target.value)}
              rows={3}
              placeholder="Too hard on knees, add dumbbell work, make it lower impact..."
            />
          </label>
          <article className="plan-output">
            {todayPlan ? (
              todayPlan.schema_version >= 2 && planItems.length ? (
                <WorkoutPlan
                  key={todayPlan.id}
                  planId={todayPlan.id}
                  items={planItems}
                  intervals={intervals}
                  interactive={todayPlan.is_current && todayPlan.status !== "executed"}
                  onDataChange={updateWorkoutData}
                />
              ) : (
                <div className="legacy-plan">
                  <span className="legacy-badge">Legacy plan · read only</span>
                  <pre>{todayPlan.plan_markdown}</pre>
                </div>
              )
            ) : (
              <div className="empty-state">
                <Sparkles size={22} />
                <p>Save your inputs, then generate a bilingual daily plan.</p>
              </div>
            )}
          </article>
        </section>

        <section className="panel execution-panel">
          <div className="panel-heading">
            <CalendarCheck size={18} />
            <h2>Execution record</h2>
          </div>
          {todayPlan && todayPlan.schema_version >= 2 ? (
            <>
              <div className="workout-metrics">
                <div>
                  <strong>{measuredMetrics.completionPercentage}%</strong>
                  <span>items done</span>
                </div>
                <div>
                  <strong>{formatStopwatch(measuredMetrics.durationSeconds)}</strong>
                  <span>active time</span>
                </div>
              </div>
              <p className="muted">
                {measuredMetrics.completedItems} of {measuredMetrics.totalItems} exercises marked done.
                You can finish and save a partial workout.
              </p>
              <label>
                Workout note
                <textarea
                  value={activitySummary}
                  onChange={(event) => setActivitySummary(event.target.value)}
                  rows={3}
                />
              </label>
              <button
                className="secondary-button"
                type="button"
                onClick={finishWorkout}
                disabled={finishing || todayPlan.status === "executed"}
              >
                {finishing ? <Loader2 className="spin" size={16} /> : <CalendarCheck size={16} />}
                {todayPlan.status === "executed" ? "Workout saved" : "Finish workout"}
              </button>
            </>
          ) : (
            <>
              <label className="check-row">
                <input
                  type="checkbox"
                  checked={executed}
                  onChange={(event) => setExecuted(event.target.checked)}
                />
                Plan executed today
              </label>
              <label>
                Completion: {executed ? completion : 0}%
                <input
                  type="range"
                  min="0"
                  max="100"
                  step="5"
                  value={executed ? completion : 0}
                  disabled={!executed}
                  onChange={(event) => setCompletion(Number(event.target.value))}
                />
              </label>
              <label>
                Duration (minutes)
                <input
                  type="number"
                  min="0"
                  max="240"
                  value={executed ? durationMinutes : 0}
                  disabled={!executed}
                  onChange={(event) => setDurationMinutes(Number(event.target.value))}
                />
              </label>
              <button className="secondary-button" type="button" onClick={recordExecution}>
                <RefreshCw size={16} />
                Save legacy record
              </button>
            </>
          )}
          {todayPlan ? (
            <p className="status-line">
              Current plan status: <strong>{todayPlan.status}</strong>, {todayPlan.completion_percentage}% complete
            </p>
          ) : null}
        </section>

        <section className="panel chart-panel">
          <div className="panel-heading">
            <TrendingDown size={18} />
            <h2>Weight curve</h2>
          </div>
          {chartData.length ? (
            <ResponsiveContainer width="100%" height={260}>
              <AreaChart data={chartData} margin={{ top: 16, right: 16, bottom: 8, left: 0 }}>
                <defs>
                  <linearGradient id="weightFill" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#2f7d6d" stopOpacity={0.35} />
                    <stop offset="95%" stopColor="#2f7d6d" stopOpacity={0.02} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="#d9ded8" />
                <XAxis dataKey="date" tickLine={false} axisLine={false} />
                <YAxis tickLine={false} axisLine={false} width={42} />
                <Tooltip />
                <Area
                  type="monotone"
                  dataKey="weight"
                  stroke="#2f7d6d"
                  strokeWidth={2}
                  fill="url(#weightFill)"
                />
              </AreaChart>
            </ResponsiveContainer>
          ) : (
            <div className="empty-state">
              <TrendingDown size={22} />
              <p>Weight logs appear after saving body status.</p>
            </div>
          )}
        </section>

        <ExerciseRecordsCalendar
          state={calendar}
          today={data.todayHk}
          onMonthChange={loadRecordsMonth}
          onRetry={() => loadRecordsMonth(calendar.month)}
        />
      </section>
    </main>
  );
}
