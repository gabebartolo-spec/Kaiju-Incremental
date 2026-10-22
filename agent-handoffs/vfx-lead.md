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

## Open findings for the lead (not mine to build unless assigned)
- Lightning Breath / Thunder Beam (D-108/112) not built anywhere: breath is the orange "Atomic" plasma, the
  ultimate a solid emissive box (powers_view.gd:120). ROADMAP b2-18.
- Second looks on base: Fx.tree_puff sprite, CityView.ring hazard-yellow torus, Fx.sparks plain cubes.
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
