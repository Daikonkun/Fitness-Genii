"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { PlanItemCard } from "@/components/PlanItemCard";
import { createClient } from "@/lib/supabase/client";
import { itemElapsedSeconds } from "@/lib/workout";
import type { ExerciseInterval, PlanItem } from "@/lib/types";

type WorkoutPlanProps = {
  planId: string;
  items: PlanItem[];
  intervals: ExerciseInterval[];
  interactive?: boolean;
  onDataChange?: (items: PlanItem[], intervals: ExerciseInterval[]) => void;
};

export function WorkoutPlan({
  planId,
  items,
  intervals,
  interactive = false,
  onDataChange
}: WorkoutPlanProps) {
  const [openDemonstrationId, setOpenDemonstrationId] = useState<string | null>(null);
  const [nowMs, setNowMs] = useState(() => Date.now());
  const [busyItemId, setBusyItemId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const activeInterval = intervals.find((interval) => !interval.ended_at) ?? null;
  const activeIntervalId = activeInterval?.id ?? null;

  useEffect(() => {
    if (!activeIntervalId) return;
    const timer = window.setInterval(() => setNowMs(Date.now()), 1000);
    return () => window.clearInterval(timer);
  }, [activeIntervalId]);

  const refresh = useCallback(async () => {
    const supabase = createClient();
    const itemsResult = await supabase
      .from("plan_items")
      .select("*")
      .eq("plan_id", planId)
      .order("section_position", { ascending: true })
      .order("item_position", { ascending: true });

    if (itemsResult.error) throw new Error(itemsResult.error.message);
    const refreshedItems = (itemsResult.data ?? []) as PlanItem[];
    const itemIds = refreshedItems.map((item) => item.id);
    const intervalsResult = itemIds.length
      ? await supabase
          .from("exercise_intervals")
          .select("*")
          .in("plan_item_id", itemIds)
          .order("started_at", { ascending: true })
      : { data: [], error: null };

    if (intervalsResult.error) throw new Error(intervalsResult.error.message);
    onDataChange?.(refreshedItems, (intervalsResult.data ?? []) as ExerciseInterval[]);
    setNowMs(Date.now());
  }, [onDataChange, planId]);

  useEffect(() => {
    if (!interactive) return;
    const syncWhenVisible = () => {
      if (document.visibilityState === "visible") refresh().catch(() => undefined);
    };
    window.addEventListener("focus", syncWhenVisible);
    document.addEventListener("visibilitychange", syncWhenVisible);
    return () => {
      window.removeEventListener("focus", syncWhenVisible);
      document.removeEventListener("visibilitychange", syncWhenVisible);
    };
  }, [interactive, refresh]);

  const sections = useMemo(() => {
    const grouped = new Map<number, PlanItem[]>();
    for (const item of items) {
      const sectionItems = grouped.get(item.section_position) ?? [];
      sectionItems.push(item);
      grouped.set(item.section_position, sectionItems);
    }
    return [...grouped.entries()].sort(([a], [b]) => a - b);
  }, [items]);

  async function toggleTimer(itemId: string) {
    setBusyItemId(itemId);
    setError(null);
    const supabase = createClient();
    const { error: toggleError } = await supabase.rpc("toggle_plan_item_timer", {
      p_plan_item_id: itemId
    });
    try {
      if (toggleError) throw new Error(toggleError.message);
      await refresh();
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Could not update the stopwatch.");
    } finally {
      setBusyItemId(null);
    }
  }

  async function toggleDone(item: PlanItem) {
    setBusyItemId(item.id);
    setError(null);
    const supabase = createClient();
    const { error: doneError } = await supabase.rpc("set_plan_item_done", {
      p_plan_item_id: item.id,
      p_done: !item.completed_at
    });
    try {
      if (doneError) throw new Error(doneError.message);
      await refresh();
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Could not update this exercise.");
    } finally {
      setBusyItemId(null);
    }
  }

  return (
    <div className="workout-plan">
      {error ? <div className="form-error">{error}</div> : null}
      {sections.map(([sectionPosition, sectionItems]) => (
        <section className="workout-section" key={sectionPosition}>
          <div className="workout-section-heading">
            <h3>{sectionItems[0].section_title_en}</h3>
            <span>{sectionItems[0].section_title_zh}</span>
          </div>
          <div className="workout-item-list">
            {sectionItems.map((item) => (
              <PlanItemCard
                key={item.id}
                item={item}
                demonstrationOpen={openDemonstrationId === item.id}
                onDemonstrationToggle={() => setOpenDemonstrationId((current) => current === item.id ? null : item.id)}
                elapsedSeconds={itemElapsedSeconds(item.id, intervals, nowMs)}
                active={activeInterval?.plan_item_id === item.id}
                interactive={interactive}
                busy={busyItemId === item.id}
                onToggle={() => toggleTimer(item.id)}
                onDone={() => toggleDone(item)}
              />
            ))}
          </div>
        </section>
      ))}
    </div>
  );
}
