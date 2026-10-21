# Rooftops handoff, 2026-10-18 (D-076 / D-076a rooftop density)
## State: running a check (PR #86 legs/tail hits open; CI clip b13ev6vis queued behind green-lots)

## Who
Session "Rooftop density", started by "Kaiju: Lead" (local_106fc100-d2a4-4091-bc9a-4bda31df13ac).
Worktree .claude/worktrees/festive-jemison-3fb73c. Report to LEAD (SendMessage, <= 8 lines).

## Task
Director D-076 "more squads, more often", made visible; director (here): "shooters arent firing in
unison ... improvised, unrehearsed resistance". LEAD D-076a: tanks unchanged; rifle chip scaled per
tier so each stage's damage per run holds within ±5%; reptilian pacing within ±5%. No HUD change
(D-061): hit read = flash + tracer + hide spark. PR #63 into claude/look-options; LEAD merges.

## Now: #86 claude/rooftop-hits-body (post-demo, LEAD 2026-10-19)
- RooftopAim TARGETS + legs/tail (13 bones, NEAREST 5); capture logs body_x_px. Headless span
  292/296 px = 99% (bar >= 60%), top 20 px bin 15% (bar <= 25%). Gate 561/561; known-bad 174/564.
  Suites all 9 pass (54e94f8).
- Clip: local windowed blocked (director in League fullscreen); CI job b13ev6vis waits for the
  capture.yml queue, then downloads to notes round4/ci. Then: span.py on it, 2x strip, fill the
  PR body's Clip line (gh pr edit 86), ping LEAD.
- #80 and #83 MERGED (5d1a892). Defeat rise -> full-game retune list (LEAD).

## Playtest fixes (D-083, director playtest, LEAD); proof notes PLAYTEST_FIXES.md, breath-snout/
- #80 claude/rifle-fire a06b6d9: near squads (12 u) crack, the rest rifle_far pops (-14 dB,
  pitch 0.7); gaps 0.25 s +60% / 0.5 s +80%; pitch ±10%. LEAD PASS on numbers.
- #83 claude/breath-aim 70e3de9: sim/breath_cone.gd (BreathCone.of) = the cone from the SNOUT
  (city.breath_snout_ahead [10.4,10.4,10.3,13.5] x body_scale ahead of kaiju_pos, the tail root);
  sim burns it, beam/scorch aim from event "from", BreathAim (scenes/breath_aim.gd) draws it while
  ready. Flow check (mismatch 0; known-bad tail-root 12.24 u fails). Floor flow 153.
  Pacing 130 runs: evolve1 0.26 -> 0.27 h; defeats up (Beh 6 -> 17, Col 31 -> 39): LEAD's call.
- If croc-contact-dash (local_1feb30ca) moves kaiju_pos to the body centre: re-measure the snout
  offsets (probe: KaijuModel per stage, KaijuRig.tail_world("head1"), forward is -Z).
- #63 MERGED. Legs/tail hit WIP stays local on claude/rooftop-density (ea54ca5), post-demo.

## Branch and commit
- claude/rooftop-density. origin = 65e96f4 (synced with look-options 57617b0: #54 #36 #59 #66 in).
  LEAD merges 65e96f4 on green CI.
- Local only, NOT pushed: ea54ca5 (round 4 WIP below) and this handoff rewrite.

## What #63 changes (at 65e96f4)
- sim/army.gd: reach = range + stomp_radius(); next shot = interval × (1 ± interval_jitter) on
  Seeds.derive(rng, 0x2008); Army.volleys.
- tuning army.rooftop: chance 1.0, max [30,96,96,120], interval 0.8, jitter 0.5, range 24,
  chip [0.01,0.012,0.03,0.05]. sfx: rifle +2 dB, gain_jitter_db {rifle: 3}, min_interval rifle 0.1,
  start_s {rifle: 0.13} (rifle.ogg has ~140 ms silent lead-in).
- scenes/rooftop_aim.gd: hit = shown voxel of a trunk/head bone facing the shooter (24 draws).
- scenes/rooftop_view.gd (381 lines): nearest-first, looming squads hidden but spark kept, ragged
  men 2-14 frames, fading tracer, figures clamped to their own roof level (_roof), PARAPET_IN 2.
- scenes/sfx.gd: gain jitter + start offset from tuning. flow_rifle_sounds.gd fix (#53's check).
- capture_rooftops.gd: open-spot --typical (CLEAR 5, sight line, MIN_SEEN 5), --rifle-ab=A,B,...,
  in_reach_per_second. tests/lib/sim_rooftops.gd: edge reach, density, ragged gaps.
- Floors = real counts: sim 53, growth 31, flow 148 (LEAD merged look-options 329e708, #66, at 65e96f4).

## Evidence (notes side-session-notes/local_106fc100.../rooftops-density/)
- Replay vs af7eb05: totals -0.8/+2.6/+2.7/+0.2%. Pacing: evolve1 0%, tree -4.4% (before #36).
- round3/PROOF_round3.md: plaza spot, gate 553/553 (known-bad 162/557 exit 1), audio crack +2.7 dB
  over a stomp alone, -18.8 LUFS, -2.7 dBTP (LEAD ACCEPTED the audio).

## Unfinished changes (POST-DEMO, LEAD: no hits on tail or legs yet; local WIP ea54ca5, unverified)
- Bar: on-screen sparks span >= 60% of the kaiju's screen width; no 20 px x-bin > 25%; hits over
  torso, flanks, tail and legs, never in the air or in shadow. clip2 at 1d874df: 47% span, ~25% bin.
- WIP: RooftopAim TARGETS + leg_l0/l1, leg_r0/r1, tail0-3, NEAREST 5; capture logs body_x_px.
- Post-demo, when LEAD assigns it and Godot is allowed: headless --import first (FallMotion from #66 failed to parse
  without it); headless --typical run + scratchpad/span.py; gate + known-bad; render the 6 s clip
  (override.cfg, separate call; remove after); 4 stills; trimmed mp4 (first 5 frames); suites
  (GODOT=<console exe> tools/run_tests.sh); new branch off look-options after #63 merges (ea54ca5 is local only).

## Attempts
- CI capture.yml (llvmpipe) timed out at 50 min for 12 s at 720p60: render locally instead.
- In-mix stomp peaks are contaminated by overlapping rifles: measure the stomp with rifles
  muted (--rifle-ab=-80,...).
- A Movie Maker clip at --resolution 1280x720 still came out 1920x1080, so spark coordinates are
  in 1920 space.

## Open decisions
- Re-measure the ±5% totals after #36 (army learns inside a stage)? LEAD's call.
- Post-demo (LEAD): recoil, lulls between bursts.

## Running jobs
None. Background watcher bj4wt7h0y (waits for PR 50 to close) may still be polling gh.

## Rules
Kill Godot by PID only. Never git stash; stage by name. Don't touch scenes/rampage_hud.gd.
