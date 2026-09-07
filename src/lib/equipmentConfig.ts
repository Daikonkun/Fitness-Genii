import { z } from "zod";
import type { ExerciseDefinition } from "./exercises/catalogue";

export const equipmentKinds = {
  kit: "INNSTAR kit / 拉力器套裝",
  dumbbells: "Dumbbells / 啞鈴",
  bodyweight: "Bodyweight / 徒手",
  full_gym: "Full gym set / 健身房全套器材"
} as const;
export type EquipmentKind = keyof typeof equipmentKinds;
const weight = z.number().finite().positive().max(500);
export const equipmentConfigSchema = z.object({
  version: z.literal(1),
  selected: z.array(z.enum(["kit", "dumbbells", "bodyweight", "full_gym"])).min(1).max(4),
  primary: z.enum(["kit", "dumbbells", "bodyweight", "full_gym"]),
  dumbbells: z.object({ weight, unit: z.enum(["kg", "lb"]), count: z.union([z.literal(1), z.literal(2)]) }).nullable(),
  kit: z.object({ rating: weight.nullable(), unit: z.enum(["kg", "lb"]), basis: z.enum(["unknown", "per_tube", "per_side", "total"]), tubesPerSide: z.number().int().min(1).max(3).nullable() }).nullable(),
  supports: z.object({ chair: z.boolean(), wall: z.boolean() })
}).strict().superRefine((config, ctx) => {
  if (new Set(config.selected).size !== config.selected.length || !config.selected.includes(config.primary)) ctx.addIssue({code:"custom", message:"Choose a primary equipment option from your selections. / 請從已選器材中選擇主力器材。"});
  if (config.selected.some(kind => kind === "dumbbells" || kind === "full_gym") !== Boolean(config.dumbbells)) ctx.addIssue({code:"custom", message:"Enter the working weight per dumbbell and quantity. / 請填寫每個啞鈴的訓練重量及數量。"});
  if (config.selected.includes("kit") !== Boolean(config.kit)) ctx.addIssue({code:"custom", message:"Kit settings must match the selected equipment. / 套裝設定須與器材選項一致。"});
});
export type EquipmentConfig = z.infer<typeof equipmentConfigSchema>;
const prefix = "equipment:v1:";
export function isStructuredEquipment(value: string | null | undefined) { return value?.startsWith("equipment:") ?? false; }
export function readEquipmentConfig(value: string | null | undefined): EquipmentConfig | null {
  if (!value?.startsWith(prefix)) return null;
  try { const parsed=equipmentConfigSchema.safeParse(JSON.parse(value.slice(prefix.length))); return parsed.success ? parsed.data : null; } catch { return null; }
}
export function serializeEquipment(config: EquipmentConfig) { return prefix + JSON.stringify(equipmentConfigSchema.parse(config)); }
export function emptyEquipment(): EquipmentConfig {
  return {version:1,selected:["bodyweight"],primary:"bodyweight",dumbbells:null,kit:null,supports:{chair:false,wall:false}};
}
export function configAllows(exercise: ExerciseDefinition, config: EquipmentConfig) {
  if (exercise.equipment.includes("band")) return false; // These controls do not confirm a flat band.
  if (exercise.equipment.some(e => ["handled-tubes-foot-straps","padded-chest-expander","kit-bar"].includes(e)) && !config.selected.includes("kit")) return false;
  if (exercise.equipment.includes("chair") && !config.supports.chair) return false;
  if (exercise.equipment.includes("wall") && !config.supports.wall) return false;
  if (exercise.equipment.includes("dumbbells")) {
    if (!config.dumbbells) return false;
    if (!["goblet-squat","supported-dumbbell-row"].includes(exercise.id) && config.dumbbells.count < 2) return false;
  }
  return true;
}
export function equipmentSummary(config: EquipmentConfig) {
  const lines: string[] = config.selected.map(kind => equipmentKinds[kind]);
  if (config.dumbbells) lines.push(`${config.dumbbells.count} × ${config.dumbbells.weight} ${config.dumbbells.unit} per dumbbell / 每個啞鈴`);
  if (config.kit) lines.push(kitRatingLabel(config.kit));
  return lines.join(" · ");
}
function kitRatingLabel(kit: NonNullable<EquipmentConfig["kit"]>) {
  const basis={unknown:"basis unspecified / 標示基準未明",per_tube:"per tube / 每條管",per_side:"per side / 每側",total:"whole assembly / 整組"}[kit.basis];
  return kit.rating === null ? "Kit resistance rating unspecified / 套裝阻力標示未填" : `Kit label: ${kit.rating} ${kit.unit}, ${basis}; not constant load / 非固定負重`;
}
export function loadCaption(exercise: ExerciseDefinition, config: EquipmentConfig) {
  if (exercise.equipment.includes("dumbbells") && config.dumbbells) return `Working weight / 訓練重量: ${config.dumbbells.weight} ${config.dumbbells.unit} per dumbbell / 每個`;
  if (exercise.equipment.some(e=>["handled-tubes-foot-straps","padded-chest-expander","kit-bar"].includes(e)) && config.kit) return kitRatingLabel(config.kit);
  return "";
}
// Weight is supplied by controls, not free-form generated prescription text.
export function hasGeneratedLoad(text: string) {
  return /(?<![a-z])(?:kg|kgs|kilograms?|kilos?|lb|lbs|pounds?)(?![a-z])|公斤|千克|磅|加重|減重|heavier|lighter|increase.{0,20}(?:weight|resistance)|decrease.{0,20}(?:weight|resistance)/i.test(text);
}
