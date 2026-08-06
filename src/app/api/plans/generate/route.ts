import { NextResponse } from "next/server";
import { z } from "zod";
import { getHongKongDate } from "@/lib/date";
import {
  structuredPlanJsonSchema,
  structuredPlanSchema,
  structuredPlanToMarkdown
} from "@/lib/planSchema";
import { buildPlanPrompt } from "@/lib/planPrompt";
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

const generateSchema = z.object({
  feedback: z.string().max(2000).optional()
});

function getHistoryStart(todayHk: string) {
  const date = new Date(`${todayHk}T00:00:00+08:00`);
  date.setUTCDate(date.getUTCDate() - 27);
  return date.toISOString().slice(0, 10);
}

export async function POST(request: Request) {
  const supabase = await createClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const parsed = generateSchema.safeParse(await request.json().catch(() => ({})));
  if (!parsed.success) {
    return NextResponse.json({ error: "Invalid request body." }, { status: 400 });
  }

  const apiKey = process.env.OPENROUTER_API_KEY;
  if (!apiKey) {
    return NextResponse.json(
      { error: "OPENROUTER_API_KEY is not configured." },
      { status: 503 }
    );
  }

  const todayHk = getHongKongDate();
  const model = process.env.OPENROUTER_MODEL || "openai/gpt-5.5";

  const [
    bodyResult,
    targetResult,
    weightsResult,
    recordsResult,
    currentPlanResult,
    historyPlansResult
  ] =
    await Promise.all([
      supabase.from("body_status").select("*").eq("user_id", user.id).maybeSingle(),
      supabase.from("exercise_targets").select("*").eq("user_id", user.id).maybeSingle(),
      supabase
        .from("weight_logs")
        .select("*")
        .eq("user_id", user.id)
        .order("logged_on", { ascending: false })
        .limit(20),
      supabase
        .from("exercise_records")
        .select("*")
        .eq("user_id", user.id)
        .gte("record_date", getHistoryStart(todayHk))
        .order("record_date", { ascending: false })
        .limit(60),
      supabase
        .from("daily_plans")
        .select("*")
        .eq("user_id", user.id)
        .eq("plan_date", todayHk)
        .eq("is_current", true)
        .maybeSingle(),
      supabase
        .from("daily_plans")
        .select("id,plan_date,revision,status,completion_percentage")
        .eq("user_id", user.id)
        .gte("plan_date", getHistoryStart(todayHk))
        .order("plan_date", { ascending: false })
        .limit(60)
    ]);

  const bodyStatus = (bodyResult.data as BodyStatus | null) ?? null;
  const target = (targetResult.data as ExerciseTarget | null) ?? null;

  if (!bodyStatus || !target) {
    return NextResponse.json(
      { error: "Save body status and exercise target before generating a plan." },
      { status: 422 }
    );
  }

  const weightLogs = ((weightsResult.data as WeightLog[] | null) ?? []).reverse();
  const records = (recordsResult.data as ExerciseRecord[] | null) ?? [];
  const historyPlans = (historyPlansResult.data ?? []) as Array<
    Pick<DailyPlan, "id" | "plan_date" | "revision" | "status" | "completion_percentage">
  >;
  const historyPlanIds = historyPlans.map((plan) => plan.id);
  const historyItemsResult = historyPlanIds.length
    ? await supabase
        .from("plan_items")
        .select("*")
        .in("plan_id", historyPlanIds)
        .order("section_position", { ascending: true })
        .order("item_position", { ascending: true })
    : { data: [] };
  const historyItems = (historyItemsResult.data ?? []) as PlanItem[];
  const historyItemIds = historyItems.map((item) => item.id);
  const historyIntervalsResult = historyItemIds.length
    ? await supabase
        .from("exercise_intervals")
        .select("*")
        .in("plan_item_id", historyItemIds)
        .not("ended_at", "is", null)
    : { data: [] };
  const historyIntervals = (historyIntervalsResult.data ?? []) as ExerciseInterval[];
  const secondsByItem = historyIntervals.reduce<Record<string, number>>((totals, interval) => {
    totals[interval.plan_item_id] =
      (totals[interval.plan_item_id] ?? 0) + interval.duration_seconds;
    return totals;
  }, {});
  const historyDigest = {
    window_start: getHistoryStart(todayHk),
    through: todayHk,
    daily_records: records.map((record) => ({
      date: record.record_date,
      activity: record.activity_summary,
      duration_seconds: record.duration_seconds ?? record.duration_minutes * 60,
      completion_percentage: record.completion_percentage,
      status: record.status
    })),
    plan_outcomes: historyPlans.map((plan) => ({
      date: plan.plan_date,
      revision: plan.revision,
      status: plan.status,
      completion_percentage: plan.completion_percentage
    })),
    measured_items: historyItems.slice(0, 120).map((item) => ({
      exercise_en: item.title_en,
      exercise_zh: item.title_zh,
      prescription: item.prescription,
      elapsed_seconds: secondsByItem[item.id] ?? 0,
      completed: Boolean(item.completed_at)
    }))
  };
  const currentPlan = (currentPlanResult.data as DailyPlan | null) ?? null;
  const previousPlan = currentPlan?.plan_json ?? currentPlan?.plan_markdown ?? null;
  const messages = buildPlanPrompt({
    bodyStatus,
    target,
    weightLogs,
    historyDigest,
    previousPlan,
    feedback: parsed.data.feedback,
    todayHk
  });

  const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
      "HTTP-Referer": process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000",
      "X-Title": "Fitness Genii"
    },
    body: JSON.stringify({
      model,
      messages,
      // Keep this payload to parameters advertised by the selected model.
      // require_parameters intentionally rejects providers that cannot honor them.
      provider: { require_parameters: true },
      response_format: {
        type: "json_schema",
        json_schema: {
          name: "fitness_genii_daily_plan",
          strict: true,
          schema: structuredPlanJsonSchema
        }
      }
    })
  });

  if (!response.ok) {
    const detail = await response.text();
    return NextResponse.json(
      { error: "OpenRouter request failed.", detail },
      { status: response.status }
    );
  }

  const completion = await response.json();
  const planContent = completion?.choices?.[0]?.message?.content;

  if (!planContent || typeof planContent !== "string") {
    return NextResponse.json(
      { error: "OpenRouter returned an empty plan." },
      { status: 502 }
    );
  }

  let parsedPlanJson: unknown;
  try {
    parsedPlanJson = JSON.parse(planContent);
  } catch {
    return NextResponse.json(
      { error: "OpenRouter returned invalid structured plan JSON." },
      { status: 502 }
    );
  }

  const structuredPlanResult = structuredPlanSchema.safeParse(parsedPlanJson);
  if (!structuredPlanResult.success) {
    return NextResponse.json(
      {
        error: "OpenRouter returned a plan that does not match the workout schema.",
        issues: structuredPlanResult.error.issues
      },
      { status: 502 }
    );
  }

  const structuredPlan = structuredPlanResult.data;
  const planMarkdown = structuredPlanToMarkdown(structuredPlan);

  const { data: planId, error: upsertError } = await supabase.rpc(
    "create_structured_plan_revision",
    {
      p_target_id: target.id ?? null,
      p_plan_date: todayHk,
      p_plan_json: structuredPlan,
      p_plan_markdown: planMarkdown,
      p_feedback: parsed.data.feedback ?? "",
      p_model: model,
      p_prompt_inputs: {
        bodyStatus,
        target,
        weightLogs,
        historyDigest,
        feedback: parsed.data.feedback ?? null
      }
    }
  );

  if (upsertError) {
    return NextResponse.json({ error: upsertError.message }, { status: 500 });
  }

  const [planResult, itemsResult] = await Promise.all([
    supabase.from("daily_plans").select("*").eq("id", planId).single(),
    supabase
      .from("plan_items")
      .select("*")
      .eq("plan_id", planId)
      .order("section_position", { ascending: true })
      .order("item_position", { ascending: true })
  ]);

  if (planResult.error || itemsResult.error) {
    return NextResponse.json(
      { error: planResult.error?.message ?? itemsResult.error?.message },
      { status: 500 }
    );
  }

  return NextResponse.json({ plan: planResult.data, items: itemsResult.data, intervals: [] });
}
