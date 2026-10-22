# vfx-lead handoff (VFX lead, the lead's second in command), 2026-10-23

## State
Split (director 2026-10-23, via lead): I own EVERY visual item end to end (decide, brief my own Sonnet builders in
their own worktrees, art QA, SHIP final); the lead owns sim, gameplay, UI layout/flow, tests, merges, docs. Tell
the lead before touching a file its builders are in (fire.gd: UI branch; sim + Taskforce: explosions PR 1). The
lead's explosions + UI builders keep their visual work; the lead relays proof/verdicts verbatim. Every session and
helper keeps the app checklist (update_plan) current; say so in every brief. Director 2026-10-23: at most 2
engine-running builders for me (4 team-wide); NO full suite on this PC (touched suites only, GitHub runs full).

## Task
Director 2026-10-23: VFX oversight (builder + art critic) for fire, smoke, explosions, city destruction, ability
effects, Taskforce effects, post effects. Rule above all: one look per kind ("consistency is absolutely key").

## Branch and commit
Worktree .claude/worktrees/vfx-lead-c37456. claude/vfx-lead-c37456 = PR #154 (look sheet + base fixes).
claude/heli-deaths (from look-options a85944f2) = item 3, PR when the full suite is green.

## What exists
- docs/VFX_STYLE.md: 10 families (owner files, material, ramp, scale), "Two looks today" table, review checklist.
- tools/capture/capture_vfx_sheet.gd (every family at the game camera, --run=1 night / 3 noon, side camera for
  breath and ultimate, run clock set to 600 s) + tools/capture/vfx_sheet.py (one labelled sheet, night|noon pairs).
- docs/captures/2026-10-23-vfx/vfx_families.png (the sheet).
- Reviews in side-session-notes/local_a16cd984-.../vfx-lead/reviews-2026-10-23.md.

## Director rulings 2026-10-23 (asked in my session with a labelled board; sent to the lead to log as D-n)
Blast = a sudden burst of Fire's own rising flames + the Fire left burning; gas = smoke shader tinted; smoke lit
from below everywhere; title burning windows orange with flames out of the openings; Lightning Breath/Thunder
Beam rework in M1; Taskforce = one electric blue nobody else uses (deflect flash -> white); blast/Taskforce hits
use the street dust; I fix the base mismatches (tail ring, tree puff, shell sparks) now, in PR #154.

Second batch, 12 visual-direction answers (cinematic fire, escalating haze, dust walls, block-wide stomp waves,
debris rain, rare slow-mo, glass, blackouts, bloodless, crushed kills, lightning charge-up on the body, clean
Taskforce tech): recorded in VFX_STYLE.md "Visual direction"; sent to the lead to log.

## Standing queue (lead 2026-10-23; my SHIP is final for effects; report <= 6 lines per item, name the next)
1 VFX_STYLE + sheet (done, #154) · 2 verdicts: explosions r8 FIX, title FIX x2 (notes reviews-2026-10-23.md) ·
3 helicopter deaths (ROADMAP #86, D-140/141/145), build sim+view, own branch, PR · 4 BuildingView.lift_piece
collapse defect (scenes/building_view.gd:204) · 5 Taskforce effects as its sim lands · 6 textured-surfaces board
(one building, three detail styles) · 7 graphics preview scene · 8 load-screen board (~20 shots).
Bar: three pillars (beauty, consistency, scale/power); SHIP only if the director will love it.

## Item 3 helicopter deaths (claude/heli-deaths, 78222347)
sim/air_wing.gd: blow_apart share decides burst vs spin; Falling list, own stream Seeds.derive(rng,0xFA11);
crash ignites the nearest building (City Ablaze) then smashes crash_floors (never the kaiju, air excluded via
_crashing); tentacle grabs clear_dead(true). scenes/heli_wreck.gd draws it (Fire burst / trail, debris, dust,
ripple, crew under arched canopies). tests/run_helideaths_tests.gd 6 fn 17 checks green; blow_apart 0 -> 6 red.
Proof: notes vfx-lead/heli_deaths_proof.png. A toppling tower tall enough sweeps helis over its strip down.
Not built: killable parachutists (they only drift down).

## Unfinished changes / my builders (Agent subagents, own worktrees)
- PR #154: fresh critic (mine) said FIX: sparks still white flecks, tail ring ~80 px vs a 400 px tail, rings
  invisible at noon, tree puff a white blob at noon. Builder on claude/vfx-lead-c37456 fixing; proof due at notes
  vfx-lead/proof_base_fixes_r2.png. Then a NEW fresh critic; on PASS message the lead "#154 PASS" (its GitHub
  helper merges on green).
- Thunder Beam builder on claude/thunder-beam (b2-18 spec, VFX_STYLE family 6): bolt.gdshader ribbon, breath
  strokes, held beam; proof + 3 halo stills (R 17.6) in notes vfx-lead/thunder/. No PR until my SHIP; halo colour
  goes to the director as one question with the labelled stills.
- Explosions claude/city-explosives-v2 (r9 at 5a9697db, 11 behind look-options) is now MINE: burst reads cream,
  not orange-red. Brief ready at scratchpad brief_r9.md (raise the fire family ramp for all fires, blast heat
  ~1.1, scale/light); goes to my next free builder slot; tell the lead before fire.gd edits (#160 has fire.gd).
- #160 title (claude/ui-title-menu): my verdict FIX = director's tilt + warm 2-3 px head rim; lead's builder does it.
- Title: D-158 amended (director 02:25, asked by the lead): Colossus ~185 m, ~7 deg tilt (water ~1/3 thinner,
  reflections kept), the 163 m tower lowered on the title only; head 1.5-2x the tallest tower left, whole. Title-
  look questions now go through me. Review its 4K reveal still + 2x head crop (with the rim fix).
- D-155 atmosphere (all M1): looks are mine (rampage escalation haze/orange sky/blackouts, clouds, birds, boats,
  one whale, weather looks rain/fog/storm/overcast). Sim side (weather pick, life positions/events, options row) =
  lead's "demo-end" session local_d3ef25ef; I asked it for value names + branch. Files: data/looks.json,
  scenes/city_environment.gd (wait for #156 to merge), new view scenes. Shared lit-from-below smoke: mine, after
  the UI + explosions branches merge (no fire.gd / smoke.gdshader edits till then).

## Open findings
- CityView.ring still draws the cephalopod's ink ring (octopus paused, D-124); deflect flash moves to white.
- Charcoal smoke invisible at night; a fire-lit underside for the shared smoke (D-141 "lit from below").
- fire.gd edited on fire-spread, ui-redesign and city-explosives-v2: merge #152 first.

## Running jobs
Touched suites on claude/heli-deaths (helideaths tentacles military powers), auto-start 02:58 after the director's
Godot pause, log scratchpad touched.log (no full suite on this PC any more). When green:
push claude/heli-deaths, open the PR as ready with body scratchpad pr_heli.md (sim-review packet inside), tell the
lead (proof notes vfx-lead/heli_deaths_proof.png). If the session restarts, rerun `tools/run_tests.sh` first.

## Item 4 (collapse defect, BuildingView.lift_piece) — diagnosed in part, parked
Defect (fire-spread clip v5 QC): (d) tilted falling block shows a see-through window lattice; (e) a neighbour's
walls vanish into floor plates. capture_topple_faces.gd (one 24-floor office city, scripted chew, --solid=1 turns
the fade off; scratchpad topple3/) shows: (d) = FallFade's screen-door on a falling piece that covers the kaiju
(R 19.4 fade, by design; with fade off the piece is solid). Cut faces are NOT see-through: building_baked draws
back faces at `inside` 0.12, so a cut reads as a dark hollow, not the carved slab colour (8a8780, D-101); possible
fix = cap quads. A "+" lattice on the landed rubble was a helicopter rotor's shadow. (e) not reproduced (no
neighbours in that city). Next: find the v5 clip frames (ask the lead) before choosing a fix. The chunks-inside-
capture_topple_faces.gd (off the heli branch). Chunks-inside-body: sim-side, the lead took it.

## Rules learnt the hard way
- A fresh worktree needs `git lfs pull`, the carve dll copied into native/bin (gitignored; newest build from a
  worktree whose native/src matches) and a headless --import before captures.
- The default rampage clock ends a long capture: set sim.time_left.
- override.cfg (no_focus, off-screen) is written in its own Bash call; gitignored.
- GDScript warnings are errors: no `int(Variant)` (use Num.i), no `as Fire` on a Variant (typed var assign).
