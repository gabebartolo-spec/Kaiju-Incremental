# Landmarks handoff, 2026-10-19 04:40
## State: awaiting lead (#59 r5 tweaks + resync pushed, head 4229d5f; LEAD checks the strip at 2x and merges on green)

## Task
Landmarks role, reporting to LEAD ("Kaiju: Lead", local_106fc100...). PR bodies <= 8 lines, never
merge; LEAD does QA, critics, merges and the director.
- #57 landmark sites (A stadium city 1, D Sky Wheel Behemoth; D-071): MERGED as cce6309 into
  claude/look-options. Branch claude/landmarks stays on origin (never --delete-branch over a live
  worktree; LEAD prunes).
- #59 stadium matches (D-078): branch claude/stadium-matches, base claude/look-options, ready
  for review, head 4229d5f. Full suite green there (flow 146 = 139 + 7).
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
- Round 5b (LEAD's 2x check: core PASS): merged look-options with #54 (ad0a773; floors city 23,
  growth 26, flow 146); 4229d5f: chunks in the wall's albedo x0.65, 30% at x0.45, unshaded
  (tuning chunk_shade / chunk_dark / chunk_dark_share); dust = 7 soft smoke.gdshader billboards
  (Fx's step puff, MultiMesh, centre_keep 1) instead of spheres. Strip re-rendered
  (scratchpad local_strip.sh). Proof LEAD asked: strip only + suite. Chunks read warm beige.
- Round 5 (2821786, captures 0c01c61): r4 passed bar one blocker (burst read as a vanish).
  LandmarkBurst now: 7 opaque dust balls on the break frame + ~360 lit 2-3 voxel chunks flung
  outward for 0.3 s + 40 physics fragments (tuning.json "landmark_burst"). Strip
  burst_f60_75_2x.png; clip notes landmarks/afl_crowd_r5_720p.mp4. No new critic; LEAD checks
  and merges. Post-demo (LEAD): break position vs head, far-ring exit timing, fans streaming
  out by the breach, spreading the sports-still clusters.
- Round 4 (d119953, captures b95893f; LEAD's change of method): every landmark section bursts
  in place on its break frame (LandmarkBurst: piece gone, ~120 voxels sprayed outward, dust; no
  topple/strip/crush). Crowd flee all in crowd.gdshader (flee_t uniform; StadiumCrowd only
  counts escapes with the same golden-ratio hash and hides fallen/crushed). 3965 fans: 53% out
  at +1 s, all by +2.1 s. Pale kits dress fans in kit trim. Ball rolls and fades. Clip notes
  landmarks/afl_crowd_r4_720p.mp4; far_stand_flee.png. Passes -> LEAD merges.
- Round 3 (7baf9d1, captures a61467f): 3965 fans (spacing 2), static MultiMesh per outfit,
  runner pool 500, 16 exits; ball 3x lit + carried; landmark back faces 0.8 ("inside" in
  landmarks.json); landed landmark sections shrink 0.15 s (LandmarkBurst.retire); nearest of
  12 mouths, shock 0.1-0.4; stills use a pitch-aimed game-offset camera; clip 180 frames.
  Clip notes landmarks/afl_crowd_r3_720p.mp4. LEAD merges after r3 if only polish is left.
- Local re-render at a5073d4 (captures ce56405): clip notes landmarks/afl_crowd_r2_local_720p.mp4.
  Crowd CPU: calm 0.015 ms, flee 6.2 -> 1.5 ms (cached cfg, no trig, STRIDE 3). GPU 1080p
  off/on: frame 5.85/5.82, GPU 3.97/4.19 ms. Ball still small at game cam (offer 3x).
  No GPU baton now (LEAD: up to 3 windowed at once while the director is away).
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
