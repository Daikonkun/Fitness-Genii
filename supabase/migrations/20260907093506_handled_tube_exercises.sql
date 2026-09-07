alter table public.plan_items drop constraint plan_items_supported_exercise_id;

alter table public.plan_items add constraint plan_items_supported_exercise_id
  check (exercise_id is null or exercise_id in (
    'march-in-place',
    'step-jack',
    'arm-circle',
    'shoulder-roll',
    'standing-hip-hinge',
    'bodyweight-squat',
    'chair-sit-to-stand',
    'wall-push-up',
    'kneeling-push-up',
    'standard-push-up',
    'supported-reverse-lunge',
    'glute-bridge',
    'standing-calf-raise',
    'bird-dog',
    'dead-bug',
    'forearm-plank',
    'goblet-squat',
    'dumbbell-romanian-deadlift',
    'supported-dumbbell-row',
    'dumbbell-floor-press',
    'dumbbell-biceps-curl',
    'band-pull-apart',
    'standing-band-curl',
    'wall-calf-stretch',
    'seated-hamstring-stretch',
    'supported-quad-stretch',
    'cross-body-shoulder-stretch',
    'childs-pose',
    'handled-tube-curl',
    'handled-tube-romanian-deadlift',
    'handled-tube-bent-over-row',
    'handled-tube-seated-row'
  ));

