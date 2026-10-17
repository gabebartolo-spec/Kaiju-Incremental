# Lighting handoff, 2026-10-18 08:40
## State: awaiting slot (lead's GPU slot for the final breath render, then fresh critic 6)

## Who
Role: lighting, reporting to the lead ("Kaiju: Lead" in ListAgents; message it by name). Rules:
look changes reach the director only via the lead; CI captures one run at a time or the lead's GPU
slot; PRs into claude/look-options; reports <=8 lines. Director asleep since 06:4x: no questions.

## Closed: lighting looks (D-057)
Director picked A, keep concrete. claude/lighting (d2f63dc) stays pushed, not merged.

## Now: PR #38 claude/breath-beam-only (worktree ../Kaiju-Incremental-wt/lighting), head 17ecd14
Lead's calls: remove the legacy voxel jet (defect) AND make the breath read from the game camera.
The lead merges on a fresh motion-critic PASS. Synced with look-options at a3ee004 (sync again
before the final push). Flow floor 114. rampage.gd 399/400 lines: don't add lines there.
Built:
- fx.gd jet removed; flow check "no pale voxel-cube jet" (failed first).
- scenes/breath_beam.gd (pooled): core from the JAW (mouth_of, 0.7 along "jaw"; tracks the jaw
  while lit); flame curtain (breath_curtain.gdshader) on the far arc of the sim's hit cone (from
  ability_fx.cone_origin = the feet, full reach, 36 deg), height fx.breath_curtain_height 7;
  muzzle flash (3.5 u, warm), strike flare, strike light (4 energy, 3.5 u), all driven by one
  progress value, easing in over fx.breath_fade_in 0.12.
- Scorch from the cone origin; soot fades in (FxDecals optional soot_in; fx.scorch_soot_in 0.4).
- capture.yml --fixed-fps for stills; capture_powers --species --signature-only --side;
  tools/capture/probe_breath.gd (headless geometry probe).
- Removed again: the street glow (breath_fan.gdshader); the curtain carries the behind read.
Key measurement: from the game camera the mouth-to-street beam lies inside the body's screen
outline (head top ~42 deg below the horizon, beam 44-51 deg), so the core never shows from behind.
Say so in the PR (the lead asked for that honest note).

## Critic log (scratchpad crit*/; renders scratchpad gpu_*, iso_*)
1 FIX beam inside the back -> jaw anchor. 2 FIX fan invisible behind + frame-1 pop -> curtain +
eased flashes. 3 FIX pale hard-rimmed pool (strike light range) -> small light. 4 5/6, sharp dark
edge: I guessed soot, then the fan, both wrong; layer isolation (all / curtain off / scorch off)
proved it was the curtain's smooth lower sheet -> lower half fades in. 5: 4/6, blocky curtain +
white muzzle flash -> separate tongues, warm smaller flash (17ecd14, not rendered yet).
Known, out of scope: red jagged ground decal pops at the breath (pre-existing; lead logged it as
my follow-up after #38: find the fx_decals crack/scorch spawning at full opacity, 0.1 s fade-in).
White drop at f121 behind: probably the #6 spark burst dying together.

## Next
1. On the slot: write the off-screen override.cfg into the worktree; scratchpad/render_breath.sh
   gpu_behind14 ; render_breath.sh gpu_side14 --side ; delete override.cfg. Isolate layers via
   scratchpad/isolate.sh pattern if anything new appears (prove, don't guess).
2. Fresh motion-critic (same bars), then gh pr edit 38 --body-file scratchpad/pr_body.md (fill
   FINAL_PATHS / FINAL_VERDICT; drop the street-glow lines), sync look-options, push, report.
3. Then the red decal follow-up.
