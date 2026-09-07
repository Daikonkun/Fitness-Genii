# Handled resistance tube review — 2026-09-07

Reviewed the requested account's production history read-only: 26 structured band items, 14 distinct titles, dated August 8–28, plus band-containing legacy Markdown plans dated June 10–August 5. Current equipment text is only “6kg resistance band”. The account and its saved plans were not edited.

The supplied product collage appears to show separate sleeved tubes with handles, a bar and foot attachments. It does not establish the user's accessory inventory, model, permitted stretch, or anchor ratings. Movement suitability below is an editorial assessment, conditional on the actual kit allowing the shown attachment and range. A nominal kg rating is not a constant load.

## Findings and decisions

| Historical movement family | Fit for pictured kit | Library decision |
| --- | --- | --- |
| Romanian deadlift | Suitable pattern with both feet secured and handles beside legs | Add explicit two-tube foot-strap variant |
| Standing bent-over row (legacy plans) | Suitable pattern with fixed foot attachments, neutral trunk | Add explicit two-tube foot-strap variant |
| Seated row / seated row with brace | Suitable pattern when foot straps are approved for seated pulling | Add secured foot-strap variant; do not map old “loop around feet” instructions to it |
| Front squat | Potentially suitable, but shoulder-level starting tension and full standing stretch are unverified | Defer until kit length/range is confirmed |
| Single-arm row, reverse fly, diagonal lift / half-kneeling chop | Potentially suitable with specific single-side attachments and sufficient range | Defer these distinct variants; the old chop copy also contradicts itself about holding one end while using both hands at the other |
| Row hold / row pulses | Potentially suitable with a confirmed row setup | Defer distinct held/pulsed animations; do not silently alias to continuous repetitions |
| Pull-apart / external rotation / pull-apart combinations / chest opener | Assumes suitable continuous band between hands, unlike independent foot-to-hand tubes | Exclude from handled-tube generation; retain existing flat-band IDs for confirmed flat-band users |
| Back-wrapped chest press, fly, floor press, close-grip press, press pulses, half-kneeling chest press | Assumes a continuous band can route across the upper back | Defer; photo does not verify this route for separate tubes or hard attachments |
| Squeeze press / press-out | Several descriptions omit a clear resistance anchor; “inner chest” emphasis is also overstated | Do not add those ambiguous instructions |
| Feet-anchored low-to-high press | Different resistance direction from a chest press; long stretch not verified | Defer rather than copy its chest-target claim |
| Banded dead bug | Inconsistent variants: arms pulling apart, feet looped, or handles held up without a defined anchor | Do not add; retain separate bodyweight dead bug |
| Suitcase march | A stepping-on-band anchor can be released when that foot lifts | Do not add as written |
| Face pull, pulldown, anchored standing press/fly/row (legacy) | Requires a rated external anchor not established by photo | Do not add |
| Good morning / banded push-up (legacy) | Requires shoulder/back routing or ends beneath palms; hard handles change the setup | Defer |

Added handled curl as part of the earlier requested handled-equipment optimization; it is not claimed to have occurred in the reviewed history.

## Implementation

Catalogue version 2 adds four stable IDs: `handled-tube-curl`, `handled-tube-romanian-deadlift`, `handled-tube-bent-over-row`, `handled-tube-seated-row`. Each has EN/Traditional Chinese setup, movement, return and form cues. SVGs show two separate tubes, handle grips/rings and fixed foot straps. Playback uses the existing isolated controls.

The Band setup selector requires explicit confirmation of flat band, handled tubes with matching foot straps, both, or unspecified. The existing equipment text stores a small setup marker for compatibility with old callers; the input hides that marker. Unspecified free text is not inferred as an attachment confirmation. Catalogue filtering excludes incompatible band moves, and the server independently rejects incompatible output before the revision RPC. Other equipment and injury constraints retain the existing planner behavior.

Old IDs, saved text and timers stay intact. No historical aliases were added because the recorded setup descriptions do not establish the new exact variants. Legacy Markdown stays intact. The forward migration extends only the ID check constraint; apply it before deploying this application version. This update has not been deployed.

## Reference basis and limits

- [Mayo Clinic bent-over tubing row](https://www.mayoclinic.org/healthy-lifestyle/fitness/multimedia/bent-over-row/vid-20084668)
- [Mayo Clinic seated tubing row](https://www.mayoclinic.org/healthy-lifestyle/fitness/multimedia/seated-row/vid-20084669)
- [Mayo Clinic tubing curl](https://www.mayoclinic.org/healthy-lifestyle/fitness/multimedia/biceps-curl/vid-20084666)
- [Ochsner Health tubing deadlift](https://blog.ochsner.org/articles/what-is-resistance-training-with-bands/)

These support movement mechanics with tubing, not certification of the photographed kit. The foot-strap adaptation is an inference from the pictured setup and is gated on the user's confirmation of the kit's instructions. No universal load, stretch ratio or anchor configuration is prescribed.

## Verification

Tests, typecheck, lint and production build passed in the isolated Node 24 runtime. The local Supabase stack applied the forward migration and passed integration checks for all four IDs through revisions 3 and 4, legacy v2 callers, v3 persistence, RLS, and invalid-output rollback with an active timer. Temporary integration users were removed and the local database stopped without backup.

Browser review covered the four assets' start/intermediate/end poses, desktop and 390px mobile layout (no horizontal overflow), reduced-motion static poses, play/pause, half-speed and keyboard activation. Read-only tracking buttons remained disabled. A row pose was adjusted to bring the handles toward the lower ribs. Missing-asset fallback and geometry tests passed. Production was queried read-only; this update is local and awaits deployment.

## Update: confirmed INNSTAR chest unit, bar and foot straps

The user supplied a second specification image and confirmed ownership of the bar and foot straps. The image identifies a padded bench-press/chest-expander assembly and a two-part bar, marked 96 cm when assembled. The chest assembly is marked 85–230 cm; this is not treated as the safe stretch limit of each separate tube. This new evidence supersedes the earlier uncertainty about whether the kit has a purpose-built back pad for chest pressing. It does not establish a door or external anchor.

Catalogue version 3 adds `innstar-bar-floor-press`, `innstar-standing-chest-press`, and `handled-tube-side-bend`, taking the library to 35 movements. The chest sketches use a visible pad and bilateral attachments; the bar remains rigid throughout the floor press. The core sketch uses a single same-side foot connection, both feet fixed, and a small lateral bend away from the loaded hand. It does not reuse the problematic suitcase march. The existing two row variants provide back coverage.

The new INNSTAR primary preset confirms the padded chest unit, bar, handles and foot straps. It requires chest, back and core kit exercises in the main workout, using explicit focus metadata. The server independently checks equipment and focus coverage before saving a revision. Missing coverage returns a bilingual error and preserves the current revision. The planner must explain inability to meet injury/time/feedback constraints instead of forcing coverage. This preset does not enable flat-band pull-aparts or unconfirmed external-anchor movements.

Historical chest-press descriptions are now plausible movement candidates, but remain unaliased: their saved copy does not identify the padded unit or exact bar/handle configuration. Saved plans are not rewritten. The prior front-squat, fly, chop and other deferred variants are not automatically approved by this update.

Sources: the user-supplied specifications and exercise collage, the [INNSTAR bench press and bar product description](https://innstarstore.com/products/innstar%C2%AE-bench-press), and the [CanDo side-bend movement reference](https://www.fab-ent.com/MEDIA/41_INSTRUCTIONS/CANDOBANDLOOP_MANUAL.PDF). The side-bend reference uses a different band; the foot-strap attachment is adapted from the user's kit photo. Marketing safety and equivalence claims are not repeated as verified facts.

The forward migration `20260907095936_innstar_chest_core.sql` must follow the handled-tube migration before deployment. Primary equipment preference is exposed as a saved-input preset; no email-specific behavior is hardcoded. This work remains local and does not change production account settings or saved plans.

Version 3 verification: full tests, typecheck, lint and production build passed. Local database migration and integration checks passed with all seven handled-kit IDs persisted through regeneration. New route tests prove incomplete primary-kit coverage is rejected without a revision write and a chest/back/core plan succeeds. Equipment tests exclude padded chest movements for foot-strap-only users, and preserve older markers. SVG tests check bar rigidity, pad/tube rendering and fixed feet. Desktop start/mid/end poses and 390px reduced-motion cards were visually reviewed; playback, half speed and keyboard activation worked while read-only timer controls stayed disabled. Local database fixtures were removed and the stack stopped without backup.
