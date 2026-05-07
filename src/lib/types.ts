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
  status: "generated" | "regenerated" | "executed" | "unfinished";
  completion_percentage: number;
  feedback: string | null;
  model: string;
  prompt_inputs: Record<string, unknown>;
  generated_at: string;
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
};
