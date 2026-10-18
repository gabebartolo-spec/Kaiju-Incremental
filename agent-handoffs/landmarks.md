# Landmarks handoff, 2026-10-18 19:00
## State: blocked (#59's AFL clip waits for my CI turn; LEAD pings)

## Task
Landmarks role, reporting to LEAD ("Kaiju: Lead", local_106fc100...). PR bodies <= 8 lines, never
merge; LEAD does QA, critics, merges and the director.
- #57 landmark sites (A stadium city 1, D Sky Wheel Behemoth; D-071): MERGED as cce6309 into
  claude/look-options. Branch claude/landmarks stays on origin (never --delete-branch over a live
  worktree; LEAD prunes).
- #59 stadium matches (D-078): branch claude/stadium-matches, base claude/look-options, DRAFT,
  head 3bc9f2e. Full suite + harness green there (flow 141 = 138 + 3).
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

## #59 next
1. When LEAD says it's my CI turn (after croc P3, military re-shoot, rooftops):
   tools/capture/ci_capture.sh --movie --renderer=gl_compatibility --resolution=1280x720 --fps=30
   capture_matches.gd -- --clip --out=<dir> (wall gives ~frame 84; 11-13 of 22 out by 180).
2. Check the clip (players jog, wall caves, they run for the tunnels), commit it under
   docs/captures/2026-10-18-matches/, fill the body's Evidence, un-draft, tell LEAD (fresh motion
   critic is LEAD's).
Body draft: scratchpad pr59_new.md (already on GitHub).

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
