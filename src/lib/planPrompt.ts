import type { BodyStatus, ExerciseTarget, StructuredPlan, WeightLog } from "@/lib/types";

type PromptInput = {
  bodyStatus: BodyStatus | null;
  target: ExerciseTarget | null;
  weightLogs: WeightLog[];
  historyDigest: Record<string, unknown>;
  previousPlan: StructuredPlan | string | null;
  feedback?: string;
  todayHk: string;
};

export function buildPlanPrompt(input: PromptInput) {
  const weightLossContext =
    input.target?.target_type === "weight_loss"
      ? `Weight-loss context: consider the user's weight trend when calibrating intensity and expected progress. Weight logs: ${JSON.stringify(
          input.weightLogs
        )}`
      : "Weight-loss context: not selected unless the goal description explicitly requires it.";

  return [
    {
      role: "system" as const,
      content:
        "You are a careful bilingual fitness coach. Generate practical daily exercise plans that avoid aggravating injuries, fit the user's equipment, and stay within the requested session length. Return only the requested structured data."
    },
    {
      role: "user" as const,
      content: `Create today's customized exercise plan for ${input.todayHk} in both English and Chinese.

Required plan behavior:
- Include a title in English and Chinese.
- Include warm-up, main workout, and cool-down sections when appropriate.
- Each move must have English and Chinese titles and descriptions, a concise time/reps/cycle prescription, and planned_seconds (use 0 only when no meaningful time can be estimated).
- Include safer substitutions when injury notes imply risk.
- Keep total planned exercise time within the user's requested minutes.
- Include a short completion logging suggestion in both languages.

User body status:
${JSON.stringify(input.bodyStatus, null, 2)}

Exercise target:
${JSON.stringify(input.target, null, 2)}

Recent measured exercise history (bounded digest):
${JSON.stringify(input.historyDigest, null, 2)}

${weightLossContext}

Previous plan, if any:
${input.previousPlan ? JSON.stringify(input.previousPlan, null, 2) : "None"}

User feedback for regeneration:
${input.feedback?.trim() || "None"}

Make the plan as customized as possible using every available input.`
    }
  ];
}
