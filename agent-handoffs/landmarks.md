# Landmarks handoff, 2026-10-18 23:40
## State: running a check (#59 round 2 re-render on CI: runs 39108683628 stills, 39108705294 clip)

## Task
Landmarks role, reporting to LEAD ("Kaiju: Lead", local_106fc100...). PR bodies <= 8 lines, never
merge; LEAD does QA, critics, merges and the director.
- #57 landmark sites (A stadium city 1, D Sky Wheel Behemoth; D-071): MERGED as cce6309 into
  claude/look-options. Branch claude/landmarks stays on origin (never --delete-branch over a live
  worktree; LEAD prunes).
- #59 stadium matches (D-078): branch claude/stadium-matches, base claude/look-options, ready
  for review, head 0379e4a. Full suite + harness green there (flow 141 = 138 + 3).
One worktree (../Kaiju-Incremental-wt/landmarks), now on claude/stadium-matches.

## #57 as merged
- Sim `Arcs` (sim/arcs.gd): 24 sectors x rim/stands; a column belongs to an arc if it rises above
  the 2-floor stub, out to r 1.1 (the corner masts are outside). An arc's first lost chunk
  topples everything of it above the stub (rim out, stands in). Data: city.landmarks stadium.arcs.
- View: no bites on landmarks; pitch laid on the ground (bake.py --ground); LandmarkRubble heaps
  (ragged, tallest at the stub, <= 2 units past the wall, wall greys + seat reds only).
- Pacing: no landmarks 0.58 / 4.45 h; arcs + bonus 4.0: 0.59 / 4.56 h (+1.7/+2.5%). D-081: the
  4x bonus stays.
- Follow-ups after the demo (in #57's body / LEAD's list): broken wheel is a pancake (bent rim
  section, leg stub, capsules ~30% smaller, desaturated); stadium: ragged stumps of varying
  height, jagged per-column breaks, mounded chunk-sized heaps, seat rubble over the floor ring.
  E spire / F megatower bake (F needs a Performance look at ~816k voxels).

## #59 state
- Director 2026-10-18 (via LEAD): "the stadium needs to be full of people in the stands". Done in
  9032216: scenes/stadium_crowd.gd (StadiumCrowd, child of StadiumMatch). Up to 1000 fans on the
  model's top-open seat voxels (b23d32 / 8e3029), one per 3x3 voxels, shuffled; kit shirts 60%,
  else neutral; idle bob. Panic: fans on dead chunks hidden (fallen); rest stand, run along
  their row to the nearest of 8 exits away from the kaiju, then up the aisle; gone once off the
  seats for 0.6 (escaped). Draws 18 MultiMeshes seated (6 shirts x 3 skins), buffer uploads.
  tuning.json "crowd". Flow 144 (fail-first log: scratchpad crowd_failfirst_evidence.log).
- Round 2 (AFL clip FAILED its motion critic; LEAD's 5 fixes) in d665eb5, no sim change:
  match loose positions, 2x light ball (sports.json), 3 jostle at the ball, opening kick,
  drift; LandmarkBurst (scenes/landmark_burst.gd): inward landmark topples burst in place,
  no strip/crush (flow check failed first: 5 swung, 22 crushed); landmark debris flies out;
  landmark drops no longer crush the whole stadium; 8 dark tunnel mouths, staggered flight;
  crowd bob in crowd.gdshader; clip kaiju from the SSE (SE clipped the corner mast).
  city_view kept at 395 lines (Fire.prewarm moved out). Flow 145.
- Local GPU render (greenery's slot) showed every player in one midfield clump: the loose-
  placement loop compared a float32 to -0.04 and never ran. Fixed 6281641 (+ crowd casts no
  shadow). Suite green there (flow 145). Frame time crowd off/on (1080p, before no-shadow):
  frame 12.8 -> 15.6 ms, GPU 10.5 -> 13.3 ms; re-time when the director is not fullscreen.
  Slot passed to croc #54 (then #50). Re-render on CI (director in a fullscreen game).
- On CI landing: copy stills to docs/captures/2026-10-18-matches/, crops (afl/nfl/soccer/
  cricket _2x, crowd_stand_2x, afl_after_2x), mp4 to notes landmarks/, PR body, paths to LEAD.
- After the slot: pass it on as LEAD/greenery say. If round 2 fails, LEAD changes method
  (demo with sections bursting in place only).
- NEXT on the GPU slot: scratchpad local_crowd.sh (stills, --frametime off/on, clip; mp4 to
  720p). Then: 2x crop of a stand, commit stills, clip to notes landmarks/, paths + frame times
  to LEAD, PR body update.
- Earlier (pre-crowd): ready for review, base claude/look-options. Suite green at 3bc9f2e.
- AFL clip rendered on the local GPU (scratchpad local_clip.sh): notes landmarks/afl_cave_in_720p.mp4
  (mp4 is gitignored; Movie Maker wrote 1080p, scaled to 720p). Pair in docs/captures/2026-10-18-matches/.
- Own check: ~3.4-4.0 s the stands sections toppling inward show their dark hollow undersides
  over the pitch, then burst. Proposed fix if the critic fails it: landmark sections drop in place
  instead of rotating over.

## Findings for the lead
- voxelize.py shells surfaces only: a solid disc bakes as a cap; build open parts as rings.
- Probe the sim's events before changing a rule (the "vanishing" stadium was a stage-2 signature).
- A check bounded by the constant it tests passes when sabotaged: bound it by the bar.
- The dummy renderer keeps no MultiMesh transforms: test a builder's cells instead.
- A pacing script that edits tuning.json and is killed mid-run leaves the edit: restore it.
- Merging into a branch not checked out: git merge-tree --write-tree + commit-tree, then push.
- After a squash merge, resyncing a stacked branch can silently take old copies of files it
  never touched (lead.md here): diff the result against the base before pushing.

## Rules learnt the hard way
- gdlint: 400 lines per file, 4 arguments; gdformat writes CRLF on Windows and must run after
  the last edit (CI runs gdformat --check).
- A failing check must run (not fail to parse): land the classes first, wire them second.
