import { readEquipmentConfig, isStructuredEquipment, configAllows } from "../equipmentConfig";
import type { ExerciseDefinition } from "./catalogue";

// Persist the explicit selection in the existing equipment text for old callers.
// Free text alone cannot establish a tube's attachments or permitted stretch.
export const bandSetups = {
  unspecified: "Not confirmed / 未確認",
  flat: "Flat band suitable for gripping and standing on / 可手握及腳踩的扁平彈力帶",
  foot_straps: "Handled tubes + matching foot straps / 手柄拉力管及配套腳套",
  both: "Flat band + foot-strap tubes / 扁平帶及腳套拉力管",
  innstar_primary: "INNSTAR kit — primary: chest, back, core / 主力器材：胸、背、核心"
} as const;
export type BandSetup = keyof typeof bandSetups;
const marker = /\[band-setup:(unspecified|flat|foot_straps|both|innstar_primary)\]/g;
export function bandSetup(value: string | null | undefined): BandSetup {
  const config = readEquipmentConfig(value);
  if (config) return config.selected.includes("kit") ? (config.primary === "kit" ? "innstar_primary" : "foot_straps") : "unspecified";
  const matches = [...(value ?? "").matchAll(marker)];
  return matches.length === 1 ? matches[0][1] as BandSetup : "unspecified";
}
export function equipmentDescription(value: string | null | undefined) {
  return (value ?? "").replace(marker, "").trim();
}
export function withBandSetup(description: string, setup: BandSetup) {
  return `${equipmentDescription(description)} [band-setup:${setup}]`.trim();
}
export function bandEquipmentCompatible(exercise: ExerciseDefinition, equipment: string | null | undefined) {
  const config = readEquipmentConfig(equipment);
  if (config) return configAllows(exercise, config);
  if (isStructuredEquipment(equipment)) return false;
  const setup = bandSetup(equipment);
  if (exercise.equipment.includes("band")) return setup === "flat" || setup === "both";
  if (exercise.equipment.some(part => part === "padded-chest-expander" || part === "kit-bar")) return setup === "innstar_primary";
  if (exercise.equipment.includes("handled-tubes-foot-straps")) return setup === "foot_straps" || setup === "both" || setup === "innstar_primary";
  return true;
}

export function missingKitFocus(exercises: ExerciseDefinition[], equipment: string | null | undefined) {
  if (bandSetup(equipment) !== "innstar_primary") return [];
  return (["chest", "back", "core"] as const).filter(focus => !exercises.some(exercise => exercise.focus === focus));
}
