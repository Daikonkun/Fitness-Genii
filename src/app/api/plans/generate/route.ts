import { NextResponse } from "next/server";
import { z } from "zod";
import { getHongKongDate } from "@/lib/date";
import { buildPlanPrompt } from "@/lib/planPrompt";
import { createClient } from "@/lib/supabase/server";
import type { BodyStatus, ExerciseRecord, ExerciseTarget, WeightLog } from "@/lib/types";

const generateSchema = z.object({
  feedback: z.string().max(2000).optional()
});

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

  const [bodyResult, targetResult, weightsResult, recordsResult, currentPlanResult] =
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
        .order("record_date", { ascending: false })
        .limit(14),
      supabase
        .from("daily_plans")
        .select("*")
        .eq("user_id", user.id)
        .eq("plan_date", todayHk)
        .maybeSingle()
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
  const previousPlan = (currentPlanResult.data?.plan_markdown as string | undefined) ?? null;
  const messages = buildPlanPrompt({
    bodyStatus,
    target,
    weightLogs,
    records,
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
      temperature: 0.45
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
  const planMarkdown = completion?.choices?.[0]?.message?.content;

  if (!planMarkdown || typeof planMarkdown !== "string") {
    return NextResponse.json(
      { error: "OpenRouter returned an empty plan." },
      { status: 502 }
    );
  }

  const { data: plan, error: upsertError } = await supabase
    .from("daily_plans")
    .upsert(
      {
        user_id: user.id,
        target_id: target.id ?? null,
        plan_date: todayHk,
        plan_markdown: planMarkdown,
        status: previousPlan ? "regenerated" : "generated",
        completion_percentage: 0,
        feedback: parsed.data.feedback?.trim() || null,
        model,
        prompt_inputs: {
          bodyStatus,
          target,
          weightLogs,
          records,
          feedback: parsed.data.feedback ?? null
        },
        generated_at: new Date().toISOString()
      },
      { onConflict: "user_id,plan_date" }
    )
    .select("*")
    .single();

  if (upsertError) {
    return NextResponse.json({ error: upsertError.message }, { status: 500 });
  }

  return NextResponse.json({ plan });
}
