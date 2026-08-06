import assert from "node:assert/strict";
import { createClient } from "@supabase/supabase-js";
import WebSocket from "ws";

const url = process.env.SUPABASE_TEST_URL;
const anonKey = process.env.SUPABASE_TEST_ANON_KEY;
const serviceRoleKey = process.env.SUPABASE_TEST_SERVICE_ROLE_KEY;
const expectRevisionHistory = process.env.SUPABASE_EXPECT_REVISION_HISTORY !== "false";

if (!url || !anonKey || !serviceRoleKey) {
  throw new Error(
    "Set SUPABASE_TEST_URL, SUPABASE_TEST_ANON_KEY, and SUPABASE_TEST_SERVICE_ROLE_KEY."
  );
}

const admin = createClient(url, serviceRoleKey, {
  auth: { autoRefreshToken: false, persistSession: false },
  realtime: { transport: WebSocket }
});
const suffix = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
const password = `Qa-${suffix}-A1!`;
const createdUserIds = [];

async function createTestUser(label) {
  const email = `fitness-genii-${label}-${suffix}@example.test`;
  const { data, error } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true
  });
  if (error) throw error;
  createdUserIds.push(data.user.id);

  const client = createClient(url, anonKey, {
    auth: { autoRefreshToken: false, persistSession: false },
    realtime: { transport: WebSocket }
  });
  const signIn = await client.auth.signInWithPassword({ email, password });
  if (signIn.error) throw signIn.error;
  return { client, user: data.user };
}

async function expectNoError(result, label) {
  if (result.error) throw new Error(`${label}: ${result.error.message}`);
  return result.data;
}

try {
  const owner = await createTestUser("owner");
  const stranger = await createTestUser("stranger");

  await expectNoError(
    await owner.client.from("body_status").insert({
      user_id: owner.user.id,
      age: 32,
      height_cm: 170,
      weight_kg: 70,
      injury: "none"
    }),
    "create body status"
  );
  const target = await expectNoError(
    await owner.client
      .from("exercise_targets")
      .insert({
        user_id: owner.user.id,
        target_type: "general_fitness",
        goal_description: "Integration test",
        exercise_minutes: 20,
        equipment: "none"
      })
      .select("id")
      .single(),
    "create target"
  );

  const planJson = {
    title_en: "QA workout",
    title_zh: "測試訓練",
    completion_suggestion_en: "Record the result.",
    completion_suggestion_zh: "記錄結果。",
    sections: [
      {
        section_type: "main_workout",
        title_en: "Main workout",
        title_zh: "主要訓練",
        items: [
          {
            title_en: "Exercise A",
            title_zh: "動作 A",
            description_en: "First exercise.",
            description_zh: "第一個動作。",
            prescription: "1 minute",
            planned_seconds: 60
          },
          {
            title_en: "Exercise B",
            title_zh: "動作 B",
            description_en: "Second exercise.",
            description_zh: "第二個動作。",
            prescription: "1 minute",
            planned_seconds: 60
          }
        ]
      }
    ]
  };
  const today = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Hong_Kong",
    year: "numeric",
    month: "2-digit",
    day: "2-digit"
  }).format(new Date());

  const planId = await expectNoError(
    await owner.client.rpc("create_structured_plan_revision", {
      p_target_id: target.id,
      p_plan_date: today,
      p_plan_json: planJson,
      p_plan_markdown: "# QA workout",
      p_feedback: "",
      p_model: "integration-test",
      p_prompt_inputs: { source: "integration-test" }
    }),
    "create revision 1"
  );
  assert.equal(typeof planId, "string");

  const items = await expectNoError(
    await owner.client
      .from("plan_items")
      .select("*")
      .eq("plan_id", planId)
      .order("item_position"),
    "load plan items"
  );
  assert.equal(items.length, 2);

  const anonymous = createClient(url, anonKey, {
    auth: { autoRefreshToken: false, persistSession: false },
    realtime: { transport: WebSocket }
  });
  const anonymousRead = await anonymous.from("plan_items").select("id").limit(1);
  assert.ok(anonymousRead.error, "anonymous table access must be denied");

  const strangerRead = await stranger.client.from("plan_items").select("id");
  assert.equal(strangerRead.error, null);
  assert.deepEqual(strangerRead.data, []);

  await expectNoError(
    await owner.client.rpc("toggle_plan_item_timer", { p_plan_item_id: items[0].id }),
    "start A"
  );
  await new Promise((resolve) => setTimeout(resolve, 1100));
  await expectNoError(
    await owner.client.rpc("toggle_plan_item_timer", { p_plan_item_id: items[1].id }),
    "switch A to B"
  );
  await new Promise((resolve) => setTimeout(resolve, 1100));
  await expectNoError(
    await owner.client.rpc("toggle_plan_item_timer", { p_plan_item_id: items[1].id }),
    "pause B"
  );

  const switchedIntervals = await expectNoError(
    await owner.client
      .from("exercise_intervals")
      .select("plan_item_id,ended_at,duration_seconds,stop_reason")
      .order("started_at"),
    "load switched intervals"
  );
  assert.equal(switchedIntervals.length, 2);
  assert.equal(switchedIntervals[0].plan_item_id, items[0].id);
  assert.equal(switchedIntervals[0].stop_reason, "switch");
  assert.ok(switchedIntervals[0].duration_seconds >= 1);
  assert.equal(switchedIntervals[1].plan_item_id, items[1].id);
  assert.equal(switchedIntervals[1].stop_reason, "pause");
  assert.ok(switchedIntervals[1].duration_seconds >= 1);

  await expectNoError(
    await owner.client.rpc("toggle_plan_item_timer", { p_plan_item_id: items[0].id }),
    "resume A"
  );
  await expectNoError(
    await owner.client.rpc("set_plan_item_done", {
      p_plan_item_id: items[0].id,
      p_done: true
    }),
    "finish A"
  );

  const finished = await expectNoError(
    await owner.client.rpc("finish_workout", {
      p_plan_id: planId,
      p_activity_summary: "Integration workout"
    }),
    "finish workout"
  );
  assert.equal(finished.completed_items, 1);
  assert.equal(finished.total_items, 2);
  assert.equal(finished.completion_percentage, 50);
  assert.ok(finished.duration_seconds >= 2);

  const record = await expectNoError(
    await owner.client
      .from("exercise_records")
      .select("duration_seconds,completion_percentage,status")
      .eq("plan_id", planId)
      .single(),
    "load exercise record"
  );
  assert.equal(record.status, "executed");
  assert.equal(record.completion_percentage, 50);
  assert.ok(record.duration_seconds >= 2);

  const postFinishToggle = await owner.client.rpc("toggle_plan_item_timer", {
    p_plan_item_id: items[1].id
  });
  assert.ok(postFinishToggle.error, "finished workouts must reject new timer intervals");

  const revision2Id = await expectNoError(
    await owner.client.rpc("create_structured_plan_revision", {
      p_target_id: target.id,
      p_plan_date: today,
      p_plan_json: planJson,
      p_plan_markdown: "# QA workout revision 2",
      p_feedback: "make it easier",
      p_model: "integration-test",
      p_prompt_inputs: { source: "integration-test" }
    }),
    "create revision 2"
  );
  if (expectRevisionHistory) {
    assert.notEqual(revision2Id, planId);
  } else {
    assert.equal(revision2Id, planId);
  }

  const revisions = await expectNoError(
    await owner.client
      .from("daily_plans")
      .select("id,revision,is_current,status")
      .eq("plan_date", today)
      .order("revision"),
    "load revisions"
  );
  const revisionSummary = revisions.map((plan) => ({
    revision: plan.revision,
    current: plan.is_current,
    status: plan.status
  }));
  assert.deepEqual(
    revisionSummary,
    expectRevisionHistory
      ? [
          { revision: 1, current: false, status: "superseded" },
          { revision: 2, current: true, status: "regenerated" }
        ]
      : [{ revision: 2, current: true, status: "regenerated" }]
  );

  console.log("Supabase workout integration tests passed.");
} finally {
  for (const userId of createdUserIds.reverse()) {
    await admin.auth.admin.deleteUser(userId);
  }
}
