import type { StructuredPlanItem } from "../types";

export const EXERCISE_CATALOGUE_VERSION = 1;
export type Equipment = "chair" | "wall" | "dumbbells" | "band";
export type ExerciseDefinition = {
  id: string;
  title_en: string;
  title_zh: string;
  equipment: Equipment[];
  steps: [string, string][];
  cue: [string, string];
  held: boolean;
  reference: string;
};

// Original concise instructions; references support editorial review, not copied media.
const ace = "https://www.acefitness.org/resources/everyone/exercise-library/";
const movementReferences: Record<string, string> = {
  "bird-dog": `${ace}14/bird-dog/`,
  "bodyweight-squat": `${ace}135/bodyweight-squat/`,
  "glute-bridge": "https://www.nasm.org/exercise-library/floor-bridge"
};
function move(
  id: string,
  en: string,
  zh: string,
  equipment: Equipment[],
  steps: [string, string][],
  cue: [string, string],
  held = false
): ExerciseDefinition {
  return {
    id,
    title_en: en,
    title_zh: zh,
    equipment,
    steps,
    cue,
    held,
    reference: movementReferences[id] ?? ace
  };
}
export const exercises: ExerciseDefinition[] = [
  move(
    "march-in-place",
    "March in place",
    "原地踏步",
    [],
    [
      ["Stand tall with feet under your hips.", "站直，雙腳置於髖部下方。"],
      [
        "Lift one knee and swing the opposite arm; alternate sides.",
        "抬起一膝，同時擺動另一側手臂；左右交替。"
      ],
      ["Place each foot down softly.", "每次輕輕落腳。"]
    ],
    ["Keep the knee lift comfortable.", "抬膝至舒適高度。"]
  ),
  move(
    "step-jack",
    "Step jack",
    "踏步開合",
    [],
    [
      ["Stand with feet together and arms down.", "雙腳併攏，雙臂垂下。"],
      [
        "Step one foot out while raising both arms.",
        "一腳向側踏出，同時舉起雙臂。"
      ],
      [
        "Step back and lower arms; alternate sides.",
        "收回腳並放下手臂；左右交替。"
      ]
    ],
    ["Step rather than jump.", "用踏步完成，毋須跳躍。"]
  ),
  move(
    "arm-circle",
    "Arm circles",
    "手臂繞圈",
    [],
    [
      ["Stand tall and extend your arms sideways.", "站直，雙臂向兩側伸展。"],
      ["Draw small controlled circles with your hands.", "雙手緩慢畫小圈。"],
      [
        "Reverse direction after the prescribed repetitions.",
        "完成指定次數後反方向繞圈。"
      ]
    ],
    ["Keep your shoulders away from your ears.", "肩膀遠離耳朵。"]
  ),
  move(
    "shoulder-roll",
    "Shoulder rolls",
    "肩膀繞圈",
    [],
    [
      ["Stand relaxed with arms at your sides.", "放鬆站立，雙臂垂於身側。"],
      [
        "Lift shoulders, roll them back, then lower them.",
        "提肩、向後繞，再放下。"
      ],
      ["Return to a relaxed position and repeat.", "回到放鬆位置並重複。"]
    ],
    ["Use a small, unforced circle.", "小幅度繞圈，不要勉強。"]
  ),
  move(
    "standing-hip-hinge",
    "Standing hip hinge",
    "站姿髖部折疊",
    [],
    [
      [
        "Stand with soft knees and feet hip-width apart.",
        "雙腳與髖同寬，膝蓋微彎。"
      ],
      [
        "Send your hips back as your torso tips forward.",
        "臀部向後推，軀幹隨之向前傾。"
      ],
      ["Drive through your feet to stand tall.", "腳掌穩定踩地，回復站姿。"]
    ],
    ["Keep your back long; move at the hips.", "背部保持延伸，以髖部帶動。"]
  ),
  move(
    "bodyweight-squat",
    "Bodyweight squat",
    "徒手深蹲",
    [],
    [
      ["Stand with feet about shoulder-width apart.", "雙腳約與肩同寬。"],
      [
        "Bend hips and knees, sitting down between your feet.",
        "屈髖屈膝，臀部往雙腳之間下降。"
      ],
      ["Push through your feet to stand.", "腳掌踩地，起身站直。"]
    ],
    [
      "Keep heels grounded and knees following toes.",
      "腳跟貼地，膝蓋順着腳尖方向。"
    ]
  ),
  move(
    "chair-sit-to-stand",
    "Chair sit-to-stand",
    "椅子坐站",
    ["chair"],
    [
      [
        "Sit near the front of a stable chair, feet flat.",
        "坐在穩固椅子的前緣，雙腳平放地上。"
      ],
      [
        "Lean forward slightly and press through your feet to stand.",
        "身體略向前傾，雙腳踩地起身。"
      ],
      ["Reach hips back and sit down slowly.", "臀部向後移，慢慢坐下。"]
    ],
    ["Use a chair that cannot slide or roll.", "使用不會滑動或滾動的椅子。"]
  ),
  move(
    "wall-push-up",
    "Wall push-up",
    "牆壁掌上壓",
    ["wall"],
    [
      [
        "Place palms on a wall at shoulder height; step back.",
        "手掌放在牆上與肩同高，雙腳後退。"
      ],
      [
        "Bend elbows to bring your chest toward the wall.",
        "屈肘，胸部靠近牆壁。"
      ],
      ["Press the wall away to return.", "推牆回到起始位置。"]
    ],
    ["Keep your body in one line.", "身體保持一直線。"]
  ),
  move(
    "kneeling-push-up",
    "Kneeling push-up",
    "跪姿掌上壓",
    [],
    [
      [
        "Place hands below shoulders and knees on the floor.",
        "雙手置於肩下，膝蓋着地。"
      ],
      [
        "Keep a line from head to knees as you lower your chest.",
        "頭部至膝蓋保持一直線，降低胸部。"
      ],
      ["Press through your palms to rise.", "手掌推地回升。"]
    ],
    ["Move your chest and hips together.", "胸部與髖部同步移動。"]
  ),
  move(
    "standard-push-up",
    "Standard push-up",
    "標準掌上壓",
    [],
    [
      [
        "Start on hands and toes, hands just wider than shoulders.",
        "雙手與腳尖撐地，手距略寬於肩。"
      ],
      ["Bend elbows and lower your body as one unit.", "屈肘，身體整體下降。"],
      ["Press the floor away to straighten your arms.", "推地，伸直手臂。"]
    ],
    ["Keep hips level with your trunk.", "髖部與軀幹保持一直線。"]
  ),
  move(
    "supported-reverse-lunge",
    "Supported reverse lunge",
    "扶椅後跨弓步",
    ["chair"],
    [
      [
        "Stand beside a stable chair and hold its back lightly.",
        "站在穩固椅旁，輕扶椅背。"
      ],
      ["Step one foot back and bend both knees.", "一腳向後跨，雙膝彎曲。"],
      [
        "Press through the front foot to return; switch sides.",
        "前腳踩地返回；換邊進行。"
      ]
    ],
    ["Keep the front heel down and torso tall.", "前腳跟貼地，軀幹挺直。"]
  ),
  move(
    "glute-bridge",
    "Glute bridge",
    "臀橋",
    [],
    [
      [
        "Lie on your back, knees bent and feet flat.",
        "仰臥，屈膝，雙腳平放地上。"
      ],
      [
        "Press through your feet and lift hips toward a shoulder-to-knee line.",
        "雙腳踩地，抬髖至肩至膝約成一直線。"
      ],
      ["Lower your hips with control.", "有控制地放下臀部。"]
    ],
    [
      "Finish with your glutes, without arching your lower back.",
      "用臀部完成動作，不要拱腰。"
    ]
  ),
  move(
    "standing-calf-raise",
    "Standing calf raise",
    "站姿提踵",
    [],
    [
      ["Stand with feet hip-width apart.", "雙腳與髖同寬站立。"],
      [
        "Lift both heels, rising onto the balls of your feet.",
        "抬起雙腳跟，以前腳掌支撐。"
      ],
      ["Lower your heels slowly.", "慢慢放下腳跟。"]
    ],
    [
      "Rise straight up without rolling your ankles outward.",
      "垂直上升，腳踝不要向外翻。"
    ]
  ),
  move(
    "bird-dog",
    "Bird dog",
    "鳥狗式",
    [],
    [
      [
        "Start on hands and knees beneath shoulders and hips.",
        "四足跪姿，雙手在肩下，膝蓋在髖下。"
      ],
      [
        "Reach one arm forward and the opposite leg back.",
        "一手向前伸，另一側腿向後伸。"
      ],
      ["Return to all fours; alternate sides.", "回到四足跪姿；左右交替。"]
    ],
    ["Keep hips facing the floor.", "髖部保持朝向地面。"]
  ),
  move(
    "dead-bug",
    "Dead bug",
    "死蟲式",
    [],
    [
      [
        "Lie on your back with arms up and hips and knees bent.",
        "仰臥，雙臂朝上，髖膝彎曲。"
      ],
      [
        "Lower one arm overhead and extend the opposite leg.",
        "一臂向頭頂方向放下，另一側腿伸出。"
      ],
      ["Return to the start; alternate sides.", "回到起始位置；左右交替。"]
    ],
    [
      "Use a range that keeps your lower back steady.",
      "以能保持腰部穩定的幅度進行。"
    ]
  ),
  move(
    "forearm-plank",
    "Forearm plank",
    "前臂平板支撐",
    [],
    [
      [
        "Place forearms on the floor, elbows beneath shoulders, knees down.",
        "前臂着地，手肘在肩下，膝蓋着地。"
      ],
      [
        "Lift knees onto toes and hold a straight body line.",
        "抬膝，以腳尖支撐，身體保持一直線。"
      ],
      ["Lower knees to finish the hold.", "放下膝蓋，結束支撐。"]
    ],
    ["Breathe steadily; avoid letting hips sag.", "保持呼吸，髖部不要下沉。"],
    true
  ),
  move(
    "goblet-squat",
    "Goblet squat",
    "高腳杯深蹲",
    ["dumbbells"],
    [
      [
        "Hold one dumbbell close to your chest with both hands.",
        "雙手把一個啞鈴握在胸前。"
      ],
      [
        "Bend hips and knees to squat, keeping the weight close.",
        "屈髖屈膝下蹲，啞鈴貼近身體。"
      ],
      ["Press through your feet to stand.", "雙腳踩地，站起。"]
    ],
    [
      "Keep heels down and elbows inside your arm position.",
      "腳跟貼地，手肘自然收攏。"
    ]
  ),
  move(
    "dumbbell-romanian-deadlift",
    "Dumbbell Romanian deadlift",
    "啞鈴羅馬尼亞硬拉",
    ["dumbbells"],
    [
      [
        "Stand holding dumbbells in front of your thighs, knees soft.",
        "站立，啞鈴放在大腿前，膝蓋微彎。"
      ],
      [
        "Push hips back and lower weights close to your legs.",
        "臀部後推，啞鈴沿腿部附近下降。"
      ],
      ["Bring hips forward to stand tall.", "髖部向前回復站姿。"]
    ],
    [
      "Stop before your back rounds; the knees stay softly bent.",
      "在背部彎曲前停止下降；膝蓋保持微彎。"
    ]
  ),
  move(
    "supported-dumbbell-row",
    "Supported one-arm dumbbell row",
    "扶椅單臂啞鈴划船",
    ["chair", "dumbbells"],
    [
      [
        "Support one hand on a stable chair and hinge forward; let the weight hang.",
        "一手扶穩固椅面，屈髖前傾，另一手垂握啞鈴。"
      ],
      ["Pull your elbow back toward your hip.", "手肘往髖部方向向後拉。"],
      ["Lower slowly; repeat on the other side.", "慢慢放下；換邊重複。"]
    ],
    ["Keep your trunk still rather than twisting.", "軀幹保持穩定，不要扭轉。"]
  ),
  move(
    "dumbbell-floor-press",
    "Dumbbell floor press",
    "啞鈴地板臥推",
    ["dumbbells"],
    [
      [
        "Lie on your back, knees bent, elbows on the floor and weights above elbows.",
        "仰臥屈膝，手肘着地，啞鈴在手肘上方。"
      ],
      ["Press the weights up over your chest.", "把啞鈴推至胸部上方。"],
      [
        "Lower until upper arms gently meet the floor.",
        "慢慢下降，直到上臂輕觸地面。"
      ]
    ],
    ["Keep wrists stacked above elbows.", "手腕保持在手肘上方。"]
  ),
  move(
    "dumbbell-biceps-curl",
    "Dumbbell biceps curl",
    "啞鈴二頭肌彎舉",
    ["dumbbells"],
    [
      [
        "Stand with weights by your sides, palms forward.",
        "站立，雙手垂握啞鈴，掌心向前。"
      ],
      [
        "Bend elbows to curl weights toward your shoulders.",
        "屈肘，把啞鈴舉向肩部。"
      ],
      ["Lower the weights slowly.", "慢慢放下啞鈴。"]
    ],
    [
      "Keep upper arms beside your torso; avoid swinging.",
      "上臂貼近身側，不要擺動。"
    ]
  ),
  move(
    "band-pull-apart",
    "Band pull-apart",
    "彈力帶水平拉開",
    ["band"],
    [
      [
        "Hold a band in front of your chest with arms extended.",
        "雙臂在胸前伸展，握住彈力帶。"
      ],
      [
        "Open arms sideways to stretch the band across your chest.",
        "雙臂向兩側打開，把彈力帶拉至胸前。"
      ],
      [
        "Return slowly, keeping control of the band.",
        "慢慢收回，控制彈力帶張力。"
      ]
    ],
    [
      "Keep shoulders down and elbows softly unlocked.",
      "肩膀放低，手肘不要鎖死。"
    ]
  ),
  move(
    "standing-band-curl",
    "Standing band biceps curl",
    "站姿彈力帶二頭肌彎舉",
    ["band"],
    [
      [
        "Stand on the middle of the band and hold its ends, palms forward.",
        "踩住彈力帶中段，握住兩端，掌心向前。"
      ],
      [
        "Bend elbows to raise your hands toward shoulders.",
        "屈肘，雙手舉向肩部。"
      ],
      [
        "Lower hands slowly against the band's tension.",
        "控制張力，慢慢放下雙手。"
      ]
    ],
    ["Keep the band securely under both feet.", "雙腳穩穩踩住彈力帶。"]
  ),
  move(
    "wall-calf-stretch",
    "Wall calf stretch",
    "扶牆小腿伸展",
    ["wall"],
    [
      [
        "Face a wall with hands on it and one foot stepped back.",
        "面向牆，雙手扶牆，一腳後退。"
      ],
      [
        "Bend the front knee while keeping the back heel down; hold.",
        "前膝彎曲，後腳跟貼地；保持。"
      ],
      ["Ease out and switch legs.", "慢慢放鬆，再換腿。"]
    ],
    [
      "Point both feet forward and keep the back knee straight.",
      "雙腳朝前，後膝伸直。"
    ],
    true
  ),
  move(
    "seated-hamstring-stretch",
    "Seated hamstring stretch",
    "坐姿腿後側伸展",
    ["chair"],
    [
      [
        "Sit at the front of a stable chair; extend one leg with heel down.",
        "坐在穩固椅子前緣，一腿伸直，腳跟着地。"
      ],
      [
        "Hinge forward slightly at your hips and hold.",
        "從髖部略向前傾並保持。"
      ],
      ["Sit upright and switch legs.", "坐直，再換腿。"]
    ],
    [
      "Keep your back long rather than reaching with a rounded spine.",
      "背部保持延伸，不要彎腰勉強前伸。"
    ],
    true
  ),
  move(
    "supported-quad-stretch",
    "Standing quadriceps stretch with chair support",
    "扶椅站姿大腿前側伸展",
    ["chair"],
    [
      [
        "Stand beside a stable chair and hold it with one hand.",
        "站在穩固椅旁，一手扶椅。"
      ],
      [
        "Bend the other knee, hold the ankle behind you and hold.",
        "另一膝彎曲，握住身後腳踝並保持。"
      ],
      ["Release gently and switch sides.", "輕輕放開，再換邊。"]
    ],
    ["Keep knees close and avoid arching your back.", "雙膝靠近，不要拱腰。"],
    true
  ),
  move(
    "cross-body-shoulder-stretch",
    "Cross-body shoulder stretch",
    "橫臂肩部伸展",
    [],
    [
      [
        "Stand tall and bring one arm across your chest.",
        "站直，一臂橫過胸前。"
      ],
      [
        "Support the upper arm with the other hand and hold.",
        "另一手托住上臂並保持。"
      ],
      ["Release and repeat on the other side.", "放開，再換邊。"]
    ],
    [
      "Keep the stretched shoulder down; do not pull on the elbow joint.",
      "伸展側肩膀放低，不要拉扯肘關節。"
    ],
    true
  ),
  move(
    "childs-pose",
    "Child’s pose",
    "嬰兒式",
    [],
    [
      ["Start on hands and knees.", "從四足跪姿開始。"],
      [
        "Move hips toward heels and reach arms forward; hold.",
        "臀部往腳跟移，雙臂向前伸展並保持。"
      ],
      ["Return slowly to hands and knees.", "慢慢回到四足跪姿。"]
    ],
    [
      "Use a comfortable knee bend and relax your neck.",
      "膝蓋彎曲至舒適幅度，頸部放鬆。"
    ],
    true
  )
];
export const exerciseIds = exercises.map((exercise) => exercise.id);
export function getExercise(id: string | null | undefined) {
  return exercises.find((exercise) => exercise.id === id);
}
export function canonicalCopy(exercise: ExerciseDefinition) {
  return {
    title_en: exercise.title_en,
    title_zh: exercise.title_zh,
    description_en: exercise.steps.map(([en]) => en).join(" "),
    description_zh: exercise.steps.map(([, zh]) => zh).join("")
  };
}
// Historical matching is deliberately strict: both titles AND full movement copy must match.
// No fuzzy matching or partial-name matching (e.g. push-up vs kneeling push-up).
export function resolveExercise(item: StructuredPlanItem) {
  if (item.exercise_id) return getExercise(item.exercise_id);
  return exercises.find((exercise) => {
    const copy = canonicalCopy(exercise);
    return (
      item.title_en.trim().toLowerCase() === copy.title_en.toLowerCase() &&
      item.title_zh.trim() === copy.title_zh &&
      item.description_en.trim() === copy.description_en &&
      item.description_zh.trim() === copy.description_zh
    );
  });
}
