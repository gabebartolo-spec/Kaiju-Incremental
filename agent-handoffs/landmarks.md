# Landmarks handoff, 2026-10-18 12:00
## State: blocked (CI stills held: LEAD's capture queue is shell-hit -> military-ai 720p -> croc P3 first)

## Task
Original city landmarks, modelled in Blender and voxel-baked so they break chunk by chunk like any
building, placed through data, PR into claude/look-options to LEAD ("Kaiju: Lead", local_106fc100...):
8-line body, Auto-fix off, never merge. D-071 (director 10:5x): A stadium -> D Sky Wheel ->
E Signal Spire -> F Crown Megatower, one per city, growing. This PR = A + D (landmark sites);
E + F are a follow-up PR (F needs a Performance look at ~816k voxels).

## Branch and commit
Worktree ../Kaiju-Incremental-wt/landmarks, branch claude/landmarks, pushed head da168e4 (merge of
look-options 434bb49: #22 croc, #27 UI, #49 flow split). Full suite + harness self-test green there:
smoke 27, sim 50, powers 24, tentacles 18, city 19, growth 24, load 9, flow 129, clips 14.

## Done
- Board: 6 originals, critic r1-r5 (notes landmarks/board1..board5); r5 all PASS.
- Path: assets/source/landmarks/build_landmarks.py (Blender) -> tools/blender/voxelize.py ->
  tools/landmarks/bake.py -> assets/landmarks/<id>.kvox (flags = faces open to outside air) +
  data/landmarks.json (w, d, h, chunk mask). LandmarkVoxels + BuildingMesher mask.
- Sim: Landmarks.building(), Structure.keep(), Building.rubble_bonus, chunks_total = alive chunks.
  Packet: notes landmarks/sim_packet.md (LEAD reviews).
- Sites: CitySites grows grid cells round a data anchor (never across a ring avenue or the
  diagonal); CityGen skips streets inside; shapes come via cfg (Content merges landmark_shapes).
  CityLines = moved street-line helpers. City-fill reviewed the city_gen diff: no blockers.
- Data: stadium (22,-24) margin 0 tier 1, wheel (10,56) margin 2 tier 2, rubble_bonus 4.0.
  Pacing (--species=reptilian, evolve1 / tree): none 0.59/4.46 h; 2.0 0.61/4.90; 4.0 0.59/4.61.
- Rooftops on/off fixture runs with city.landmarks = [] (its hp check compares two cities).
- PR body drafted (scratchpad pr_body.md; RUNID and HEADSHA to fill).

## Next
1. When LEAD's three captures are done (check `gh run list --workflow capture.yml`: nothing
   in_progress or queued, and croc P3's chain finished), dispatch:
   tools/capture/ci_capture.sh --resolution=1920x1080 capture_landmarks.gd -- --out=<dir>
   (stadium/wheel _standing and _broken, game-camera angle, 9 s scripted rampage).
2. Own check + 2x crop of the break; commit to docs/captures/2026-10-18-landmarks/.
3. Open the PR into claude/look-options, Auto-fix off, bind with ccd_pr, send to LEAD. Board/log:
   D-071 + rubble_bonus 4.0 balance note.
Follow-ups: E/F bake (PR 2); the wheel drawn past the edge at stage 1 as a lure.

## Findings for the lead
- voxelize.py shells surfaces only: a solid disc bakes as a cap; build open parts as rings.
- Rotated geometry and slow tapers alias at 8 voxels per floor; axis-aligned boxes and constant
  rings bake clean (critic rounds r1-r4).
- A critic that reads a stale copy of the source reports fixed defects: point it at the current file.
- Godot --script with new class_names needs --import first; a runtime script error makes a
  headless --script hang: wrap probes in `timeout`.
- An "until nothing is running" capture watcher can jump a lead-set queue in the gap between two
  runs: hold dispatch by hand when the lead orders the queue.

## Rules learnt the hard way
- gdlint caps files at 400 lines and functions at 4 arguments.
- gdformat on Windows writes CRLF; convert back to LF before committing.
