# Lighting handoff, 2026-10-18 09:25
## State: available (#38 and #47 merged; no open work)

## Who
Role: lighting, reporting to the lead ("Kaiju: Lead" in ListAgents; message it by name). Rules:
look changes reach the director only via the lead; CI captures one run at a time or the lead's GPU
slot; PRs into claude/look-options; reports <=8 lines. Director asleep since 06:4x: no questions.

## Closed
- Lighting looks (D-057): director kept concrete; claude/lighting (d2f63dc) pushed, not merged.
- PR #38 MERGED (907adfb -> f71c527): breath voxel jet removed; breath reads from the game camera
  (jaw core, flame curtain on the hit cone's far arc, eased flashes). Taste notes for the director
  are in the PR body. The lead added the layer-isolation method to the art-qa-critic learnings.

## Now: nothing open
- PR #47 MERGED (a4b3ef2): breath scorch cracks glow in (fx.scorch_glow_in 0.12); found with
  tools/capture/probe_decals.gd + a scorch-off render; fresh critic PASS.
- Worktree ../Kaiju-Incremental-wt/lighting removed; remote claude/breath-before deleted.
- Next session: ask the lead for a job (lighting/FX). Start a fresh worktree per task.

## Tools left for later sessions
- scratchpad scripts are session-local; the repo keeps tools/capture/probe_breath.gd,
  probe_decals.gd and capture_powers.gd --species --signature-only --side.
- Local GPU render: off-screen no_focus override.cfg in the worktree, one Godot, delete after;
  the focus guard blocks command text naming Godot plus a windowed flag without it.
