"use client";
import { useCallback, useState } from "react";
import { WorkoutPlan } from "@/components/WorkoutPlan";
import type { PlanItem, ExerciseInterval } from "@/lib/types";

// Test surface: requests are intercepted by the browser test, never saved to a real account.
const initialItems: PlanItem[] = ["March in place", "Squats"].map((title, index) => ({
  id: `lap-review-${index}`, user_id: "review", plan_id: "lap-review",
  section_type: "main_workout", section_title_en: "Lap stopwatch review", section_title_zh: "計時測試",
  section_position: 0, item_position: index, title_en: title, title_zh: "訓練動作",
  description_en: "Keep a comfortable pace.", description_zh: "保持舒適的速度。",
  prescription: "2 minutes", planned_seconds: 120, completed_at: null,
  lap_number: 1, lap_start_total_seconds: 0, created_at: "2026-10-12T00:00:00Z"
}));
export function StopwatchPreview() {
  const [items, setItems] = useState(initialItems);
  const [intervals, setIntervals] = useState<ExerciseInterval[]>([]);
  const update = useCallback((nextItems: PlanItem[], nextIntervals: ExerciseInterval[]) => {
    setItems(nextItems); setIntervals(nextIntervals);
  }, []);
  return <main style={{maxWidth: 1000, margin: "32px auto", padding: 16}}>
    <h1>Stopwatch preview</h1>
    <WorkoutPlan planId="lap-review" items={items} intervals={intervals} interactive onDataChange={update}/>
  </main>;
}
