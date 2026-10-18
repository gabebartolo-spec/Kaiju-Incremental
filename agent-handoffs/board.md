# Handoff: board (this session: "Kaiju: Load, smoke FX, builds")

Updated: 2026-10-19 04:40
State: paused (director). Both review fixes pushed; CI on them not yet read.

## Done
- #77 frame cap: merged. #81 less camera smoke: merged (eb9a86e). #92 Graphics setting: merged (41d452f).

## #84 faster run load (claude/faster-run-load, worktree run-load, head 6d8e33a)
- Synced onto look-options after #81. The lead's review item (prune the static _baked cache) is DONE:
  - BuildingView.begin_city() runs in BuildingStream._ready, end_city() in _exit_tree.
  - Each entry is [voxels, mesher, generation]; end_city drops entries the current city did not use.
- The new check _check_bake_pruned failed first on CI at 46383f6 (336 kept, [109, 273]); load floor 15.
- PR body updated, including that #89 croc-contact only reads voxels and meshes (Ruin.build, lift_piece).
- NEXT: read the CI tests run on 6d8e33a; if green, tell the lead.

## #82 sound gate (claude/sfx-load-gate, worktree sfx-gate, head cfcbb15)
- The gate moved to scenes/sfx_gate.gd (SfxGate), because sfx.gd hit the 400-line cap. SfxGate reads its own tuning.
- The lead's review item (timeout) is DONE: start_gate.max_wait_s = 3.0 after the first drawn frame.
- The new check FlowSfx.gate_timeout failed first on CI at d86e936 (10.0 s); flow floor 157.
- The flow_sfx bus check now skips the SfxGate child; its crash was a bug from the move.
- Pause during the load does not skew the timing: the gate is pausable and adds per-frame delta only.
- PR body updated.
- NEXT: read the CI tests run on cfcbb15. If the flow count is short of 157, set the floor to the real count.

## Rules in force
- No local Godot (headless included) while the director plays; proof on CI (capture.yml, gl_compatibility).
- Never rebase or force-push; merge look-options and resolve floors to the real counts.
- Lead session: local_106fc100-d2a4-4091-bc9a-4bda31df13ac ("Kaiju: LEAD"). Send SHAs there.

## Worktrees
Live: run-load, sfx-gate, demo-smoke (handoff), integ-a and integ-a-export (lead: keep).
Prune when merged: smoke, graphics, fps-cap.
