"use client";

import { Check, Clock3, Pause, Play } from "lucide-react";
import { formatStopwatch } from "@/lib/workout";
import type { PlanItem } from "@/lib/types";

type PlanItemCardProps = {
  item: PlanItem;
  elapsedSeconds: number;
  active: boolean;
  interactive?: boolean;
  busy?: boolean;
  onToggle?: () => void;
  onDone?: () => void;
};

export function PlanItemCard({
  item,
  elapsedSeconds,
  active,
  interactive = false,
  busy = false,
  onToggle,
  onDone
}: PlanItemCardProps) {
  const done = Boolean(item.completed_at);
  const state = done ? "done" : active ? "active" : elapsedSeconds > 0 ? "paused" : "ready";
  const stateLabel = done ? "Done" : active ? "Running" : elapsedSeconds > 0 ? "Paused" : "Ready";

  return (
    <article className={`plan-item-card ${state}`}>
      <button
        className="plan-item-main"
        type="button"
        aria-pressed={active}
        aria-label={`${active ? "Pause" : "Start"} ${item.title_en}. Elapsed ${formatStopwatch(elapsedSeconds)}`}
        disabled={!interactive || busy || done}
        onClick={onToggle}
      >
        <span className="plan-item-action" aria-hidden="true">
          {active ? <Pause size={18} /> : <Play size={18} />}
        </span>
        <span className="plan-item-copy">
          <strong>{item.title_en}</strong>
          <span className="plan-item-zh">{item.title_zh}</span>
          <span>{item.description_en}</span>
          <span>{item.description_zh}</span>
          <span className="plan-item-prescription">{item.prescription}</span>
        </span>
        <span className="plan-item-timer" aria-live={active ? "off" : "polite"}>
          <Clock3 size={15} aria-hidden="true" />
          {formatStopwatch(elapsedSeconds)}
          <small>{stateLabel}</small>
        </span>
      </button>
      <button
        className="plan-item-done"
        type="button"
        aria-pressed={done}
        aria-label={`${done ? "Mark not done" : "Mark done"}: ${item.title_en}`}
        disabled={!interactive || busy}
        onClick={onDone}
      >
        <Check size={16} aria-hidden="true" />
        {done ? "Done" : "Mark done"}
      </button>
    </article>
  );
}
