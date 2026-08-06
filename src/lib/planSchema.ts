import { z } from "zod";
import type {
  StructuredPlan,
  StructuredPlanItem,
  StructuredPlanSection
} from "@/lib/types";

export const structuredPlanItemSchema: z.ZodType<StructuredPlanItem> = z.object({
  title_en: z.string().min(1).max(160),
  title_zh: z.string().min(1).max(160),
  description_en: z.string().min(1).max(600),
  description_zh: z.string().min(1).max(600),
  prescription: z.string().min(1).max(240),
  planned_seconds: z.number().int().min(0).max(10_800)
});

export const structuredPlanSectionSchema: z.ZodType<StructuredPlanSection> = z.object({
  section_type: z.enum(["warm_up", "main_workout", "cool_down"]),
  title_en: z.string().min(1).max(120),
  title_zh: z.string().min(1).max(120),
  items: z.array(structuredPlanItemSchema).min(1).max(20)
});

export const structuredPlanSchema: z.ZodType<StructuredPlan> = z.object({
  title_en: z.string().min(1).max(160),
  title_zh: z.string().min(1).max(160),
  sections: z.array(structuredPlanSectionSchema).min(1).max(6),
  completion_suggestion_en: z.string().min(1).max(400),
  completion_suggestion_zh: z.string().min(1).max(400)
});

export const structuredPlanJsonSchema = {
  type: "object",
  additionalProperties: false,
  required: [
    "title_en",
    "title_zh",
    "sections",
    "completion_suggestion_en",
    "completion_suggestion_zh"
  ],
  properties: {
    title_en: { type: "string" },
    title_zh: { type: "string" },
    sections: {
      type: "array",
      minItems: 1,
      maxItems: 6,
      items: {
        type: "object",
        additionalProperties: false,
        required: ["section_type", "title_en", "title_zh", "items"],
        properties: {
          section_type: { type: "string", enum: ["warm_up", "main_workout", "cool_down"] },
          title_en: { type: "string" },
          title_zh: { type: "string" },
          items: {
            type: "array",
            minItems: 1,
            maxItems: 20,
            items: {
              type: "object",
              additionalProperties: false,
              required: [
                "title_en",
                "title_zh",
                "description_en",
                "description_zh",
                "prescription",
                "planned_seconds"
              ],
              properties: {
                title_en: { type: "string" },
                title_zh: { type: "string" },
                description_en: { type: "string" },
                description_zh: { type: "string" },
                prescription: { type: "string" },
                planned_seconds: { type: "integer", minimum: 0, maximum: 10800 }
              }
            }
          }
        }
      }
    },
    completion_suggestion_en: { type: "string" },
    completion_suggestion_zh: { type: "string" }
  }
} as const;

export function structuredPlanToMarkdown(plan: StructuredPlan) {
  const lines = [`# ${plan.title_en} / ${plan.title_zh}`, ""];

  for (const section of plan.sections) {
    lines.push(`## ${section.title_en} / ${section.title_zh}`);
    for (const item of section.items) {
      lines.push(
        `- **${item.title_en} / ${item.title_zh}** — ${item.prescription}`,
        `  ${item.description_en}`,
        `  ${item.description_zh}`
      );
    }
    lines.push("");
  }

  lines.push(plan.completion_suggestion_en, plan.completion_suggestion_zh);
  return lines.join("\n");
}
