# Lighting handoff, 2026-10-18 09:15
## State: awaiting lead (PR claude/decal-fade-in open; lead merges on green; then available)

## Who
Role: lighting, reporting to the lead ("Kaiju: Lead" in ListAgents; message it by name). Rules:
look changes reach the director only via the lead; CI captures one run at a time or the lead's GPU
slot; PRs into claude/look-options; reports <=8 lines. Director asleep since 06:4x: no questions.

## Closed
- Lighting looks (D-057): director kept concrete; claude/lighting (d2f63dc) pushed, not merged.
- PR #38 MERGED (907adfb -> f71c527): breath voxel jet removed; breath reads from the game camera
  (jaw core, flame curtain on the hit cone's far arc, eased flashes). Taste notes for the director
  are in the PR body. The lead added the layer-isolation method to the art-qa-critic learnings.

## Now: claude/decal-fade-in (worktree ../Kaiju-Incremental-wt/lighting), off look-options f71c527
The red jagged mark that popped beside the kaiju on the breath's first frame = the breath scorch
decal's emission (molten crack lines) at full energy 4.8 on frame one (pre-existing since #6).
Proof: tools/capture/probe_decals.gd (headless) lists the only nodes new on that frame (spark
burst + scorch decal); scorch-off render removes it (docs/captures/2026-10-18-breath/
scorch_glow_isolation.png). Fix: optional "glow_in" on FxDecals.spawn; fx.scorch_glow_in 0.12.
Flow check (tests/lib/flow_breath.gd track_scorch_glow) failed first (4.81 of 4.81), floor 117.
Fresh critic PASS: chevron pixels 0, 28, 148, 241, 309, 363, 387 over f91-97 (was 0 -> 383 in one
frame); cools as before; no regression (whole-frame diff 0.09-0.22). Board:
docs/captures/2026-10-18-breath/scorch_glow_before_after.png. #46 also raises flow from 116:
whichever merges second resyncs.

## Next
1. After the merge: remove this worktree (git worktree remove ../Kaiju-Incremental-wt/lighting),
   delete remote claude/breath-before (mine, from #38's BEFORE clip).
2. Available: ask the lead for the next job.

## Tools left for later sessions
- scratchpad scripts are session-local; the repo keeps tools/capture/probe_breath.gd,
  probe_decals.gd and capture_powers.gd --species --signature-only --side.
- Local GPU render: off-screen no_focus override.cfg in the worktree, one Godot, delete after;
  the focus guard blocks command text naming Godot plus a windowed flag without it.
