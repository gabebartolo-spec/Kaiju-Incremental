# City-calm handoff, 2026-10-19 03:30
## State: running a check (D-075 green on CI; capture.yml queue: probe, pacing x2, aerials x4)
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
  - sim/city_green_lots.gd (CityGreenLots.choose from CityGen._blocks): a staggered lattice
    on the street grid, one block in city.green_lot_every [3, 4] (8.3%), keyed by the block's
    "cell" (i, j) that CityGen._blocks now stores; skips landmark sites ("site": outer at
    stage 1, landmark later), parks/plazas/parking, outskirts. Marks use "park", old use under
    "green". generate fills green lots and drops them (same RNG draws). Farthest-point by
    area was tried first and failed (67 m spread, stage-unstable via landmark sites).
  - tests/lib/city_green_lots.gd from the D-062 loop: lots' own share 8.3% +-3.5 from the
    Behemoth, >= 1 lot at stage 1; furthest building <= 52 m from any park/plaza/lot (past the
    edge too); no building on a lot; same blocks as stage 1. city floor 65 (+12).
  - CI: red claude/green-lots-red run 39122099360 (12 FAILs); green 39122101734 (all pass).
  - Queue (scratchpad d075_ci.sh, polls 2-3 min; the API limit is shared, ci_capture.sh
    polls every 4-15 s): green_lots_probe.gd, pacing_ci.gd (+ --no-green), capture_growth
    --stage=1/2 --quick on green-lots and green-lots-red. Output: notes green-lots/.
  - Then: PR body (scratchpad pr_d075.md draft) + lead report; PR opens after #55 merges.
    Delete claude/green-lots-red after (ask the lead).
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
