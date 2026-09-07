// Authored vector key poses in a 300 × 250 viewbox. Near/far limbs remain separate.
// Joint order: head, shoulder, hip, far elbow, far wrist, near elbow, near wrist,
// far knee, far ankle, near knee, near ankle. Coordinates are SVG animation assets.
export type Point = [number, number];
export type Pose = [
  Point,
  Point,
  Point,
  Point,
  Point,
  Point,
  Point,
  Point,
  Point,
  Point,
  Point
];
export type Sketch = {
  poses: Pose[];
  prop?: "chair" | "support" | "wall";
  weights?: "both" | "near" | "goblet";
  band?: "feet" | "hands";
  toeAnchor?: boolean;
  view: "Front" | "Side" | "Three-quarter";
};
const front: Pose = [
  [150, 43],
  [150, 73],
  [150, 137],
  [121, 100],
  [118, 139],
  [179, 100],
  [182, 139],
  [131, 177],
  [124, 220],
  [169, 177],
  [176, 220]
];
const side: Pose = [
  [150, 43],
  [145, 73],
  [140, 137],
  [155, 100],
  [165, 134],
  [135, 104],
  [141, 142],
  [149, 179],
  [153, 220],
  [130, 179],
  [128, 220]
];
const squat: Pose = [
  [168, 86],
  [160, 115],
  [123, 160],
  [182, 117],
  [206, 112],
  [179, 126],
  [207, 125],
  [172, 173],
  [153, 220],
  [143, 182],
  [128, 220]
];
const hinge: Pose = [
  [203, 105],
  [180, 117],
  [124, 132],
  [186, 148],
  [187, 180],
  [173, 151],
  [178, 185],
  [145, 174],
  [153, 220],
  [126, 178],
  [128, 220]
];
const floor: Pose = [
  [67, 207],
  [89, 208],
  [162, 208],
  [96, 215],
  [122, 218],
  [113, 218],
  [140, 220],
  [194, 164],
  [221, 220],
  [181, 169],
  [209, 220]
];
const four: Pose = [
  [84, 119],
  [102, 138],
  [184, 141],
  [106, 177],
  [108, 220],
  [94, 180],
  [94, 220],
  [190, 217],
  [229, 220],
  [177, 217],
  [218, 220]
];
const plank: Pose = [
  [76, 139],
  [97, 149],
  [158, 174],
  [94, 185],
  [87, 220],
  [108, 185],
  [108, 220],
  [205, 197],
  [242, 220],
  [193, 194],
  [232, 220]
];
const lowPush: Pose = [
  [74, 189],
  [96, 191],
  [163, 203],
  [128, 209],
  [87, 220],
  [133, 218],
  [108, 220],
  [204, 211],
  [242, 220],
  [199, 210],
  [232, 220]
];
const wall: Pose = [
  [178, 51],
  [169, 78],
  [143, 142],
  [207, 87],
  [248, 94],
  [201, 95],
  [248, 104],
  [135, 181],
  [124, 220],
  [159, 181],
  [152, 220]
];
const wallLean: Pose = [
  [218, 53],
  [207, 81],
  [177, 141],
  [224, 115],
  [248, 94],
  [223, 125],
  [248, 104],
  [153, 181],
  [124, 220],
  [173, 181],
  [152, 220]
];
const curl: Pose = [
  [150, 43],
  [150, 73],
  [150, 137],
  [121, 100],
  [131, 65],
  [179, 100],
  [169, 65],
  [131, 177],
  [124, 220],
  [169, 177],
  [176, 220]
];
const seated: Pose = [
  [152, 68],
  [150, 98],
  [142, 159],
  [171, 121],
  [185, 154],
  [156, 124],
  [174, 158],
  [190, 163],
  [195, 220],
  [175, 171],
  [179, 220]
];
const withPoints = (base: Pose, points: Partial<Record<number, Point>>): Pose =>
  base.map((point, index) => points[index] ?? point) as Pose;
export const sketches: Record<string, Sketch> = {
  "march-in-place": {
    view: "Front",
    poses: [
      front,
      withPoints(front, {
        5: [188, 91],
        6: [171, 71],
        7: [112, 143],
        8: [112, 184]
      }),
      front,
      withPoints(front, {
        3: [112, 91],
        4: [129, 71],
        9: [188, 143],
        10: [188, 184]
      })
    ]
  },
  "step-jack": {
    view: "Front",
    poses: [
      front,
      withPoints(front, {
        3: [107, 58],
        4: [125, 23],
        5: [193, 58],
        6: [175, 23],
        7: [104, 177],
        8: [83, 220]
      }),
      front,
      withPoints(front, {
        3: [107, 58],
        4: [125, 23],
        5: [193, 58],
        6: [175, 23],
        9: [196, 177],
        10: [217, 220]
      })
    ]
  },
  "arm-circle": {
    view: "Front",
    poses: [
      withPoints(front, {
        3: [108, 73],
        4: [67, 73],
        5: [192, 73],
        6: [233, 73]
      }),
      withPoints(front, {
        3: [108, 65],
        4: [69, 57],
        5: [192, 65],
        6: [231, 57]
      }),
      withPoints(front, {
        3: [108, 73],
        4: [71, 78],
        5: [192, 73],
        6: [229, 78]
      }),
      withPoints(front, {
        3: [108, 81],
        4: [69, 91],
        5: [192, 81],
        6: [231, 91]
      })
    ]
  },
  "shoulder-roll": {
    view: "Three-quarter",
    poses: [
      side,
      withPoints(side, {
        1: [145, 65],
        3: [153, 94],
        4: [163, 128],
        5: [132, 97],
        6: [138, 136]
      }),
      withPoints(side, {
        1: [138, 67],
        3: [147, 97],
        4: [159, 131],
        5: [126, 100],
        6: [134, 139]
      }),
      withPoints(side, {
        1: [138, 75],
        3: [148, 104],
        4: [160, 138],
        5: [127, 108],
        6: [135, 146]
      })
    ]
  },
  "standing-hip-hinge": { view: "Side", poses: [side, hinge] },
  "bodyweight-squat": { view: "Three-quarter", poses: [side, squat] },
  "chair-sit-to-stand": {
    view: "Side",
    prop: "chair",
    poses: [
      seated,
      withPoints(side, {
        0: [193, 43],
        1: [187, 73],
        2: [184, 137],
        7: [189, 179],
        8: [195, 220],
        9: [177, 179],
        10: [179, 220],
        3: [191, 100],
        4: [200, 139],
        5: [173, 105],
        6: [176, 143]
      })
    ]
  },
  "wall-push-up": { view: "Side", prop: "wall", poses: [wall, wallLean] },
  "kneeling-push-up": {
    view: "Side",
    poses: [
      withPoints(plank, {
        2: [154, 179],
        7: [200, 220],
        8: [242, 220],
        9: [186, 220],
        10: [232, 220]
      }),
      withPoints(lowPush, {
        2: [155, 205],
        7: [200, 220],
        8: [242, 220],
        9: [186, 220],
        10: [232, 220]
      })
    ]
  },
  "standard-push-up": { view: "Side", poses: [plank, lowPush] },
  "supported-reverse-lunge": {
    view: "Side",
    prop: "support",
    poses: [
      withPoints(side, { 5: [184, 96], 6: [226, 119] }),
      [
        [165, 80],
        [162, 110],
        [156, 166],
        [171, 138],
        [181, 169],
        [191, 117],
        [226, 119],
        [112, 176],
        [73, 220],
        [193, 177],
        [190, 220]
      ]
    ]
  },
  "glute-bridge": {
    view: "Side",
    poses: [floor, withPoints(floor, { 2: [156, 180] })]
  },
  "standing-calf-raise": {
    view: "Side",
    toeAnchor: true,
    poses: [
      side,
      side.map((p, i) => [p[0], p[1] - (i === 8 || i === 10 ? 10 : 15)]) as Pose
    ]
  },
  "bird-dog": {
    view: "Side",
    poses: [
      four,
      withPoints(four, {
        3: [64, 140],
        4: [26, 140],
        9: [222, 142],
        10: [265, 142]
      }),
      four,
      withPoints(four, {
        5: [64, 133],
        6: [26, 133],
        7: [222, 135],
        8: [265, 135]
      })
    ]
  },
  "dead-bug": {
    view: "Side",
    poses: [
      withPoints(floor, {
        3: [94, 165],
        4: [94, 123],
        5: [105, 167],
        6: [105, 124],
        7: [169, 160],
        8: [220, 160],
        9: [156, 156],
        10: [207, 156]
      }),
      withPoints(floor, {
        3: [48, 205],
        4: [13, 205],
        5: [105, 167],
        6: [105, 124],
        7: [169, 160],
        8: [220, 160],
        9: [204, 199],
        10: [256, 205]
      }),
      withPoints(floor, {
        3: [94, 165],
        4: [94, 123],
        5: [105, 167],
        6: [105, 124],
        7: [169, 160],
        8: [220, 160],
        9: [156, 156],
        10: [207, 156]
      }),
      withPoints(floor, {
        3: [94, 165],
        4: [94, 123],
        5: [49, 216],
        6: [14, 216],
        7: [207, 201],
        8: [258, 207],
        9: [156, 156],
        10: [207, 156]
      })
    ]
  },
  "forearm-plank": {
    view: "Side",
    poses: [
      withPoints(plank, {
        0: [76, 163],
        1: [97, 178],
        2: [158, 192],
        3: [96, 217],
        4: [52, 220],
        5: [111, 220],
        6: [66, 220],
        7: [203, 220],
        9: [189, 220]
      }),
      withPoints(plank, {
        0: [76, 163],
        1: [97, 178],
        2: [158, 192],
        3: [96, 217],
        4: [52, 220],
        5: [111, 220],
        6: [66, 220],
        7: [205, 209],
        9: [193, 205]
      })
    ]
  },
  "goblet-squat": {
    view: "Three-quarter",
    weights: "goblet",
    poses: [
      withPoints(side, {
        3: [181, 108],
        4: [181, 83],
        5: [170, 114],
        6: [181, 83]
      }),
      withPoints(squat, {
        3: [193, 148],
        4: [196, 120],
        5: [181, 150],
        6: [196, 120]
      })
    ]
  },
  "dumbbell-romanian-deadlift": {
    view: "Side",
    weights: "both",
    poses: [side, hinge]
  },
  "supported-dumbbell-row": {
    view: "Side",
    prop: "support",
    weights: "near",
    poses: [
      withPoints(hinge, {
        3: [206, 119],
        4: [240, 159],
        5: [174, 151],
        6: [178, 185]
      }),
      withPoints(hinge, {
        3: [206, 119],
        4: [240, 159],
        5: [137, 103],
        6: [162, 135]
      })
    ]
  },
  "dumbbell-floor-press": {
    view: "Three-quarter",
    weights: "both",
    poses: [
      withPoints(floor, {
        3: [112, 217],
        4: [112, 176],
        5: [135, 220],
        6: [135, 179]
      }),
      withPoints(floor, {
        3: [99, 161],
        4: [105, 119],
        5: [117, 165],
        6: [120, 122]
      })
    ]
  },
  "dumbbell-biceps-curl": {
    view: "Front",
    weights: "both",
    poses: [front, curl]
  },
  "band-pull-apart": {
    view: "Front",
    band: "hands",
    poses: [
      withPoints(front, {
        3: [139, 79],
        4: [130, 79],
        5: [161, 79],
        6: [170, 79]
      }),
      withPoints(front, {
        3: [108, 77],
        4: [64, 77],
        5: [192, 77],
        6: [236, 77]
      })
    ]
  },
  "standing-band-curl": { view: "Front", band: "feet", poses: [front, curl] },
  "wall-calf-stretch": {
    view: "Side",
    prop: "wall",
    poses: [
      withPoints(wall, {
        7: [109, 179],
        8: [80, 220],
        9: [190, 180],
        10: [193, 220]
      }),
      withPoints(wallLean, {
        7: [128, 180],
        8: [80, 220],
        9: [209, 180],
        10: [193, 220]
      })
    ]
  },
  "seated-hamstring-stretch": {
    view: "Side",
    prop: "chair",
    poses: [
      withPoints(seated, { 9: [200, 186], 10: [251, 220] }),
      withPoints(seated, {
        0: [188, 91],
        1: [174, 116],
        3: [189, 147],
        4: [214, 170],
        5: [186, 148],
        6: [210, 181],
        9: [200, 186],
        10: [251, 220]
      })
    ]
  },
  "supported-quad-stretch": {
    view: "Side",
    prop: "support",
    poses: [
      withPoints(side, { 5: [184, 96], 6: [226, 119] }),
      withPoints(side, {
        3: [119, 105],
        4: [100, 142],
        5: [184, 96],
        6: [226, 119],
        7: [134, 183],
        8: [100, 142]
      })
    ]
  },
  "cross-body-shoulder-stretch": {
    view: "Front",
    poses: [
      front,
      withPoints(front, {
        3: [174, 86],
        4: [211, 91],
        5: [188, 103],
        6: [176, 84]
      })
    ]
  },
  "childs-pose": {
    view: "Side",
    poses: [
      four,
      [
        [93, 206],
        [117, 181],
        [209, 179],
        [81, 205],
        [40, 220],
        [86, 217],
        [47, 220],
        [180, 220],
        [230, 220],
        [170, 220],
        [218, 220]
      ]
    ]
  }
};

export function interpolatePose(
  sketch: Sketch,
  progress: number,
  held: boolean
): Pose {
  // Holds reserve most of the cycle for the final posture, then release deliberately.
  const cycle = ((progress % 1) + 1) % 1;
  if (held) {
    const t = cycle < 0.2 ? cycle / 0.2 : cycle < 0.8 ? 1 : (1 - cycle) / 0.2;
    return blend(sketch.poses[0], sketch.poses[1], t);
  }
  const position = cycle * sketch.poses.length;
  const index = Math.floor(position);
  const local = position - index;
  const eased = (1 - Math.cos(Math.PI * local)) / 2;
  return blend(
    sketch.poses[index],
    sketch.poses[(index + 1) % sketch.poses.length],
    eased
  );
}
function blend(a: Pose, b: Pose, t: number): Pose {
  return a.map(([x, y], i) => [
    x + (b[i][0] - x) * t,
    y + (b[i][1] - y) * t
  ]) as Pose;
}
