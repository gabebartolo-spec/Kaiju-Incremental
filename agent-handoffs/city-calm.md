# City-calm handoff, 2026-10-19 03:30
## State: running a check (D-075 CI tests: red 39117893362, green 39117934874; pacing queued)
## NO LOCAL GODOT (director, via lead): verify on CI only (tests.yml dispatch, capture.yml).

## Task
Role city-calm (helper). Lead: "Kaiju: Lead" (local_106fc100). Anything sim goes to the lead.
- DONE: #26 calm streets (D-054), #28 export-windows, #30 ci-export, #37 no empty ground
  (D-062), D-065(b) green-lot table (lead), Landmarks city_gen review.
- DONE: PR #66 collapse-cap MERGED (329e708). Worktree removed; local branch claude/collapse-cap
  is left (squash-merged; `branch -D` needs the lead/director's OK). POST-DEMO (lead): sim
  Structure._topple_check rounds an overhang under 0.005 cells to a zero dir; FallMotion covers it.
- #55 r15 PASSED the lead's 2x check (CI green b037f69); lead merges after the demo exe. Push
  nothing more to claude/greenery (only an Auto-fix conflict resolve if asked).
- NOW: D-075 green lots 8%, branch claude/green-lots (from #55's head b037f69: it needs #55's
  park gardens) in the SAME worktree Kaiju-Incremental-wt/greenery (D-053: one worktree;
  switch back to claude/greenery only for a #55 Auto-fix, commit first, no stash). PR opens
  after #55 merges (into claude/look-options).
  - sim/city_green_lots.gd (CityGreenLots.choose from CityGen._blocks): farthest-point over
    the FULL city's blocks (all districts, not the playable edge, so stage-stable), from the
    block nearest cores[0], until city.green_lot_share 0.08 of block area; marks use "park",
    keeps the old use under "green". CityGen.generate fills green lots and drops them (same
    RNG draws for every other building).
  - tests/lib/city_green_lots.gd from the D-062 loop: share in [6.5%, 12%] + furthest building
    <= 2 x block_long[1] m from a park; no building on a green lot; same green blocks at
    stage 1. city floor 65 (+12).
  - tools/capture/pacing_ci.gd: pacing on capture.yml, --green-share=0.0 vs 0.08 (baseline
    moved with D-074b, so pace both on this branch). One capture.yml run at a time.
  - Still to do: CI results, pacing table, a look capture (CI) of the new parks, PR body with
    the kaiju-sim-review packet (notes greenery/D-075_packet_draft.md), report to the lead.
  - New .gd files have no .uid (no local import); CI imports them.

## Branch and commit
Worktree C:/Users/DANTE/Documents/GitHub/Kaiju-Incremental-wt/greenery, now on claude/green-lots.
#55 = claude/greenery head b037f69. Stray local branch claude/greenery-before:
delete when allowed.

## What #55 does
- scenes/city_greenery.gd: street trees on every avenue/street kerb (city-wide spacing), park
  garden, playground, front-yard hedges. All decor props, all crushable.
- scenes/city_decor.gd (397 lines, cap 400): body trample in _process. Every prop whose base
  is under the kaiju's ground box (scenes/kaiju_footprint.gd, from the kvox sculpt) goes down.
- scenes/prop_field.gd: a tree is crushed in place (lead, rule 8 after ten topple rounds): a
  pale stump (city.stump_color) stays, the cells above are hidden, 1 in 4 leaf cells and every
  bark cell go to PropField's leaf_field / bark_field (DebrisField, size_scale/lift knobs; the
  decor adds them), bark dark brown, scattered at spawn, flung toward the camera; drained before
  they process (contact frame). Stump: bark sides, warm cut top. Fx.tree_puff: soft unlit radial
  sprite, 30% peak in 2 frames, gone <1 s (footfall puffs vanish in the smoke centre clearing).
  group["origins"]/["keys"] are kept because headless MultiMeshes keep no transforms.
- tests/lib/city_trample.gd: tail tree goes down; crushed tree leaves stump + debris same frame.
  city floor 53.

## Evidence (notes side-session-notes/local_9fac90d2-.../greenery/)
- r14/: trample/clip_720p.mp4 + lossless clip.avi (from f0), fall_strip.png, contact_seq_2x.png,
  stump_puff_bark_3x.png, pair_r14_2x.png, samples.txt (from the avi), proplog.
  r12/stump_accounting_2x.png (tree 643's stump behind a standing crown).
- city_red_r11_crush.log (6 FAILs, debris off); run_tests_r16.log (full suite, r14 code).
- Older rounds r9-r13 failed. Sample the lossless avi: mp4v bleeds colour on small pieces.

## Next
1. r15 is done (notes greenery/r15/: strip_f0_f36_2x.png, puff_alpha.txt, samples.txt,
   stump_f0_f3_4x.png, flight_*/ leaf-flight runs, trample/clip). Lead merges #55 after the
   demo build; keep it synced (merge origin/claude/look-options, floors = real counts, CI only).
   After #55 and D-075 merge, remove the worktree.
2. Stomp shockwave tan crescents (rampage.gd:177) are not #55's; the lead excluded them.

## Rules learnt the hard way (under 10 lines)
- Branch off origin/claude/look-options; confirm the worktree exists before git commands.
- Lint before push: python -m gdtoolkit.linter AND gdtoolkit.formatter --check.
- Headless MultiMesh keeps no instance transforms or colours: tests read a CPU mirror.
- Never edit files under a running suite; other sessions share /tmp, read your own log.
- Local windowed Godot: no_focus override.cfg first (Write tool), removed after.
- Night/dusk lighting darkens debris and smoke: sample pixels at game camera before sending.
