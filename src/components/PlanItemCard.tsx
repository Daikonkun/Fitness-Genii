"use client";

import { ExerciseSketch } from "@/components/ExerciseSketch";
import { resolveExercise } from "@/lib/exercises/catalogue";
import { Check, Clock3, Flag, Pause, Play } from "lucide-react";
import { formatStopwatch } from "@/lib/workout";
import type { PlanItem } from "@/lib/types";

type PlanItemCardProps = {
  item: PlanItem;
  demonstrationOpen?: boolean;
  onDemonstrationToggle?: () => void;
  elapsedSeconds: number;
  lapSeconds?: number;
  lapNumber?: number;
  active: boolean;
  interactive?: boolean;
  busy?: boolean;
  onToggle?: () => void;
  onDone?: () => void;
  onLap?: () => void;
};

export function PlanItemCard({
  item,
  elapsedSeconds,
  lapSeconds = elapsedSeconds,
  lapNumber = 1,
  active,
  interactive = false,
  busy = false,
  onToggle,
  onDone,
  onLap,
  demonstrationOpen = false,
  onDemonstrationToggle
}: PlanItemCardProps) {
  const exercise = resolveExercise(item);
  const demoId = `exercise-demo-${item.id}`;
  const done = Boolean(item.completed_at);
  const state = done ? "done" : active ? "active" : elapsedSeconds > 0 ? "paused" : "ready";
  const stateLabel = done ? "Done" : active ? "Running" : elapsedSeconds > 0 ? "Paused" : "Ready";

  return (
    <article className={`plan-item-card ${state}`}>
      <div className="plan-item-main">
        <div className="plan-item-controls">
          <button className="plan-item-action" type="button" aria-pressed={active && !done}
            aria-label={`${active && !done ? "Pause" : "Start"}: ${item.title_en}`}
            disabled={!interactive || busy || done} onClick={onToggle}>
            {active && !done ? <Pause size={18} aria-hidden="true" /> : <Play size={18} aria-hidden="true" />}
          </button>
          <button className="plan-item-lap" type="button" aria-label={`New lap: ${item.title_en}`}
            disabled={!interactive || busy || done || !active} onClick={onLap}>
            <Flag size={14} aria-hidden="true" /> Lap
          </button>
        </div>
        <span className="plan-item-copy">
          <strong>{item.title_en}</strong>
          <span className="plan-item-zh">{item.title_zh}</span>
          <span>{item.description_en}</span>
          <span>{item.description_zh}</span>
          <span className="plan-item-prescription">{item.prescription}</span>
        </span>
        <div className="plan-item-timers" aria-live={active && !done ? "off" : "polite"}>
          <div className="plan-item-timer"><small>Total</small><span><Clock3 size={15} aria-hidden="true" /> {formatStopwatch(elapsedSeconds)}</span></div>
          <div className="plan-item-timer lap"><small>Lap {lapNumber}</small><span>{formatStopwatch(lapSeconds)}</span></div>
          <small className="plan-item-timer-state">{stateLabel}</small>
        </div>
      </div>
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
      <div className="exercise-demo">
        {exercise ? <>
          <button className="exercise-demo-toggle" type="button" aria-expanded={demonstrationOpen} aria-controls={demoId} onClick={onDemonstrationToggle}>
            {demonstrationOpen ? "Hide demonstration / 收起示範" : "How to do it / 動作示範"}<span aria-hidden="true">{demonstrationOpen ? "−" : "+"}</span>
          </button>
          <div id={demoId} hidden={!demonstrationOpen}>
            {demonstrationOpen && <ExerciseSketch exercise={exercise}/>}
          </div>
        </> : <p className="exercise-demo-unavailable">Demonstration unavailable for this saved move. / 此已儲存動作暫無示範。</p>}
      </div>
    </article>
  );
}
