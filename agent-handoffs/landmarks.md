# Landmarks handoff, 2026-10-18 09:10
## State: running a check (pacing with/without landmarks; then CI stills, then PR to LEAD)

## Task
Original city landmarks, modelled in Blender and voxel-baked so they break chunk by chunk like any
building, placed through data, PR into claude/look-options to LEAD ("Kaiju: Lead", local_106fc100...):
8-line body, Auto-fix off, never merge. Director: "dont forget we can create our own models in
blender, but maybe you should work on some landmarks"; "use tripo if results in blender are poor"
(not needed: Blender passed five critic rounds).

## Branch and commit
Worktree ../Kaiju-Incremental-wt/landmarks, branch claude/landmarks, synced with look-options 2b241df
(merge 863d22a). Commits: db908ac path + sim, ca0cecf/1861996/f1078ae model rounds, dc4f0bb sites.
Not pushed yet (push before ci_capture.sh). Uncommitted: content.gd/city_sites.gd shapes-via-cfg,
tools/capture/capture_landmarks.gd, this file.

## Done
- Concept board: 6 originals (A stadium, B gate, C clock hall, D wheel, E spire, F megatower).
  Critic rounds r1-r5 (notes landmarks/board1..board5); r5: all six PASS. LEAD tabled the director
  question for the morning: which landmarks per city (rec A -> D -> E -> F; the demo needs A + D).
- Path: assets/source/landmarks/build_landmarks.py (Blender, all six) -> tools/blender/voxelize.py
  (height round(h*8)+1) -> tools/landmarks/bake.py -> assets/landmarks/<id>.kvox (flags = faces open
  to outside air) + data/landmarks.json (w, d, h, chunk mask). LandmarkVoxels + BuildingMesher mask;
  sim: Landmarks.building(), Structure.keep(), rubble_bonus, chunks_total = alive chunks.
- Sites: CitySites (sim) grows grid cells round a data anchor until the footprint fits, never
  across a ring avenue or the diagonal; CityGen skips streets inside and emits the entry;
  CityLines = moved street-line helpers (city_gen was at the 400-line cap). Ground/decor: one
  "plaza", "landmark" line each. Data: city.landmarks stadium (22,-24) margin 0 tier 1, wheel (10,56)
  margin 2 tier 2, both rubble_bonus 4.0 (pacing: evolve1 0.59 h = base, tree 4.61 h vs 4.46 h; 2.0 gave 4.90 h).
- Shapes reach CityGen via cfg: Content merges data/landmarks.json into city.landmark_shapes (LEAD
  ruling on city-fill's layering nit; done in Content so every cfg path has them, not only tuning_for).
- City-fill reviewed the city_gen diff: no blockers.
- Tests at dc4f0bb: smoke 27, sim 39, powers 24, tentacles 18, city 19, growth 24, load 9, flow 113.

## Next
1. Pacing (LEAD ruling a): tools/pacing.gd --species=reptilian with landmarks off vs on; keep
   evolve1 within +-5% of 0.59 h and the tree within +-5% of 4.46 h; lower the bonus if 2.0 breaks
   it; both tables in the PR; the number is a director balance note. Logs: scratchpad pace_*.log.
   pace.sh edits data/tuning.json during the baseline run and restores it: never commit mid-run.
2. Full suite, commit, push; ci_capture.sh --resolution=1920x1080 capture_landmarks.gd (stage 2:
   stadium + wheel standing/broken), one CI capture at a time; 2x crop of the break.
3. PR (<= 8 lines) with the sim packet (notes landmarks/sim_packet.md); LEAD runs the critic.
Follow-ups (not this PR): the wheel drawn past the edge at stage 1 as a "reach this" lure; bake
E/F once picked (megatower ~816k raw voxels: Perf).

## Findings for the lead
- voxelize.py shells surfaces only: a solid disc bakes as a cap; build open parts as rings.
- Rotated geometry and slow tapers alias into ragged edges at 8 voxels per floor; axis-aligned
  boxes and constant rings bake clean (critic rounds r1-r4).
- A critic that reads a stale copy of the source reports fixed defects: point it at the current file.
- Godot --script on a worktree with new class_names needs --import first, and a runtime script
  error makes a headless --script hang (debugger): always wrap probes in `timeout`.

## Rules learnt the hard way
- gdlint caps files at 400 lines and functions at 4 arguments.
- gdformat on Windows writes CRLF; convert back to LF before committing.
