"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { PlanItemCard } from "@/components/PlanItemCard";
import { createClient } from "@/lib/supabase/client";
import { itemStopwatch } from "@/lib/workout";
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
  const [busy, setBusy] = useState(false);
  const [needsSync, setNeedsSync] = useState(false);
  const operationPending = useRef(false);
  const syncBlocked = useRef(false);
  const syncVersion = useRef(0);
  const [error, setError] = useState<string | null>(null);
  const activeInterval = intervals.find((interval) => !interval.ended_at) ?? null;
  const activeIntervalId = activeInterval?.id ?? null;

  useEffect(() => {
    if (!activeIntervalId) return;
    const timer = window.setInterval(() => setNowMs(Date.now()), 1000);
    return () => window.clearInterval(timer);
  }, [activeIntervalId]);

  const refresh = useCallback(async () => {
    const version = ++syncVersion.current;
    const supabase = createClient();
    const itemsResult = await supabase
      .from("plan_items")
      .select("*")
      .eq("plan_id", planId)
      .order("section_position", { ascending: true })
      .order("item_position", { ascending: true });

    if (version !== syncVersion.current) return false;
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

    if (version !== syncVersion.current) return false;
    if (intervalsResult.error) throw new Error(intervalsResult.error.message);
    onDataChange?.(refreshedItems, (intervalsResult.data ?? []) as ExerciseInterval[]);
    setNowMs(Date.now());
    return true;
  }, [onDataChange, planId]);

  const invalidateRefresh = useCallback(() => { ++syncVersion.current; }, []);

  useEffect(() => {
    if (!interactive) return;
    const syncWhenVisible = () => {
      if (document.visibilityState !== "visible" || operationPending.current) return;
      refresh().then((applied) => {
        if (!applied) return;
        syncBlocked.current = false;
        setNeedsSync(false);
        setError(null);
      }).catch(() => {
        syncBlocked.current = true;
        setNeedsSync(true);
        setError("Could not synchronize the stopwatch. Refresh its saved state before continuing.");
      });
    };
    window.addEventListener("focus", syncWhenVisible);
    document.addEventListener("visibilitychange", syncWhenVisible);
    return () => {
      window.removeEventListener("focus", syncWhenVisible);
      document.removeEventListener("visibilitychange", syncWhenVisible);
      invalidateRefresh();
    };
  }, [interactive, refresh, invalidateRefresh]);

  const sections = useMemo(() => {
    const grouped = new Map<number, PlanItem[]>();
    for (const item of items) {
      const sectionItems = grouped.get(item.section_position) ?? [];
      sectionItems.push(item);
      grouped.set(item.section_position, sectionItems);
    }
    return [...grouped.entries()].sort(([a], [b]) => a - b);
  }, [items]);

  async function updateTimer(action: () => PromiseLike<{ error: { message: string } | null }>) {
    if (operationPending.current || syncBlocked.current) return;
    operationPending.current = true;
    const operationVersion = ++syncVersion.current;
    setBusy(true);
    setError(null);
    try {
      const { error: mutationError } = await action();
      if (operationVersion !== syncVersion.current) return;
      if (mutationError) throw new Error(mutationError.message);
      await refresh();
    } catch (caught) {
      // An interrupted response may have committed. Never automatically replay a mutation.
      syncBlocked.current = true;
      setNeedsSync(true);
      setError(caught instanceof Error ? caught.message : "Could not update the stopwatch.");
    } finally {
      operationPending.current = false;
      setBusy(false);
    }
  }

  async function retrySync() {
    if (operationPending.current) return;
    operationPending.current = true;
    setBusy(true);
    try {
      if (!await refresh()) return;
      syncBlocked.current = false;
      setNeedsSync(false);
      setError(null);
    } catch {
      setError("Could not synchronize the stopwatch. Please retry.");
    } finally {
      operationPending.current = false;
      setBusy(false);
    }
  }

  return (
    <div className="workout-plan">
      {error ? <div className="form-error" role="alert">{error}
        {needsSync ? <button type="button" className="secondary-button" disabled={busy} onClick={retrySync}>Refresh stopwatch</button> : null}
      </div> : null}
      {sections.map(([sectionPosition, sectionItems]) => (
        <section className="workout-section" key={sectionPosition}>
          <div className="workout-section-heading">
            <h3>{sectionItems[0].section_title_en}</h3>
            <span>{sectionItems[0].section_title_zh}</span>
          </div>
          <div className="workout-item-list">
            {sectionItems.map((item) => {
              const timing = itemStopwatch(item, intervals, nowMs);
              return (
              <PlanItemCard
                key={item.id}
                item={item}
                demonstrationOpen={openDemonstrationId === item.id}
                onDemonstrationToggle={() => setOpenDemonstrationId((current) => current === item.id ? null : item.id)}
                elapsedSeconds={timing.totalSeconds}
                lapSeconds={timing.lapSeconds}
                lapNumber={timing.lapNumber}
                active={activeInterval?.plan_item_id === item.id}
                interactive={interactive}
                busy={busy || needsSync}
                onToggle={() => updateTimer(() => createClient().rpc("toggle_plan_item_timer", { p_plan_item_id: item.id }))}
                onDone={() => updateTimer(() => createClient().rpc("set_plan_item_done", { p_plan_item_id: item.id, p_done: !item.completed_at }))}
                onLap={() => updateTimer(() => createClient().rpc("advance_plan_item_lap", { p_plan_item_id: item.id, p_expected_lap_number: timing.lapNumber }))}
              />
            ); })}
          </div>
        </section>
      ))}
    </div>
  );
}
