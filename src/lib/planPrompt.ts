import type { BodyStatus, ExerciseRecord, ExerciseTarget, WeightLog } from "@/lib/types";

type PromptInput = {
  bodyStatus: BodyStatus | null;
  target: ExerciseTarget | null;
  weightLogs: WeightLog[];
  records: ExerciseRecord[];
  previousPlan: string | null;
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
        "You are a careful bilingual fitness coach. Generate practical daily exercise plans that avoid aggravating injuries, fit the user's equipment, and stay within the requested session length. Return concise Markdown only."
    },
    {
      role: "user" as const,
      content: `Create today's customized exercise plan for ${input.todayHk} in both English and Chinese.

Required output:
- Title in English and Chinese.
- Warm-up, main workout, and cool-down sections.
- Each move must include a brief English description, a brief Chinese description, and time, reps, or cycle guidance.
- Include safer substitutions when injury notes imply risk.
- Keep total planned exercise time within the user's requested minutes.
- End with a short completion logging suggestion.

User body status:
${JSON.stringify(input.bodyStatus, null, 2)}

Exercise target:
${JSON.stringify(input.target, null, 2)}

Recent exercise records:
${JSON.stringify(input.records, null, 2)}

${weightLossContext}

Previous plan, if any:
${input.previousPlan ?? "None"}

User feedback for regeneration:
${input.feedback?.trim() || "None"}

Make the plan as customized as possible using every available input.`
    }
  ];
}
