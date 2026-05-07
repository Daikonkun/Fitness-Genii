"use client";

import {
  Activity,
  CalendarCheck,
  Dumbbell,
  History,
  Loader2,
  LogOut,
  RefreshCw,
  Save,
  Sparkles,
  Target,
  TrendingDown,
  UserRound
} from "lucide-react";
import { useMemo, useState } from "react";
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
import type { BodyStatus, DailyPlan, DashboardData, ExerciseTarget, TargetType } from "@/lib/types";

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
  const [todayPlan, setTodayPlan] = useState<DailyPlan | null>(data.todayPlan);
  const [feedback, setFeedback] = useState("");
  const [executed, setExecuted] = useState(true);
  const [completion, setCompletion] = useState(todayPlan?.completion_percentage ?? 80);
  const [activitySummary, setActivitySummary] = useState("Completed today's AI exercise plan.");
  const [durationMinutes, setDurationMinutes] = useState(target.exercise_minutes);
  const [notice, setNotice] = useState<Notice | null>(null);
  const [saving, setSaving] = useState(false);
  const [generating, setGenerating] = useState(false);

  const chartData = useMemo(
    () =>
      data.weightLogs.map((log) => ({
        date: log.logged_on.slice(5),
        weight: Number(log.weight_kg)
      })),
    [data.weightLogs]
  );

  async function saveInputs() {
    setNotice(null);
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
        equipment: target.equipment || null
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

      setNotice({ type: "success", message: "Inputs saved. You can generate today's plan." });
    } finally {
      setSaving(false);
    }
  }

  async function generatePlan() {
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

    const { error: recordError } = await supabase.from("exercise_records").upsert(
      {
        user_id: data.userId,
        plan_id: todayPlan.id,
        record_date: data.todayHk,
        activity_summary: executed
          ? activitySummary || "Completed today's AI exercise plan."
          : "Plan was marked unfinished by the user.",
        duration_minutes: executed ? durationMinutes : 0,
        completion_percentage: percentage,
        status
      },
      { onConflict: "plan_id" }
    );

    if (recordError) {
      setNotice({ type: "error", message: recordError.message });
      return;
    }

    setTodayPlan({ ...todayPlan, status, completion_percentage: percentage });
    setNotice({ type: "success", message: "Exercise record saved." });
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
            <label>
              Equipment
              <input
                value={target.equipment ?? ""}
                onChange={(event) => setTarget({ ...target, equipment: event.target.value })}
                placeholder="None, dumbbells, bands..."
              />
            </label>
          </div>
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
              disabled={generating}
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
              <pre>{todayPlan.plan_markdown}</pre>
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
          <div className="form-grid">
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
          </div>
          <label>
            What was done
            <textarea
              value={executed ? activitySummary : "Plan was marked unfinished by the user."}
              disabled={!executed}
              onChange={(event) => setActivitySummary(event.target.value)}
              rows={3}
            />
          </label>
          <button className="secondary-button" type="button" onClick={recordExecution}>
            <RefreshCw size={16} />
            Save record
          </button>
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

        <section className="panel records-panel">
          <div className="panel-heading">
            <History size={18} />
            <h2>Exercise records</h2>
          </div>
          <div className="record-list">
            {data.records.length ? (
              data.records.map((record) => (
                <article className="record-item" key={record.id}>
                  <div>
                    <strong>{record.record_date}</strong>
                    <p>{record.activity_summary}</p>
                  </div>
                  <span className={`record-badge ${record.status}`}>{record.status}</span>
                  <span>{record.duration_minutes} min</span>
                  <span>{record.completion_percentage}%</span>
                </article>
              ))
            ) : (
              <div className="empty-state">
                <History size={22} />
                <p>Executed and unfinished plans will appear here.</p>
              </div>
            )}
          </div>
        </section>
      </section>
    </main>
  );
}
