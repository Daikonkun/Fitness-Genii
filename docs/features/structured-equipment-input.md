# Equipment selections and weight controls

Implemented after the INNSTAR kit release. This form update is local, not included in production commit 25e35ab.

The equipment section supports multiple selections: INNSTAR kit, dumbbells, bodyweight, and full gym set, with one selected primary option. Stable chair and wall support are separate explicit capabilities. Kit as primary preserves required chest/back/core coverage.

Dumbbells and full gym require a positive working weight per dumbbell, kg/lb units, and quantity one or two. One dumbbell only permits the supported single-dumbbell movements; two-hand animations cannot be generated with one dumbbell. Changing weight units clears the number rather than silently relabelling it. This release uses one user-selected working dumbbell weight for the session; an inventory of multiple adjustable weight increments is not implemented.

The kit has optional nominal resistance, kg/lb, rating basis (per tube, per side, whole assembly, unknown) and chest-unit tubes per side. Unknown remains unknown. The rating is not converted to constant load or multiplied to estimate assembly resistance. Changing resistance must be done in inputs, not through model-generated load instructions.

Full gym identifies availability but does not expand the exercise catalogue: only supported bodyweight and entered dumbbell movements are generated. The form explains that machine, cable and barbell routines remain unavailable. Requests requiring those unsupported movements must return an explanation.

Configuration is validated and stored as versioned JSON inside the existing equipment text column, avoiding a destructive schema change. Old free text remains readable and is shown for review; ambiguous descriptions are not silently converted into equipment ownership or weights. A previously confirmed primary INNSTAR preset imports its confirmed parts but does not infer a numeric rating basis. Saving uses the existing authenticated owner-scoped upsert. Unsaved/invalid equipment disables generation in the UI. Malformed structured configuration is rejected server-side before model invocation.

The prompt receives decoded equipment and catalogue entries filtered by capabilities. Server validation independently checks equipment, dumbbell count, kit coverage, and generated load language before the revision RPC. The application adds the entered dumbbell working weight or the kit's nominal-rating label to the prescription, which persists in both plan JSON and plan_items. Appended text must still satisfy historical prescription length limits. Existing timers, completion and revision behavior remain unchanged.

Validation: unit/route tests for malformed configuration, negative and nonfinite weights, equipment combinations, primary membership, quantity, units, controlled load labels, rejection of fabricated loads without revision writes, old markers and round trips. Local database integration verifies structured equipment storage alongside revision/timer/RLS behavior. Tests, typecheck, lint and build passed. Development-only review: /dev/equipment.

Browser verification passed at 390px without horizontal overflow. Mixed selection saved independently labelled dumbbell and kit values; switching dumbbell units cleared its number, invalid negative weight disabled preview save, and full-gym limitations were visible. A real OpenRouter request through the local application succeeded with structured kit settings and persisted the controlled nominal-rating labels in plan_items. The initial test used credentials from the wrong database and returned 401; its disposable fixture was removed before the corrected local run. Local test accounts and temporary model-key configuration were cleaned up afterwards.
