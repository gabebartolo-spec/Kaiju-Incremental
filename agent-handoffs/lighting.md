# Lighting handoff, 2026-10-18 07:20
## State: awaiting slot (lead's local GPU slot for the breath behind + side clip)

## Who
Role: lighting, reporting to the lead ("Kaiju: Lead" in ListAgents; its pipe address changes on
restart, so message it by name). Rules: look changes reach the director only via the lead (A/B at
the game camera); CI captures one run at a time or the lead's GPU slot; PRs into
claude/look-options; reports <=8 lines. The director is asleep (06:4x): no questions to him.

## Closed: lighting looks (D-057)
Director picked A, keep concrete. claude/lighting (d2f63dc) stays pushed, not merged.

## Now: PR #38 claude/breath-beam-only (worktree ../Kaiju-Incremental-wt/lighting), head f253b6f
Lead's call: the legacy voxel jet goes AND the breath must read from behind at the game camera.
Done:
- fx.gd breath() jet removed; flow check "no pale voxel-cube jet" (failed first); floor 114.
- capture.yml: --fixed-fps for stills (fixed-fps flag only, per the lead).
- scenes/breath_beam.gd (pooled): slim core from the JAW (BreathBeam.mouth_of: 0.7 along the
  "jaw" bone; the old hard-coded mouth was inside the back) to the struck point; a flat
  additive fan (breath_fan.gdshader) on the street over exactly the sim's hit cone: from the feet
  (ability_fx.cone_origin, set by rampage), out to full reach, 36 deg either side (±6.5 u).
  Fade-in fx.breath_fade_in 0.1 s; fx.breath_fan_alpha 1.0; fan albedo 2.6+1.4*power.
- capture_powers.gd --species --signature-only --side; tools/capture/probe_breath.gd (headless:
  prints facing, mouth, beam, fan apex/tip/edges, camera).
- rampage.gd 399 lines (cap 400): don't add lines there.
Measured: from the game camera (kaiju z=70, cam z=89 y=31) the mouth-to-street beam lies inside
the body's screen silhouette (head top ~42 deg, beam 44-51 deg). That is why the fan carries it.
GPU renders so far (scratchpad gpu_side2/gpu_side4): side view good, snout to street. The behind
view showed the fan too small BEFORE the move to the street; not yet rendered since.

## Next
1. On the slot: scratchpad/render_breath.sh gpu_behind5 ; render_breath.sh gpu_side5 --side
   (write the off-screen override.cfg into the worktree first; delete it after; the focus
   guard blocks any command text that names Godot plus a windowed flag without it).
2. Check 2x crops: the fan visible from behind on every breath frame, nothing opaque over the body,
   no pop; peach/white pixel count near the flare level. Tune fan alpha/albedo in data if needed.
3. Fresh motion-critic on the behind + side clips (bars above), then update the PR #38 body
   (scratchpad/pr_body.md is stale: rewrite Evidence and Not exercised) and report to the lead.
Known: the beam stays fixed in the world for 0.9 s while the head moves (side frame 40); a critic
may flag it; a fix would be to re-aim the core at mouth_of each frame.
