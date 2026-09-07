"use client";

import { useEffect, useRef, useState } from "react";
import type { ExerciseDefinition } from "@/lib/exercises/catalogue";
import {
  interpolatePose,
  sketches,
  type Pose,
  type Sketch
} from "@/lib/exercises/poses";

export function SketchFigure({
  pose,
  sketch,
  label
}: {
  pose: Pose;
  sketch: Sketch;
  label: string;
}) {
  const [head, shoulder, hip, fe, fw, ne, nw, fk, fa, nk, na] = pose;
  const line = (...points: number[][]) =>
    points.map((p) => p.join(",")).join(" ");
  const front = sketch.view === "Front";
  const limbs = [
    line([shoulder[0] - (front ? 10 : 0), shoulder[1]], fe, fw),
    line([hip[0] - (front ? 7 : 0), hip[1]], fk, fa),
    line([shoulder[0] + (front ? 10 : 0), shoulder[1]], ne, nw),
    line([hip[0] + (front ? 7 : 0), hip[1]], nk, na)
  ];
  const dumbbell = ([x, y]: number[], key: string) => (
    <g key={key} stroke="#255f53" strokeWidth="3" fill="#dcebe4">
      <path d={`M${x - 13},${y}h26`} />
      <rect x={x - 17} y={y - 8} width="7" height="16" rx="2" />
      <rect x={x + 10} y={y - 8} width="7" height="16" rx="2" />
    </g>
  );
  return (
    <svg
      viewBox="0 0 300 250"
      role="img"
      aria-label={label}
      className="exercise-sketch"
    >
      <path d="M20 229H280" stroke="#ccd9d0" strokeWidth="2" />
      {sketch.prop === "wall" && (
        <path
          d="M254 24V229m0-190 15-15m-15 40 15-15m-15 40 15-15m-15 40 15-15m-15 40 15-15m-15 40 15-15m-15 40 15-15"
          stroke="#a7b9ae"
          strokeWidth="3"
        />
      )}
      {sketch.prop === "chair" && (
        <path
          d="M115 105V169H169M119 169V228M165 169V228"
          fill="none"
          stroke="#9d7c58"
          strokeWidth="7"
          strokeLinecap="round"
        />
      )}
      {sketch.prop === "support" && (
        <path
          d="M231 119V163H271M235 163V228M268 163V228"
          fill="none"
          stroke="#9d7c58"
          strokeWidth="7"
          strokeLinecap="round"
        />
      )}
      {sketch.band === "feet" && (
        <polyline
          points={line(fw, [fa[0], 227], [na[0], 227], nw)}
          fill="none"
          stroke="#c98338"
          strokeWidth="4"
        />
      )}
      {/* Double strokes form outlined limbs rather than bare joint sticks. */}
      {limbs.slice(0, 2).map((points, i) => (
        <g key={i} strokeLinecap="round" strokeLinejoin="round">
          <polyline
            points={points}
            fill="none"
            stroke="#7a9188"
            strokeWidth="14"
          />
          <polyline
            points={points}
            fill="none"
            stroke="#e2e9e3"
            strokeWidth="9"
          />
        </g>
      ))}
      <path
        d={`M${shoulder.join(",")} L${hip.join(",")}`}
        stroke="#365a4e"
        strokeWidth="30"
        strokeLinecap="round"
      />
      <path
        d={`M${shoulder.join(",")} L${hip.join(",")}`}
        stroke="#eef3e9"
        strokeWidth="25"
        strokeLinecap="round"
      />
      {limbs.slice(2).map((points, i) => (
        <g key={i} strokeLinecap="round" strokeLinejoin="round">
          <polyline
            points={points}
            fill="none"
            stroke="#365a4e"
            strokeWidth="14"
          />
          <polyline
            points={points}
            fill="none"
            stroke="#fafbf4"
            strokeWidth="9"
          />
        </g>
      ))}
      <path
        d={`M${shoulder.join(",")} L${head.join(",")}`}
        stroke="#365a4e"
        strokeWidth="9"
      />
      <circle
        cx={head[0]}
        cy={head[1]}
        r="14"
        fill="#fafbf4"
        stroke="#365a4e"
        strokeWidth="2.5"
      />
      <path
        d={`M${head[0] + 6} ${head[1] - 2}h2`}
        stroke="#365a4e"
        strokeWidth="2"
      />
      {[fa, na].map(([x, y], i) => (
        <path
          key={i}
          d={
            sketch.toeAnchor
              ? `M${x - 4} ${y + 3}L${x + 11} 223`
              : `M${x - 4} ${y + 3}h15`
          }
          stroke="#365a4e"
          strokeWidth="5"
          strokeLinecap="round"
        />
      ))}
      {sketch.band === "hands" && (
        <path
          d={`M${fw.join(",")} Q${(fw[0] + nw[0]) / 2},${(fw[1] + nw[1]) / 2 + 20} ${nw.join(",")}`}
          fill="none"
          stroke="#c98338"
          strokeWidth="4"
        />
      )}
      {sketch.weights === "both" && [dumbbell(fw, "far"), dumbbell(nw, "near")]}
      {sketch.weights === "near" && dumbbell(nw, "near")}
      {sketch.weights === "goblet" && (
        <g transform={`rotate(90 ${nw.join(" ")})`}>{dumbbell(nw, "goblet")}</g>
      )}
    </svg>
  );
}

export function ExerciseSketch({ exercise }: { exercise: ExerciseDefinition }) {
  const sketch = sketches[exercise.id];
  const [playing, setPlaying] = useState(false);
  const [reduced, setReduced] = useState(false);
  const [visible, setVisible] = useState(true);
  const [speed, setSpeed] = useState(1);
  const [progress, setProgress] = useState(0);
  const elapsed = useRef(0);
  useEffect(() => {
    const media = window.matchMedia("(prefers-reduced-motion: reduce)");
    const preference = () => {
      setReduced(media.matches);
      setPlaying(!media.matches);
    };
    const visibility = () => setVisible(document.visibilityState === "visible");
    preference();
    visibility();
    media.addEventListener("change", preference);
    document.addEventListener("visibilitychange", visibility);
    return () => {
      media.removeEventListener("change", preference);
      document.removeEventListener("visibilitychange", visibility);
    };
  }, []);
  useEffect(() => {
    if (!playing || !visible || !sketch) return;
    let frame = 0;
    let last: number | undefined;
    const tick = (time: number) => {
      if (last !== undefined)
        elapsed.current += Math.min(time - last, 100) * speed;
      last = time;
      setProgress(elapsed.current / (exercise.held ? 10000 : 6000));
      frame = requestAnimationFrame(tick);
    };
    frame = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frame);
  }, [playing, visible, speed, sketch, exercise.held]);
  if (!sketch)
    return (
      <div className="exercise-demo-instructions">
        <p>
          Sketch unavailable; follow these instructions. /
          示範暫未提供，請參閱以下說明。
        </p>
        <ol>
          {exercise.steps.map(([en, zh]) => (
            <li key={en}>
              <span>{en}</span>
              <span lang="zh-Hant">{zh}</span>
            </li>
          ))}
        </ol>
      </div>
    );
  const cycle = progress % 1;
  const phase = exercise.held
    ? cycle < 0.2
      ? 0
      : cycle < 0.8
        ? 1
        : 2
    : cycle < 0.25
      ? 0
      : cycle < 0.75
        ? 1
        : 2;
  return (
    <div className="exercise-demo-layout">
      <div className="exercise-demo-visual">
        <span className="exercise-demo-eyebrow">
          {sketch.view} view ·{" "}
          {sketch.view === "Front"
            ? "正面"
            : sketch.view === "Side"
              ? "側面"
              : "斜側面"}
        </span>
        {reduced && !playing ? (
          <div className="exercise-static-poses">
            {[sketch.poses[0], sketch.poses[1]].map((pose, index) => (
              <figure key={index}>
                <SketchFigure
                  pose={pose}
                  sketch={sketch}
                  label={`${exercise.title_en}: ${index ? "movement / hold" : "start"}`}
                />
                <figcaption>
                  {index ? "Movement / hold · 動作／保持" : "Start · 起始"}
                </figcaption>
              </figure>
            ))}
          </div>
        ) : (
          <>
            <SketchFigure
              pose={interpolatePose(sketch, progress, exercise.held)}
              sketch={sketch}
              label={`${exercise.title_en} demonstration / ${exercise.title_zh}示範`}
            />
            <p className="exercise-phase" aria-hidden="true">
              {
                [
                  "Start · 起始",
                  exercise.held ? "Hold · 保持" : "Move · 動作",
                  "Return · 返回"
                ][phase]
              }
            </p>
          </>
        )}
        <div className="exercise-demo-controls">
          <button
            type="button"
            onClick={() => setPlaying(!playing)}
            aria-label={
              playing
                ? "Pause demonstration / 暫停示範"
                : "Play demonstration / 播放示範"
            }
          >
            {playing ? "Pause / 暫停" : "Play / 播放"}
          </button>
          <label>
            Demo speed / 示範速度{" "}
            <select
              value={speed}
              onChange={(event) => setSpeed(Number(event.target.value))}
            >
              <option value={1}>1×</option>
              <option value={0.5}>0.5×</option>
            </select>
          </label>
        </div>
        <small>
          Demonstration speed only; follow your workout prescription.
          <br />
          此為示範速度；訓練請依照指定次數及時間。
        </small>
      </div>
      <div className="exercise-demo-instructions">
        <h4>How to do it / 動作示範</h4>
        <ol>
          {exercise.steps.map(([en, zh]) => (
            <li key={en}>
              <span>{en}</span>
              <span lang="zh-Hant">{zh}</span>
            </li>
          ))}
        </ol>
        <p className="exercise-form-cue">
          <strong>Form cue / 動作要點</strong>
          <span>{exercise.cue[0]}</span>
          <span lang="zh-Hant">{exercise.cue[1]}</span>
        </p>
      </div>
    </div>
  );
}
