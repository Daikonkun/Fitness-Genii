import assert from "node:assert/strict";
import { loadTypeScriptModule as load } from "./lib/load-typescript.mjs";
const loadTypeScriptModule = (file) => load(new URL(file, import.meta.url).pathname);

const { formatStopwatch, intervalSeconds, itemElapsedSeconds, workoutMetrics } =
  loadTypeScriptModule("../src/lib/workout.ts");
const { structuredPlanSchema, structuredPlanToMarkdown } = loadTypeScriptModule(
  "../src/lib/planSchema.ts"
);
const baseItem = {
  id: "item-a",
  completed_at: null
};
const closedInterval = {
  plan_item_id: "item-a",
  started_at: "2026-08-06T00:00:00.000Z",
  ended_at: "2026-08-06T00:01:05.000Z",
  duration_seconds: 65
};
const activeInterval = {
  plan_item_id: "item-a",
  started_at: "2026-08-06T00:02:00.000Z",
  ended_at: null,
  duration_seconds: 0
};
const nowMs = new Date("2026-08-06T00:02:35.000Z").getTime();

assert.equal(formatStopwatch(0), "00:00:00");
assert.equal(formatStopwatch(3661), "01:01:01");
assert.equal(intervalSeconds(closedInterval, nowMs), 65);
assert.equal(intervalSeconds(activeInterval, nowMs), 35);
assert.equal(itemElapsedSeconds("item-a", [closedInterval, activeInterval], nowMs), 100);
assert.equal(itemElapsedSeconds("item-b", [closedInterval, activeInterval], nowMs), 0);

assert.deepEqual(
  workoutMetrics(
    [baseItem, { ...baseItem, id: "item-b", completed_at: "2026-08-06T00:03:00.000Z" }],
    [closedInterval, activeInterval],
    nowMs
  ),
  {
    completedItems: 1,
    totalItems: 2,
    durationSeconds: 100,
    completionPercentage: 50
  }
);

const validPlan = {
  title_en: "Strength day",
  title_zh: "力量訓練日",
  sections: [
    {
      section_type: "warm_up",
      title_en: "Warm-up",
      title_zh: "熱身",
      items: [
        {
          title_en: "March in place",
          title_zh: "原地踏步",
          description_en: "Raise the knees gently.",
          description_zh: "輕柔抬膝。",
          prescription: "2 minutes",
          planned_seconds: 120
        }
      ]
    }
  ],
  completion_suggestion_en: "Record how the session felt.",
  completion_suggestion_zh: "記錄訓練感受。"
};

assert.equal(structuredPlanSchema.safeParse(validPlan).success, true);
assert.equal(structuredPlanSchema.safeParse({ ...validPlan, sections: [] }).success, false);
assert.match(structuredPlanToMarkdown(validPlan), /March in place \/ 原地踏步/);

console.log("Workout timing and structured plan tests passed.");
