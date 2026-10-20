# Lead handoff, 2026-10-21 (lead 8 -> lead 9; lead 8 stood down at 500k)
## Next lead: register (empty file named by your CLI session id in ~/.claude/context-guard-leads/), read this, then
## GitHub (open PRs), then list_sessions. Director's /goal: playable build with building carving first draft.
## Plan = docs/ROADMAP.md "Post-demo plan" phases A-H; every comment in docs/roadmap/2026-10-20-build2-playtest.md
## (30 notes) and docs/roadmap/2026-10-20-director-comments.md (rows 1-17; rows 18-19 still to add, see below).

## Team (director 2026-10-20/21)
- Builders: the lead only ("No, I'll do Phase A"). Helpers: TWO Sonnet-high readers/critics he gave ("i afforded you
  two sonnet high helpers, use them wisely", "keep your devs working"): Senior dev 1 (local_130ddd7e, briefed: fresh
  review of #113 + read-only trace of b2-30/b2-29 freezes, NOT yet reported) and Senior dev 2 (local_87436601,
  excellent; last brief: save its maps to the notes folder + draft new copy for every upgrade string). Keep both busy
  with read/critic work every turn; they write no code. They report to the lead session id: re-point them to you.
- Notes folder (maps, copy draft): C:\Users\DANTE\AppData\Local\Claude-Data\claude_pzs8sxrjxfjjc\side-session-notes\
  local_962460da-74da-4903-8671-f465e00da040\ (phase-maps.md, phase-maps-copy.md once senior2 writes them).

## Open PRs / branches (all into claude/look-options; mog.sh watchers die with lead 8: re-arm)
- #113 river rise along the channel, head 29d3c61: CI shard 2 was queued a long time; merge on green.
- #114 edge bollards (comments #18), head 1468da3: critic FIX applied (taller/denser/glow/tree clear, band-filtered
  perf, per-side test). City + smoke green locally. Merge on green.
- claude/b2-21-stadium-north 71b6d74 (pushed, NO PR): stadium past the baby's edge (director picked "A past the
  edge"): anchor [-24,-57], wheel [30,-56], landmark plaza to the kerb (sim/city_sites.gd _inset, no sidewalk), test
  tests/lib/city_stadium_far.gd failed first (75-78 m) -> 105-108 m. City green. Wide suites (growth flow sim
  landmarkcells load military smoke) were running: rerun them, then merge look-options in, add roadmap rows 18
  (edge: "the edge of the play area needs to be indicated somehow (not too loud)") + 19 (two Sonnet helpers) +
  b2-21 status, drop "armoured scales" from Phase A (passes: senior2), open the PR. A wider district ring (72/73/74)
  was tried and broke other city checks: do not go back to it.
- claude/b2-22-party-facades 162427a (pushed, NO PR, Phase C prep): blank party walls removed in sim + view, pin
  updated. Suites (cells cell_mesh city load) were running. Needs a capture + lead 2x before PR; PR only after build 3.
- PR cap 3. Merged today: #109 WP7, #110, #111, #112.

## NEXT
1. Re-arm merges for #113, #114; finish the stadium PR (above). Then build 3 = Phase A gate:
   `gh workflow run build.yml --ref claude/look-options` (build 2 came from carve-play 3998051). Smoke the exe, put it
   in C:/Users/DANTE/Documents/GitHub/Kaiju-Builds/, tell him with a 5-line what-changed list.
2. Director question at Phase C start (senior2 draft, phase-maps.md): b2-4 "effortless carving even for a baby" vs
   D-091 (big buildings take the baby longer). Options A effortless + size shows in bite size (rec), B floor the
   slowdown (<=2x), C keep D-091, fix feel with VFX. Also drop VISION.md:26-27 tier-gate sentence (stale since D-091).
3. Phase C/D/E/F maps with file:line are in the notes folder (senior2). Phase D turning: sim.facing is instant, only
   body.heading lags (turn_rate 10): move along body.heading, turn_rate ~3-4, head yaw leads (biped_head.gd).

## Findings this session (evidence in PR bodies)
- Tail sweep fired but cut 0: reach shorter than its own tip (fixed #111). Smooth stick turns never sweep (Phase D).
- Ruin wall stubs were the "burning buildings" (fixed #111). Breath crushed only round the feet (fixed #111).
- Kaiju rose facing the bank: head over the road (#113). Headless Godot: MultiMesh transforms/AABB read back empty:
  test cells/positions, not meshes. Fresh worktree after a new class_name needs `--editor --import`.
- [skip ci] on a PR head leaves no checks: push an empty commit. Painted road lines read as lane markings.

## Tools
- mog.sh: lead 8 scratchpad (b5e2e23e/scratchpad/mog.sh <pr> <full sha>); copy it to your scratchpad.
- Captures: tools/capture/capture_shaders.gd (--shader=today --time=dusk|night|morning|noon); probe cameras in
  arena-edge worktree tests/_probe/edge_shot.gd. override.cfg in the worktree first (separate call).
- Worktrees to remove once merged: arena-edge, river-rise, b2-26, camera-opts, carve-wp7, res4, res16.

Lead = "Kaiju: LEAD". Owns QA gates, merges, DECISIONS/STATUS, director questions, this file.
