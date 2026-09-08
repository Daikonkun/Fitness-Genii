"use client";

import { useReducer, useRef, useState } from "react";
import { ExerciseRecordsCalendar } from "@/components/ExerciseRecordsCalendar";
import { calendarReducer, createCalendarState } from "@/lib/exerciseCalendar";
import { RECORDS_LOAD_ERROR } from "@/lib/exerciseRecords";
import type { ExerciseRecord } from "@/lib/types";

const today = "2026-09-08";
function record(id: string, day: string, completion: number, status: "executed" | "unfinished" = "executed"): ExerciseRecord {
  return {
    id, user_id: "preview", plan_id: id, record_date: day, status,
    activity_summary: `${id}: a saved exercise session.`, duration_minutes: completion ? 20 : 0,
    duration_seconds: completion ? 1200 : 0, completion_percentage: completion,
    created_at: `${day}T08:00:00Z`
  };
}
const fixtures = [
  record("Full workout", "2026-09-02", 100),
  record("Partial workout", "2026-09-04", 40),
  record("Unfinished workout", "2026-09-06", 0, "unfinished"),
  record("Today workout", today, 30),
  record("Extra session", today, 100),
  ...Array.from({ length: 31 }, (_, index) => record(`August session ${index + 1}`, `2026-08-${String(index + 1).padStart(2, "0")}`, 100))
];

export function CalendarPreview() {
  const [state, dispatch] = useReducer(calendarReducer, undefined, () => createCalendarState("2026-09", fixtures.filter((row) => row.record_date.startsWith("2026-09"))));
  const requestId = useRef(0);
  const [failNext, setFailNext] = useState(false);

  function loadMonth(month: string) {
    const id = ++requestId.current;
    const fail = failNext;
    setFailNext(false);
    dispatch({ type: "load", month, requestId: id });
    setTimeout(() => {
      if (fail) dispatch({ type: "failed", requestId: id, error: RECORDS_LOAD_ERROR });
      else dispatch({ type: "loaded", requestId: id, records: fixtures.filter((row) => row.record_date.startsWith(month)) });
    }, month === "2026-08" ? 1200 : 150);
  }

  return <main style={{ maxWidth: 850, margin: "32px auto", padding: 16 }}>
    <h1>Exercise calendar review</h1>
    <p>Sample records only; no account data is changed.</p>
    <div style={{ display: "flex", gap: 8, flexWrap: "wrap", marginBottom: 20 }}>
      <button className="calendar-nav-button" onClick={() => setFailNext(true)}>{failNext ? "Next load will fail" : "Fail next load"}</button>
      <button className="calendar-nav-button" onClick={() => dispatch({ type: "saved", record: record("Partial workout", "2026-09-04", 100) })}>Complete September 4</button>
      <button className="calendar-nav-button" onClick={() => dispatch({ type: "saved", record: record("New workout", "2026-09-10", 100) })}>Save September 10</button>
    </div>
    <ExerciseRecordsCalendar state={state} today={today} onMonthChange={loadMonth} onRetry={() => loadMonth(state.month)} />
  </main>;
}
