import { notFound } from "next/navigation";
import { exercises, canonicalCopy } from "@/lib/exercises/catalogue";
import { WorkoutPlan } from "@/components/WorkoutPlan";
import type { PlanItem } from "@/lib/types";

// Local review surface for all bundled movement assets; unreachable in production.
export default function ExerciseReviewPage() {
  if (process.env.NODE_ENV !== "development") notFound();
  const items: PlanItem[] = exercises.map((exercise, index) => ({
    ...canonicalCopy(exercise),
    exercise_id: exercise.id,
    id: `review-${index}`,
    user_id: "review",
    plan_id: "review",
    section_type: "main_workout",
    section_title_en: "Exercise sketch library",
    section_title_zh: "動作示範圖庫",
    section_position: 0,
    item_position: index,
    prescription: "Demo review / 示範檢查",
    planned_seconds: 60,
    completed_at: index === 1 ? "2026-09-07T00:00:00Z" : null,
    created_at: "2026-09-07T00:00:00Z"
  }));
  return (
    <main style={{ maxWidth: 1000, margin: "32px auto", padding: 16 }}>
      <h1>Exercise demonstrations</h1>
      <p>Local visual review · 28 movements · workout tracking disabled</p>
      <WorkoutPlan planId="review" items={items} intervals={[]} />
    </main>
  );
}
