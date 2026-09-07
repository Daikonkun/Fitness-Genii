import assert from "node:assert/strict";
import fs from "node:fs";
import React from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { loadTypeScriptModule as load } from "./lib/load-typescript.mjs";
const { exercises, canonicalCopy, resolveExercise } = load(
  "src/lib/exercises/catalogue.ts"
);
const { sketches, interpolatePose } = load("src/lib/exercises/poses.ts");
const { generatedPlanSchema, structuredPlanSchema, generationResponseSchema } =
  load("src/lib/planSchema.ts");
assert.equal(exercises.length, 35);
assert.equal(new Set(exercises.map((e) => e.id)).size, 35);
const migration = fs.readFileSync(
  "supabase/migrations/20260907095936_innstar_chest_core.sql",
  "utf8"
);
for (const exercise of exercises) {
  assert.ok(
    migration.includes(`'${exercise.id}'`),
    `DB supports ${exercise.id}`
  );
  assert.equal(exercise.steps.length, 3);
  assert.ok(
    exercise.steps.every((pair) => pair.length === 2 && pair.every(Boolean))
  );
  const sketch = sketches[exercise.id];
  assert.ok(sketch, exercise.id);
  assert.ok(
    new Set(sketch.poses.map((p) => JSON.stringify(p))).size > 1,
    `${exercise.id} moves`
  );
  for (let t = 0; t <= 1; t += 0.025) {
    const pose = interpolatePose(sketch, t, exercise.held);
    assert.equal(pose.length, 11);
    assert.ok(pose.flat().every(Number.isFinite));
    assert.ok(
      pose.every(([x, y]) => x >= 0 && x <= 300 && y >= 0 && y <= 250),
      exercise.id
    );
  }
  assert.ok(!exercise.equipment.includes("dumbbells") || sketch.weights);
  assert.ok(!exercise.equipment.includes("band") || sketch.band);
  assert.ok(!exercise.equipment.includes("handled-tubes-foot-straps") || sketch.tubeStraps);
  assert.ok(
    !exercise.equipment.includes("chair") ||
      ["chair", "support"].includes(sketch.prop)
  );
  assert.ok(!exercise.equipment.includes("wall") || sketch.prop === "wall");
  if (exercise.held)
    assert.deepEqual(interpolatePose(sketch, 0.5, true), sketch.poses[1]);
}
const first = exercises[0];
const item = {
  exercise_id: first.id,
  ...canonicalCopy(first),
  prescription: "2 minutes",
  planned_seconds: 120
};
const plan = {
  title_en: "Test",
  title_zh: "測試",
  sections: [
    {
      section_type: "warm_up",
      title_en: "Warm-up",
      title_zh: "熱身",
      items: [item]
    }
  ],
  completion_suggestion_en: "Log it",
  completion_suggestion_zh: "記錄"
};
assert.ok(generatedPlanSchema.safeParse(plan).success);
const unknown = structuredClone(plan);
unknown.sections[0].items[0].exercise_id = "unknown";
assert.equal(generatedPlanSchema.safeParse(unknown).success, false);
const legacy = structuredClone(plan);
delete legacy.sections[0].items[0].exercise_id;
assert.ok(structuredPlanSchema.safeParse(legacy).success);
assert.equal(generatedPlanSchema.safeParse(legacy).success, false);
assert.equal(resolveExercise(legacy.sections[0].items[0]).id, first.id);
assert.equal(
  resolveExercise({
    ...legacy.sections[0].items[0],
    description_en: "March with heavy overhead weights."
  }),
  undefined
);
assert.equal(resolveExercise({ ...item, exercise_id: "unknown" }), undefined);
const misleading = structuredClone(plan);
misleading.sections[0].items[0].title_en = "Jump squat";
assert.equal(
  generatedPlanSchema.parse(misleading).sections[0].items[0].title_en,
  first.title_en
);
assert.ok(
  generationResponseSchema.safeParse({
    status: "unavailable",
    reason_en: "Unsupported",
    reason_zh: "未支援",
    plan: null
  }).success
);
assert.equal(
  generationResponseSchema.safeParse({
    status: "ready",
    reason_en: "",
    reason_zh: "",
    plan: null
  }).success,
  false
);

// Exercise the real route with read fixtures: errors must never call the mutating revision RPC.
let rpcCalls = 0;
let savedPayload;
let testEquipment = "none";
const db = {
  auth: { getUser: async () => ({ data: { user: { id: "test-user" } } }) },
  from(table) {
    const data =
      table === "body_status"
        ? { user_id: "test-user", injury: "none" }
        : table === "exercise_targets"
          ? {
              id: "target",
              user_id: "test-user",
              equipment: testEquipment,
              exercise_minutes: 20
            }
          : table === "daily_plans"
            ? null
            : [];
    const chain = new Proxy(
      {},
      {
        get: (_, key) =>
          key === "then"
            ? (resolve) => resolve({ data, error: null })
            : () => chain
      }
    );
    return chain;
  },
  rpc: async (_name, payload) => {
    rpcCalls++;
    savedPayload = payload;
    return { data: "saved-id", error: null };
  }
};
const { POST } = load("src/app/api/plans/generate/route.ts", {
  "@/lib/supabase/server": { createClient: async () => db }
});
const oldFetch = globalThis.fetch,
  oldKey = process.env.OPENROUTER_API_KEY;
process.env.OPENROUTER_API_KEY = "test-not-a-secret";
try {
  for (const [output, status] of [
    [{ status: "ready", reason_en: "", reason_zh: "", plan: unknown }, 502],
    [
      {
        status: "unavailable",
        reason_en: "No supported move meets your constraints.",
        reason_zh: "未有符合條件的動作。",
        plan: null
      },
      422
    ]
  ]) {
    globalThis.fetch = async () =>
      new Response(
        JSON.stringify({
          choices: [{ message: { content: JSON.stringify(output) } }]
        })
      );
    const response = await POST(
      new Request("http://localhost/api/plans/generate", {
        method: "POST",
        body: "{}"
      })
    );
    assert.equal(response.status, status);
    assert.equal(rpcCalls, 0);
  }
  const incompatible = structuredClone(plan);
  incompatible.sections[0].items[0].exercise_id = "handled-tube-seated-row";
  globalThis.fetch = async () => new Response(JSON.stringify({ choices: [{message: {content: JSON.stringify({status: "ready", reason_en: "", reason_zh: "", plan: incompatible})}}] }));
  const blocked = await POST(new Request("http://localhost/api/plans/generate", {method: "POST", body: "{}"}));
  assert.equal(blocked.status, 422);
  assert.equal(rpcCalls, 0);
  testEquipment = "handled tubes [band-setup:foot_straps]";
  const supported = await POST(new Request("http://localhost/api/plans/generate", {method: "POST", body: "{}"}));
  assert.equal(supported.status, 200);
  assert.equal(savedPayload.p_plan_json.sections[0].items[0].exercise_id, "handled-tube-seated-row");
  rpcCalls = 0;
  testEquipment = "INNSTAR padded chest expander, bar, handles, foot straps [band-setup:innstar_primary]";
  const incomplete = await POST(new Request("http://localhost/api/plans/generate", {method: "POST", body: "{}"}));
  assert.equal(incomplete.status, 422);
  assert.equal((await incomplete.json()).code, "kit_focus_missing");
  assert.equal(rpcCalls, 0);
  const balanced = structuredClone(plan);
  balanced.sections[0].section_type = "main_workout";
  balanced.sections[0].items = ["innstar-bar-floor-press", "handled-tube-seated-row", "handled-tube-side-bend"].map(exercise_id => ({...item, exercise_id}));
  globalThis.fetch = async () => new Response(JSON.stringify({ choices: [{message: {content: JSON.stringify({status: "ready", reason_en: "", reason_zh: "", plan: balanced})}}] }));
  const covered = await POST(new Request("http://localhost/api/plans/generate", {method: "POST", body: "{}"}));
  assert.equal(covered.status, 200);
  assert.equal(rpcCalls, 1);
  assert.deepEqual(savedPayload.p_plan_json.sections[0].items.map(i => i.exercise_id), balanced.sections[0].items.map(i => i.exercise_id));
  rpcCalls = 0;
  const { serializeEquipment, emptyEquipment } = load("src/lib/equipmentConfig.ts");
  testEquipment=serializeEquipment({...emptyEquipment(),selected:["dumbbells"],primary:"dumbbells",dumbbells:{weight:5,unit:"kg",count:2}});
  const weighted=structuredClone(plan);
  weighted.sections[0].items[0].exercise_id="dumbbell-floor-press";
  globalThis.fetch=async()=>new Response(JSON.stringify({choices:[{message:{content:JSON.stringify({status:"ready",reason_en:"",reason_zh:"",plan:weighted})}}]}));
  const controlled=await POST(new Request("http://localhost/api/plans/generate",{method:"POST",body:"{}"}));
  assert.equal(controlled.status,200);
  assert.ok(savedPayload.p_plan_json.sections[0].items[0].prescription.includes("5 kg per dumbbell"));
  assert.ok(structuredPlanSchema.safeParse(savedPayload.p_plan_json).success);
  rpcCalls=0;
  weighted.sections[0].items[0].prescription="3 sets with 20kg";
  const fabricated=await POST(new Request("http://localhost/api/plans/generate",{method:"POST",body:"{}"}));
  assert.equal(fabricated.status,422);
  assert.equal((await fabricated.json()).code,"uncontrolled_load");
  assert.equal(rpcCalls,0);
  testEquipment="equipment:v1:{broken";
  globalThis.fetch=async()=>{throw Error("Invalid equipment must be rejected before model call");};
  const badEquipment=await POST(new Request("http://localhost/api/plans/generate",{method:"POST",body:"{}"}));
  assert.equal(badEquipment.status,422);
  assert.equal(rpcCalls,0);
  testEquipment = "none";
  globalThis.fetch = async () =>
    new Response(
      JSON.stringify({
        choices: [
          {
            message: {
              content: JSON.stringify({
                status: "ready",
                reason_en: "",
                reason_zh: "",
                plan: misleading
              })
            }
          }
        ]
      })
    );
  const accepted = await POST(
    new Request("http://localhost/api/plans/generate", {
      method: "POST",
      body: "{}"
    })
  );
  assert.equal(accepted.status, 200);
  assert.equal(rpcCalls, 1);
  assert.equal(
    savedPayload.p_plan_json.sections[0].items[0].title_en,
    first.title_en
  );
  assert.equal(
    savedPayload.p_plan_json.sections[0].items[0].exercise_id,
    first.id
  );
  assert.equal(savedPayload.p_prompt_inputs.exercise_catalogue_version, 3);
} finally {
  globalThis.fetch = oldFetch;
  if (oldKey === undefined) delete process.env.OPENROUTER_API_KEY;
  else process.env.OPENROUTER_API_KEY = oldKey;
}
console.log(
  "35 sketch assets, catalogue validation, historical matching and generation failure tests passed."
);

// A missing bundled pose must retain usable instructions rather than crash the card.
const assetCache = new Map();
const { ExerciseSketch } = load("src/components/ExerciseSketch.tsx", {}, assetCache);
const assetModule = load("src/lib/exercises/poses.ts", {}, assetCache);
const originalSketch = assetModule.sketches[first.id];
delete assetModule.sketches[first.id];
try {
  const fallback = renderToStaticMarkup(React.createElement(ExerciseSketch, { exercise: first }));
  assert.ok(fallback.includes("Sketch unavailable"));
  assert.ok(fallback.includes(first.steps[0][0]));
} finally {
  assetModule.sketches[first.id] = originalSketch;
}

const { bandEquipmentCompatible, bandSetup, withBandSetup } = load("src/lib/exercises/equipment.ts");
const flat = exercises.find(e => e.id === "band-pull-apart");
const handled = exercises.find(e => e.id === "handled-tube-curl");
for (const ambiguous of [null, "6kg resistance band", "handles and straps", "no bands"]) {
  assert.equal(bandEquipmentCompatible(flat, ambiguous), false);
  assert.equal(bandEquipmentCompatible(handled, ambiguous), false);
}
assert.equal(bandEquipmentCompatible(flat, withBandSetup("tube", "foot_straps")), false);
assert.equal(bandEquipmentCompatible(handled, withBandSetup("tube", "foot_straps")), true);
assert.equal(bandEquipmentCompatible(handled, withBandSetup("band", "flat")), false);
assert.equal(bandEquipmentCompatible(flat, withBandSetup("band", "flat")), true);
assert.equal(bandSetup(withBandSetup("tube [band-setup:flat]", "foot_straps")), "foot_straps");
assert.equal(bandSetup("[band-setup:flat] [band-setup:foot_straps]"), "unspecified");
const { SketchFigure } = load("src/components/ExerciseSketch.tsx");
for (const exercise of exercises.filter(e => e.equipment.includes("handled-tubes-foot-straps"))) {
  const sketch = sketches[exercise.id];
  for (const pose of sketch.poses) {
    const svg = renderToStaticMarkup(React.createElement(SketchFigure, {pose, sketch, label: exercise.title_en}));
    assert.equal((svg.match(/data-tube-strap/g) ?? []).length, sketch.singleTube ? 1 : 2);
    assert.ok(!svg.includes("NaN"));
  }
  assert.deepEqual(sketch.poses[0][8], sketch.poses[1][8]);
  assert.deepEqual(sketch.poses[0][10], sketch.poses[1][10]);
}

const { missingKitFocus } = load("src/lib/exercises/equipment.ts");
const primary = "[band-setup:innstar_primary]";
const kitExercises = exercises.filter(e => bandEquipmentCompatible(e, primary));
assert.deepEqual(missingKitFocus(kitExercises, primary), []);
assert.equal(bandEquipmentCompatible(flat, primary), false);
for (const id of ["innstar-bar-floor-press", "innstar-standing-chest-press"]) {
  const exercise = exercises.find(e => e.id === id);
  assert.equal(bandEquipmentCompatible(exercise, "[band-setup:foot_straps]"), false);
  assert.equal(bandEquipmentCompatible(exercise, primary), true);
  const sketch = sketches[id];
  for (const pose of sketch.poses) {
    const svg = renderToStaticMarkup(React.createElement(SketchFigure, {pose, sketch, label:id}));
    assert.ok(svg.includes('data-chest-pad="true"'));
    assert.equal((svg.match(/data-chest-tube/g) ?? []).length, 2);
    if (sketch.bar) assert.ok(svg.includes('data-kit-bar="true"'));
  }
}
const barSketch = sketches["innstar-bar-floor-press"];
for(let t=0;t<1;t+=.05) {
  const pose=interpolatePose(barSketch,t,false);
  assert.equal(pose[6][0]-pose[4][0],36);
  assert.equal(pose[6][1],pose[4][1]);
}
const { buildPlanPrompt } = load("src/lib/planPrompt.ts");
const prompt=buildPlanPrompt({target:{equipment:primary},bodyStatus:null,weightLogs:[],historyDigest:{},previousPlan:null,todayHk:"2026-09-07"});
const catalogue=JSON.parse(prompt[1].content.split("Supported exercise catalogue (version 3):\n")[1].split("\n\nUser body status:")[0]);
assert.ok(catalogue.some(e=>e.focus==="chest"));
assert.ok(catalogue.some(e=>e.focus==="back"));
assert.ok(catalogue.some(e=>e.focus==="core"));
assert.ok(!catalogue.some(e=>e.exercise_id==="band-pull-apart"));
