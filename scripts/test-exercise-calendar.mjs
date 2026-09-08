import assert from "node:assert/strict";
import { loadTypeScriptModule } from "./lib/load-typescript.mjs";
const load = (name) => loadTypeScriptModule(new URL(name, import.meta.url).pathname);
const { monthCells, monthBounds, shiftMonth, dayStatus, groupRecordsByDate, calendarReducer, createCalendarState } = load("../src/lib/exerciseCalendar.ts");
const { fetchExerciseRecordsMonth } = load("../src/lib/exerciseRecords.ts");
const { getHongKongDate } = load("../src/lib/date.ts");

function record(overrides = {}) {
  return {
    id: "record-1", plan_id: "plan-1", user_id: "user-1", record_date: "2026-09-08",
    created_at: "2026-09-08T03:00:00Z", activity_summary: "Walk", status: "executed",
    duration_minutes: 10, duration_seconds: 600, completion_percentage: 100, ...overrides
  };
}

assert.equal(monthCells("2024-02").filter(Boolean).length, 29);
assert.equal(monthCells("2025-02").filter(Boolean).length, 28);
assert.equal(monthCells("2026-02")[6], "2026-02-01"); // Sunday
assert.equal(monthCells("2026-06")[0], "2026-06-01"); // Monday
assert.equal(monthCells("2026-08").length, 42);
assert.equal(shiftMonth("2026-12", 1), "2027-01");
assert.equal(shiftMonth("2026-01", -1), "2025-12");
assert.deepEqual(monthBounds("2026-12"), { start: "2026-12-01", end: "2027-01-01" });
assert.equal(getHongKongDate(new Date("2026-08-31T15:59:59Z")), "2026-08-31");
assert.equal(getHongKongDate(new Date("2026-08-31T16:00:00Z")), "2026-09-01");

const complete = record();
const partial = record({ id: "partial", plan_id: "plan-2", completion_percentage: 30 });
const unfinished = record({ id: "unfinished", plan_id: "plan-3", status: "unfinished" });
assert.equal(dayStatus([]), "neutral");
assert.equal(dayStatus([unfinished]), "neutral");
assert.equal(dayStatus([partial]), "partial");
assert.equal(dayStatus([record({ completion_percentage: 0, duration_seconds: 1, duration_minutes: 0 })]), "partial");
assert.equal(dayStatus([record({ completion_percentage: 0, duration_seconds: 0, duration_minutes: 1 })]), "partial");
assert.equal(dayStatus([record({ completion_percentage: 0, duration_seconds: 0, duration_minutes: 0 })]), "neutral");
assert.equal(dayStatus([unfinished, partial, complete]), "complete");
assert.deepEqual(groupRecordsByDate([complete, partial, unfinished]).get("2026-09-08"), [complete, partial, unfinished]);

// A navigation response or failure from an older request must not change the latest month.
let state = createCalendarState("2026-09", [complete]);
state = calendarReducer(state, { type: "load", month: "2026-08", requestId: 1 });
state = calendarReducer(state, { type: "load", month: "2026-07", requestId: 2 });
assert.equal(calendarReducer(state, { type: "loaded", requestId: 1, records: [complete] }), state);
assert.equal(calendarReducer(state, { type: "failed", requestId: 1, error: "Old failure" }), state);
state = calendarReducer(state, { type: "failed", requestId: 2, error: "Try again" });
assert.equal(state.error, "Try again");
assert.equal(state.loading, false);
state = calendarReducer(state, { type: "load", month: "2026-07", requestId: 3 });
state = calendarReducer(state, { type: "loaded", requestId: 3, records: [] });
assert.equal(state.error, null);
assert.deepEqual(state.records, []);

// A successful save remains authoritative over an in-flight stale snapshot.
state = createCalendarState("2026-09", [partial]);
state = calendarReducer(state, { type: "load", month: "2026-09", requestId: 1 });
const saved = { ...partial, completion_percentage: 100, activity_summary: "Updated workout" };
state = calendarReducer(state, { type: "saved", record: saved });
assert.equal(dayStatus(state.records), "complete");
state = calendarReducer(state, { type: "loaded", requestId: 1, records: [partial] });
assert.deepEqual(state.records, [saved]);
// Even a response without the new record must retain the save.
state = calendarReducer(state, { type: "load", month: "2026-09", requestId: 2 });
state = calendarReducer(state, { type: "loaded", requestId: 2, records: [] });
assert.deepEqual(state.records, [saved]);
state = calendarReducer(state, { type: "load", month: "2026-08", requestId: 3 });
state = calendarReducer(state, { type: "saved", record: complete });
assert.deepEqual(state.records, []);
state = calendarReducer(state, { type: "load", month: "2026-09", requestId: 4 });
state = calendarReducer(state, { type: "loaded", requestId: 4, records: [] });
assert.equal(state.records.length, 2);
// Updating a legacy record replaces the same plan; independent records with no plan survive.
state = calendarReducer(state, { type: "saved", record: { ...complete, id: "replacement" } });
assert.equal(state.records.length, 2);
state = calendarReducer(state, { type: "saved", record: record({ id: "manual-1", plan_id: null }) });
state = calendarReducer(state, { type: "saved", record: record({ id: "manual-2", plan_id: null }) });
assert.equal(state.records.length, 4);

// Exercise the real loader against a query double that enforces owner and date filtering.
function queryClient(rows, failAt = -1) {
  const requests = [];
  return {
    requests,
    from(table) {
      assert.equal(table, "exercise_records");
      const filters = [];
      const query = {
        select: () => query,
        eq: (key, value) => { filters.push((row) => row[key] === value); return query; },
        gte: (key, value) => { filters.push((row) => row[key] >= value); return query; },
        lt: (key, value) => { filters.push((row) => row[key] < value); return query; },
        order: () => query,
        range: async (start, end) => {
          requests.push([start, end]);
          if (requests.length === failAt) return { error: new Error("Query failed"), data: null };
          return { error: null, data: rows.filter((row) => filters.every((filter) => filter(row))).slice(start, end + 1) };
        }
      };
      return query;
    }
  };
}
const monthRecords = Array.from({ length: 521 }, (_, index) => record({ id: `row-${index}`, plan_id: `plan-${index}` }));
const client = queryClient([
  record({ record_date: "2026-08-31" }), ...monthRecords,
  record({ record_date: "2026-10-01" }), record({ user_id: "someone-else" })
]);
assert.deepEqual(await fetchExerciseRecordsMonth(client, "user-1", "2026-09"), monthRecords);
assert.deepEqual(client.requests, [[0, 499], [500, 999]]);
assert.deepEqual(await fetchExerciseRecordsMonth(queryClient([]), "user-1", "2026-09"), []);
await assert.rejects(fetchExerciseRecordsMonth(queryClient(monthRecords, 2), "user-1", "2026-09"), /Query failed/);
console.log("Calendar dates, day statuses, save/navigation races and monthly queries passed.");
