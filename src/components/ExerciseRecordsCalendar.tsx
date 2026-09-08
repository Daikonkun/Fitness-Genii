"use client";

import { CalendarDays, Check, ChevronLeft, ChevronRight, CircleDot, X } from "lucide-react";
import { useId, useMemo, useRef, useState } from "react";
import { calendarLabel, dayStatus, groupRecordsByDate, monthCells, shiftMonth, type CalendarState } from "@/lib/exerciseCalendar";

const weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
const statusLabels = { complete: "Fully completed", partial: "Partial activity", neutral: "No completed activity" };

export function ExerciseRecordsCalendar({ state, today, onMonthChange, onRetry }: {
  state: CalendarState;
  today: string;
  onMonthChange: (month: string) => void;
  onRetry: () => void;
}) {
  const [selectedDate, setSelectedDate] = useState<string | null>(null);
  const dayButtons = useRef(new Map<string, HTMLButtonElement>());
  const detailsId = useId();
  const headingId = useId();
  const groups = useMemo(() => groupRecordsByDate(state.records), [state.records]);
  const cells = monthCells(state.month);
  const selectedRecords = selectedDate ? groups.get(selectedDate) ?? [] : [];

  function navigate(month: string) {
    setSelectedDate(null);
    onMonthChange(month);
  }

  function closeDetails() {
    if (selectedDate) dayButtons.current.get(selectedDate)?.focus();
    setSelectedDate(null);
  }

  return (
    <section className="panel records-panel exercise-calendar" aria-labelledby={headingId}>
      <div className="panel-heading">
        <CalendarDays size={18} aria-hidden="true" />
        <h2 id={headingId}>Exercise records</h2>
      </div>
      <div className="calendar-toolbar">
        <h3 aria-live="polite">{calendarLabel(state.month, true)}</h3>
        <div className="calendar-navigation">
          <button type="button" className="calendar-nav-button" aria-label="Previous month" onClick={() => navigate(shiftMonth(state.month, -1))}><ChevronLeft size={18} aria-hidden="true" /></button>
          <button type="button" className="calendar-nav-button" onClick={() => navigate(today.slice(0, 7))}>Today</button>
          <button type="button" className="calendar-nav-button" aria-label="Next month" onClick={() => navigate(shiftMonth(state.month, 1))}><ChevronRight size={18} aria-hidden="true" /></button>
        </div>
      </div>
      <div className="calendar-legend">
        <span><Check size={14} className="calendar-complete-icon" aria-hidden="true" /> Complete</span>
        <span><CircleDot size={14} className="calendar-partial-icon" aria-hidden="true" /> Partial</span>
        <span><i className="calendar-neutral-dot" aria-hidden="true" /> No completed activity</span>
      </div>
      {state.loading ? <p className="calendar-message" role="status">Loading exercise records…</p> : null}
      {state.error ? <div className="calendar-error" role="alert"><p>{state.error}</p><button type="button" className="calendar-nav-button" onClick={onRetry}>Retry</button></div> : null}
      <div className="calendar-grid" aria-label="Exercise dates" aria-busy={state.loading}>
        {weekdays.map((day) => <span className="calendar-weekday" key={day}>{day}</span>)}
        {cells.map((date, index) => {
          if (!date) return <span className="calendar-blank" key={`blank-${index}`} aria-hidden="true" />;
          const records = groups.get(date) ?? [];
          const unavailable = state.loading || Boolean(state.error);
          const status = unavailable ? "neutral" : dayStatus(records);
          const selected = date === selectedDate;
          const label = unavailable ? "Records unavailable" : records.length ? `${statusLabels[status]}, ${records.length} ${records.length === 1 ? "record" : "records"}` : "No exercise recorded";
          return (
            <button
              key={date}
              ref={(element) => { if (element) dayButtons.current.set(date, element); else dayButtons.current.delete(date); }}
              type="button"
              className={`calendar-day ${status}${date === today ? " is-today" : ""}${selected ? " is-selected" : ""}`}
              aria-label={`${calendarLabel(date)}: ${label}`}
              aria-current={date === today ? "date" : undefined}
              aria-pressed={selected}
              aria-expanded={selected}
              aria-controls={selected ? detailsId : undefined}
              disabled={unavailable}
              onClick={() => setSelectedDate(date)}
            >
              <span>{Number(date.slice(-2))}</span>
              <span className="calendar-day-marker" aria-hidden="true">
                {status === "complete" ? <Check size={14} /> : status === "partial" ? <CircleDot size={14} /> : records.length && !unavailable ? <span className="calendar-neutral-dot" /> : null}
              </span>
            </button>
          );
        })}
      </div>
      {!selectedDate ? <p className="calendar-message">Select a day to view its records.</p> : (
        <section className="calendar-details" id={detailsId} aria-labelledby={`${detailsId}-heading`}>
          <div className="calendar-details-heading">
            <h3 id={`${detailsId}-heading`}>{calendarLabel(selectedDate)}</h3>
            <button type="button" className="calendar-nav-button" aria-label="Close day details" onClick={closeDetails}><X size={18} aria-hidden="true" /></button>
          </div>
          {state.loading || state.error ? <p className="calendar-message">{state.loading ? "Loading this day’s records…" : "Records unavailable until loading succeeds."}</p> : selectedRecords.length ? (
            <div className="record-list">
              {selectedRecords.map((record) => (
                <article className="record-item calendar-record" key={record.id}>
                  <p>{record.activity_summary}</p>
                  <div className="calendar-record-metrics">
                    <span className={`record-badge ${record.status}`}>{record.status}</span>
                    <span>{record.duration_minutes} min</span>
                    <span>{record.completion_percentage}% complete</span>
                  </div>
                </article>
              ))}
            </div>
          ) : <p className="calendar-message">No exercise recorded.</p>}
        </section>
      )}
    </section>
  );
}
