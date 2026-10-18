# City-calm handoff, 2026-10-18 20:40
## State: awaiting lead (#55 r12 sent; #55 merges after the demo build per D-084)

## Task
Role city-calm (helper). Lead: "Kaiju: Lead" (local_106fc100). Anything sim goes to the lead.
- DONE: #26 calm streets (D-054), #28 export-windows, #30 ci-export, #37 no empty ground
  (D-062), D-065(b) green-lot table (lead), Landmarks city_gen review.
- NOW: D-065(a) greenery + body trample, PR #55 into claude/look-options. r11 is the LAST critic
  round (D-084 took the topple out of the demo): if it fails, #55 waits until after the demo.
- NEXT: D-075 = D-065(b) at 8% green lots, its own PR after #55 merges: city.green_lot_share
  0.08 in CityGen/CityLots (data); parks/gardens/playgrounds/plazas spread so no building is
  more than ~2 blocks from one; crushable; pacing table near evolve1 0.64 h / tree 4.88 h;
  kaiju-sim-review packet; city checks failing first. Draft: notes greenery/D-075_packet_draft.md.
  city_gen.gd is at 399 lines: the green-lot pass needs a new sim file.

## Branch and commit
claude/greenery, worktree C:/Users/DANTE/Documents/GitHub/Kaiju-Incremental-wt/greenery,
PR #55 head: see git log (synced with look-options after r12). Stray local branch claude/greenery-before:
delete when allowed.

## What #55 does
- scenes/city_greenery.gd: street trees on every avenue/street kerb (city-wide spacing), park
  garden, playground, front-yard hedges. All decor props, all crushable.
- scenes/city_decor.gd (397 lines, cap 400): body trample in _process. Every prop whose base
  is under the kaiju's ground box (scenes/kaiju_footprint.gd, from the kvox sculpt) goes down.
- scenes/prop_field.gd: a tree is crushed in place (lead, rule 8 after ten topple rounds): a
  pale stump (city.stump_color) stays, the cells above are hidden, 1 in 3 leaf cells and every
  bark cell go to the decor's own DebrisField (size_scale/lift knobs) in city.tree_debris_leaf /
  _bark, size 2x, speed 4, drained before the field processes (burst on the contact frame).
  Fx.earth_puff: soft radial unlit tan sprites, alpha ramps in over 2-3 frames, gone at 1 s.
  group["origins"]/["keys"] are kept because headless MultiMeshes keep no transforms.
- tests/lib/city_trample.gd: tail tree goes down; crushed tree leaves stump + debris same frame.
  city floor 53.

## Evidence (notes side-session-notes/local_9fac90d2-.../greenery/)
- r12/: trample/clip_720p.mp4 (from f0), fall_strip.png, contact_seq_2x.png, pair_r12_2x.png,
  samples.txt, stump_accounting_2x.png (tree 643's stump behind a standing crown), proplog.
- city_red_r11_crush.log (6 FAILs, debris off); run_tests_r14.log (full suite, r12 code).
- Older rounds: r9/, r10/ (topple), r11b/ (crush v1), all failed. PR body: scratchpad pr_green.md.

## Next
1. The lead critics r12 after the demo build ships; fix findings, re-render locally (no GPU
   baton while the director is away: own override.cfg, removed after). Then merge, D-075.
2. Stomp shockwave tan crescents (rampage.gd:177) are not #55's; the lead excluded them.

## Rules learnt the hard way (under 10 lines)
- Branch off origin/claude/look-options; confirm the worktree exists before git commands.
- Lint before push: python -m gdtoolkit.linter AND gdtoolkit.formatter --check.
- Headless MultiMesh keeps no instance transforms or colours: tests read a CPU mirror.
- Never edit files under a running suite; other sessions share /tmp, read your own log.
- Local windowed Godot: no_focus override.cfg first (Write tool), removed after.
- Night/dusk lighting darkens debris and smoke: sample pixels at game camera before sending.
