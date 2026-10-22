# vfx-lead handoff (VFX lead, the lead's second in command), 2026-10-23

## State
First task done: `docs/VFX_STYLE.md` + contact sheet; two reviews sent to the lead (both FIX). Every effect any
builder makes now passes through me before the lead. Reports go to the lead only, never the director.

## Task
Director 2026-10-23: VFX oversight (builder + art critic) for fire, smoke, explosions, city destruction, ability
effects, Taskforce effects, post effects. Rule above all: one look per kind ("consistency is absolutely key").

## Branch and commit
claude/vfx-lead-c37456 (worktree .claude/worktrees/vfx-lead-c37456, reset onto origin/claude/look-options
5550b5cf). PR: see git log / gh pr list (docs + capture tools only).

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

## Unfinished changes
- PR #154 carries the docs, the capture tools and three base fixes (fx.gd sparks + tree puff on the dust family,
  powers_view.gd tail sweep -> Fx.shockwave). Smoke/flow/powers green locally; proof
  side-session-notes/.../vfx-lead/proof_base_fixes.png; the lead runs a fresh critic on them.

## Open findings for the lead (not mine to build unless assigned)
- Lightning Breath / Thunder Beam (D-108/112) not built anywhere: breath is the orange "Atomic" plasma, the
  ultimate a solid emissive box (powers_view.gd:120). ROADMAP b2-18.
- CityView.ring still draws the cephalopod's ink ring (octopus paused, D-124); deflect flash moves to white.
- Charcoal smoke invisible at night; a fire-lit underside for the shared smoke (D-141 "lit from below").
- fire.gd edited on fire-spread, ui-redesign and city-explosives-v2: merge #152 first.

## Running jobs
none

## Rules learnt the hard way
- A fresh worktree needs `git lfs pull`, the carve dll copied into native/bin (gitignored; newest build from a
  worktree whose native/src matches) and a headless --import before captures.
- The default rampage clock ends a long capture: set sim.time_left.
- override.cfg (no_focus, off-screen) is written in its own Bash call; gitignored.
- GDScript warnings are errors: no `int(Variant)` (use Num.i), no `as Fire` on a Variant (typed var assign).
