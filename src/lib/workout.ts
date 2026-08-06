import type { ExerciseInterval, PlanItem } from "@/lib/types";

export function intervalSeconds(interval: ExerciseInterval, nowMs = Date.now()) {
  if (interval.ended_at) return interval.duration_seconds;
  return Math.max(0, Math.floor((nowMs - new Date(interval.started_at).getTime()) / 1000));
}

export function itemElapsedSeconds(
  itemId: string,
  intervals: ExerciseInterval[],
  nowMs = Date.now()
) {
  return intervals
    .filter((interval) => interval.plan_item_id === itemId)
    .reduce((total, interval) => total + intervalSeconds(interval, nowMs), 0);
}

export function workoutMetrics(items: PlanItem[], intervals: ExerciseInterval[], nowMs = Date.now()) {
  const completedItems = items.filter((item) => item.completed_at).length;
  const durationSeconds = items.reduce(
    (total, item) => total + itemElapsedSeconds(item.id, intervals, nowMs),
    0
  );

  return {
    completedItems,
    totalItems: items.length,
    durationSeconds,
    completionPercentage: items.length ? Math.round((completedItems / items.length) * 100) : 0
  };
}

export function formatStopwatch(totalSeconds: number) {
  const safeSeconds = Math.max(0, Math.floor(totalSeconds));
  const hours = Math.floor(safeSeconds / 3600);
  const minutes = Math.floor((safeSeconds % 3600) / 60);
  const seconds = safeSeconds % 60;
  return [hours, minutes, seconds].map((value) => String(value).padStart(2, "0")).join(":");
}
