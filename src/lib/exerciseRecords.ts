import type { SupabaseClient } from "@supabase/supabase-js";
import { monthBounds } from "@/lib/exerciseCalendar";
import type { ExerciseRecord } from "@/lib/types";

export const RECORDS_LOAD_ERROR = "Could not load exercise records. Please try again.";

export async function fetchExerciseRecordsMonth(client: SupabaseClient, userId: string, month: string): Promise<ExerciseRecord[]> {
  const { start, end } = monthBounds(month);
  const records: ExerciseRecord[] = [];
  const pageSize = 500;
  // A date can contain several plan revisions. Page through the whole month.
  for (let offset = 0; ; offset += pageSize) {
    const { data, error } = await client.from("exercise_records")
      .select("*")
      .eq("user_id", userId)
      .gte("record_date", start)
      .lt("record_date", end)
      .order("record_date", { ascending: false })
      .order("created_at", { ascending: false })
      .order("id", { ascending: true })
      .range(offset, offset + pageSize - 1);
    if (error) throw error;
    const page = (data ?? []) as ExerciseRecord[];
    records.push(...page);
    if (page.length < pageSize) return records;
  }
}
