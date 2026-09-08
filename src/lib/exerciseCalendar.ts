import type { ExerciseRecord } from "@/lib/types";

export type DayStatus = "complete" | "partial" | "neutral";

// Treat stored YYYY-MM-DD values as calendar dates, independent of browser timezone.
export function shiftMonth(month: string, offset: number): string {
  const [year, number] = month.split("-").map(Number);
  const date = new Date(Date.UTC(year, number - 1 + offset, 1));
  return date.toISOString().slice(0, 7);
}

export function monthBounds(month: string) {
  return { start: `${month}-01`, end: `${shiftMonth(month, 1)}-01` };
}

export function monthCells(month: string): Array<string | null> {
  const first = new Date(`${month}-01T00:00:00Z`);
  const offset = (first.getUTCDay() + 6) % 7;
  const last = new Date(`${shiftMonth(month, 1)}-01T00:00:00Z`);
  last.setUTCDate(0);
  const days = last.getUTCDate();
  return Array.from({ length: Math.ceil((offset + days) / 7) * 7 }, (_, index) => {
    const day = index - offset + 1;
    return day >= 1 && day <= days ? `${month}-${String(day).padStart(2, "0")}` : null;
  });
}

export function calendarLabel(date: string, monthOnly = false): string {
  return new Intl.DateTimeFormat("en-HK", {
    timeZone: "UTC",
    year: "numeric",
    month: "long",
    ...(monthOnly ? {} : { day: "numeric" as const })
  }).format(new Date(`${date.length === 7 ? `${date}-01` : date}T00:00:00Z`));
}

export function groupRecordsByDate(records: ExerciseRecord[]) {
  const groups = new Map<string, ExerciseRecord[]>();
  for (const record of records) {
    const group = groups.get(record.record_date) ?? [];
    group.push(record);
    groups.set(record.record_date, group);
  }
  return groups;
}

export function dayStatus(records: ExerciseRecord[]): DayStatus {
  const executed = records.filter((record) => record.status === "executed");
  if (executed.some((record) => record.completion_percentage === 100)) return "complete";
  if (executed.some((record) => record.completion_percentage > 0 || record.duration_seconds > 0 || record.duration_minutes > 0)) return "partial";
  return "neutral";
}

function mergeRecords(records: ExerciseRecord[], updates: ExerciseRecord[]) {
  const key = (record: ExerciseRecord) => record.plan_id ? `plan:${record.plan_id}` : `record:${record.id}`;
  const merged = new Map(records.map((record) => [key(record), record]));
  for (const record of updates) merged.set(key(record), record);
  return [...merged.values()].sort((a, b) => b.created_at.localeCompare(a.created_at) || a.id.localeCompare(b.id));
}

export type CalendarState = {
  month: string;
  records: ExerciseRecord[];
  savedRecords: ExerciseRecord[];
  loading: boolean;
  error: string | null;
  requestId: number;
};

export type CalendarAction =
  | { type: "load"; month: string; requestId: number }
  | { type: "loaded"; requestId: number; records: ExerciseRecord[] }
  | { type: "failed"; requestId: number; error: string }
  | { type: "saved"; record: ExerciseRecord };

export function createCalendarState(month: string, records: ExerciseRecord[], error: string | null = null): CalendarState {
  return { month, records, savedRecords: [], loading: false, error, requestId: 0 };
}

export function calendarReducer(state: CalendarState, action: CalendarAction): CalendarState {
  if (action.type === "saved") {
    return {
      ...state,
      savedRecords: mergeRecords(state.savedRecords, [action.record]),
      records: action.record.record_date.startsWith(`${state.month}-`)
        ? mergeRecords(state.records, [action.record]) : state.records
    };
  }
  if (action.type === "load") {
    return {
      ...state, month: action.month, requestId: action.requestId, loading: true, error: null,
      records: action.month === state.month ? state.records : []
    };
  }
  if (action.requestId !== state.requestId) return state;
  if (action.type === "failed") return { ...state, loading: false, error: action.error };
  // Local successful saves win over snapshots that may have started before the save.
  return {
    ...state, loading: false, error: null,
    records: mergeRecords(action.records, state.savedRecords.filter((record) => record.record_date.startsWith(`${state.month}-`)))
  };
}
