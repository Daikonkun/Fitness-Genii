export type TargetType = "general_fitness" | "weight_loss" | "strength";

export type BodyStatus = {
  id?: string;
  user_id: string;
  gender: string | null;
  age: number | null;
  height_cm: number | null;
  weight_kg: number | null;
  injury: string | null;
};

export type ExerciseTarget = {
  id?: string;
  user_id: string;
  target_type: TargetType;
  goal_description: string;
  exercise_minutes: number;
  focus: string | null;
  equipment: string | null;
};

export type WeightLog = {
  id: string;
  user_id: string;
  weight_kg: number;
  logged_on: string;
  created_at: string;
};

export type ExerciseRecord = {
  id: string;
  user_id: string;
  plan_id: string | null;
  record_date: string;
  activity_summary: string;
  duration_minutes: number;
  duration_seconds: number;
  completion_percentage: number;
  status: "executed" | "unfinished";
  created_at: string;
};

export type DailyPlan = {
  id: string;
  user_id: string;
  target_id: string | null;
  plan_date: string;
  plan_markdown: string;
  plan_json: StructuredPlan | null;
  schema_version: number;
  revision: number;
  is_current: boolean;
  superseded_at: string | null;
  status:
    | "generated"
    | "regenerated"
    | "in_progress"
    | "executed"
    | "unfinished"
    | "superseded";
  completion_percentage: number;
  feedback: string | null;
  model: string;
  prompt_inputs: Record<string, unknown>;
  generated_at: string;
};

export type PlanSectionType = "warm_up" | "main_workout" | "cool_down";

export type StructuredPlanItem = {
  title_en: string;
  title_zh: string;
  description_en: string;
  description_zh: string;
  prescription: string;
  planned_seconds: number;
};

export type StructuredPlanSection = {
  section_type: PlanSectionType;
  title_en: string;
  title_zh: string;
  items: StructuredPlanItem[];
};

export type StructuredPlan = {
  title_en: string;
  title_zh: string;
  sections: StructuredPlanSection[];
  completion_suggestion_en: string;
  completion_suggestion_zh: string;
};

export type PlanItem = StructuredPlanItem & {
  id: string;
  user_id: string;
  plan_id: string;
  section_type: PlanSectionType;
  section_title_en: string;
  section_title_zh: string;
  section_position: number;
  item_position: number;
  completed_at: string | null;
  created_at: string;
};

export type ExerciseInterval = {
  id: string;
  user_id: string;
  plan_item_id: string;
  started_at: string;
  ended_at: string | null;
  duration_seconds: number;
  stop_reason: "pause" | "switch" | "done" | "regenerate" | "finish" | "day_end" | null;
  created_at: string;
};

export type DashboardData = {
  userId: string;
  userEmail: string;
  todayHk: string;
  bodyStatus: BodyStatus | null;
  target: ExerciseTarget | null;
  weightLogs: WeightLog[];
  records: ExerciseRecord[];
  todayPlan: DailyPlan | null;
  todayPlanItems: PlanItem[];
  todayIntervals: ExerciseInterval[];
};
