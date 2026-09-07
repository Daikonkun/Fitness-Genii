import { readEquipmentConfig, equipmentSummary } from "./equipmentConfig";
import { generationCatalogue } from "./planSchema";
import { EXERCISE_CATALOGUE_VERSION, getExercise } from "./exercises/catalogue";
import { bandEquipmentCompatible } from "./exercises/equipment";
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
  const equipmentConfig=readEquipmentConfig(input.target?.equipment);
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
- Return status="ready", empty reason_en/reason_zh, and the plan when the catalogue can meet the user's constraints.
- If no suitable plan can be made, return status="unavailable", a concise reason in both languages, and plan=null. Never ignore injury, equipment, or explicit movement requirements just to produce a plan.
- Every move MUST use exactly one exercise_id from the catalogue below. No extra variants, combinations, equipment changes, or substitutions inside an item. Select another supported ID for a substitution.
- Use only equipment the user has. Chair and wall support require availability too. Basic fitness goals can use bodyweight even when other equipment is available; explicit requests for unsupported movements cannot.
- Band setup is explicitly confirmed in the equipment marker. An unspecified band, a resistance rating, or old workout history does not confirm attachments. Never use a flat band move for handled tubes, wrap independent tubes around the back, or invent anchors. If a requested band workout is unavailable, explain the missing setup confirmation. Do not interpret a nominal kg label as constant resistance.
- When band-setup is innstar_primary OR equipment_config.primary is kit, the user's main equipment is the INNSTAR padded chest expander, assembled bar, handled tubes and foot straps. Include at least one main-workout kit exercise for EACH focus: chest, back and core. Prefer kit work for the main session; warm-up/cool-down may be bodyweight. No external anchor is available by default. If injury, time, or feedback prevents this coverage, return unavailable and explain rather than forcing an unsuitable move or silently omitting a focus. The padded chest unit is distinct from loose independent tubes and is allowed across the upper back for its listed presses. Never infer 230 cm as the allowable stretch of an individual tube or invent resistance loads.
- For structured equipment, use its selected inventory, primary equipment, working dumbbell weight per hand and quantity. A full-gym selection only enables supported catalogue movements: it never authorizes invented machine, cable or barbell exercises. Kit ratings are labels, never constant loads; never multiply them to infer working resistance. Do not prescribe weights or resistance changes in prose (including kg/lb values); the application supplies the saved load label. Keep each prescription under 80 characters and customize sets, repetitions, duration and rest instead. If the entered weight conflicts with the user's constraints, explain the limitation rather than overriding it.
- Copy the catalogue movement names and instructions. Customize only selection, time/reps/cycles/rest and planned_seconds. A prescription must not change the movement variant.
- Each move must have English and Chinese titles and descriptions, a concise time/reps/cycle prescription, and planned_seconds (use 0 only when no meaningful time can be estimated).
- Include safer substitutions when injury notes imply risk.
- Keep total planned exercise time within the user's requested minutes.
- Include a short completion logging suggestion in both languages.

Supported exercise catalogue (version ${EXERCISE_CATALOGUE_VERSION}):
${JSON.stringify(generationCatalogue.filter((entry) => bandEquipmentCompatible(getExercise(entry.exercise_id)!, input.target?.equipment)))}

User body status:
${JSON.stringify(input.bodyStatus, null, 2)}

Exercise target:
${JSON.stringify(equipmentConfig ? {...input.target,equipment:equipmentSummary(equipmentConfig),equipment_config:equipmentConfig} : input.target, null, 2)}

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
