# Landmarks handoff, 2026-10-18 17:30
## State: running a check (full suite on #59 at 80d8511; the AFL clip waits for the CI queue)

## Task
Landmarks role, reporting to LEAD ("Kaiju: Lead", local_106fc100...). PR bodies <= 8 lines, never
merge; LEAD does QA, critics, merges and the director. Both PRs are in the demo chain:
1. #57 landmark sites (A stadium city 1, D Sky Wheel Behemoth; D-071), branch claude/landmarks,
   base claude/look-options, head 14380de (7e4fb81 + gdformat). Auto-fix ON (LEAD: fine).
2. #59 stadium matches (D-078), branch claude/stadium-matches, DRAFT, stacked on #57 (base
   claude/landmarks; retarget to look-options once #57 merges), head 80d8511.
One worktree (../Kaiju-Incremental-wt/landmarks) switches between the two branches.

## #57 rounds (LEAD 2x + fresh critic)
- r1: ring stood as an ellipse speckled with holes, pitch grey -> sim `Arcs` (sim/arcs.gd: 24
  sectors x rim/stands, stub 2, inner 0.6, rim 0.86; data city.landmarks stadium.arcs): an arc's
  first lost chunk topples everything of it above the stub (rim out, stands in). No bites on
  landmarks (BuildingView.chip). Pitch laid on the ground (bake.py --ground, LandmarkVoxels.ground).
- Sim review: PASS; stand-as-built now loops every landmark (wheel included).
- Critic r2: slab rubble, hedge tint, slab over the plaza -> scenes/landmark_rubble.gd (Ruin.strip
  hands landmarks over): ragged heap tallest at the stub, <= 3.5 units past the wall, colours
  from LandmarkVoxels.rubble_colors. Shared Ruin tint untouched.
- Follow-up after the demo (in #57 body): broken wheel is a pancake -> bent rim section, a leg
  stub, scattered capsules ~30% smaller and desaturated.
- Pacing at 7e4fb81: no landmarks 0.58 / 4.45 h; arcs + bonus 4.0: 0.59 / 4.56 h (+1.7/+2.5%).
- Floors: city 21, load 12 (#57); flow 137 (#59). Fail-first logs in scratchpad.

## #59 (D-078) state
- Stills done (local GPU): docs/captures/2026-10-18-matches/{afl,nfl,soccer,cricket}{,_2x}.png.
- Left: 720p ~6 s AFL clip on CI with --renderer=gl_compatibility after the rooftop clip:
  tools/capture/ci_capture.sh --movie --renderer=gl_compatibility --resolution=1280x720 --fps=30
  capture_matches.gd -- --clip --out=<dir> (wall gives at ~frame 84; 11-13 of 22 out by 180).
- PR body draft: scratchpad pr59_new.md (fill SUITES59, then gh pr edit 59).

## Next
1. #59 suite green -> edit #59 body, commit this handoff, tell LEAD both heads.
2. Clip on CI when LEAD's queue reaches me; check it; commit under docs/captures/; un-draft #59.
3. After #57 merges: retarget #59 to claude/look-options.

## Findings for the lead
- voxelize.py shells surfaces only: a solid disc bakes as a cap; build open parts as rings.
- Rotated geometry and slow tapers alias at 8 voxels per floor; axis-aligned boxes bake clean.
- Godot --script with new class_names needs --import first; wrap probes in `timeout`.
- Probe the sim's events before changing a rule (the "vanishing" stadium was a stage-2 signature).
- A check that compares against the constant it tests passes when sabotaged: bound it by the bar.
- The dummy renderer (headless) keeps no MultiMesh transforms: test a builder's cells instead.
- A pacing script that edits tuning.json and is killed mid-run leaves the edit behind: restore.
- Merging into a branch that is not checked out: git merge-tree --write-tree + commit-tree.

## Rules learnt the hard way
- gdlint caps files at 400 lines, functions at 4 arguments; gdformat writes CRLF on Windows and
  must run after the last edit (CI runs gdformat --check).
- A failing check must run (not fail to parse): land the classes first, wire them second.
