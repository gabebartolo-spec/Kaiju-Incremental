# Rooftops handoff, 2026-10-18 (D-076 / D-076a rooftop density)
## State: awaiting lead (round 2 proof sent: notes round2/PROOF_round2.md; rifle loudness call open)

## Who
Session "Rooftop density", started by "Kaiju: Lead" (local_106fc100-d2a4-4091-bc9a-4bda31df13ac).
Worktree .claude/worktrees/festive-jemison-3fb73c. Report to LEAD (SendMessage, <= 8 lines).

## Task
Director D-076 "more squads, more often", made visible; director (here): "shooters arent firing in
unison ... improvised, unrehearsed resistance". LEAD D-076a: tanks unchanged; rifle chip scaled per
tier so each stage's damage per run holds within ±5%; reptilian pacing within ±5%. No HUD change
(D-061): hit read = flash + tracer + hide spark. PR #63 into claude/look-options; do not merge.

## PR #63 (claude/rooftop-density), head dc957e1, synced with look-options a7bb4d9 (docs only new)
- sim/army.gd: reach = range + stomp_radius(); next shot = interval × (1 ± jitter) on
  Seeds.derive(rng, 0x2008); Army.volleys.
- tuning army.rooftop: chance 1.0, max [30,96,96,120], interval 0.8, interval_jitter 0.5, range 24,
  chip [0.01,0.012,0.03,0.05]. sfx rifle -6 dB, gain_jitter_db {rifle: 3}.
- scenes/rooftop_view.gd (at its 400-line cap): nearest-first, hide looming (> 4% screen) squads but
  keep their spark, 2-14 frame ragged men, 3-piece fading tracer, PARAPET_IN 2, spark 6 f x1.35.
- scenes/rooftop_aim.gd (new): random of 3 nearest upper bones, 20-80% along.
- scenes/sfx.gd gain jitter; tests/lib/flow_rifle_sounds.gd fix (#53's check).
- capture_rooftops.gd: edge-reach stand, --typical, --rifle-ab=A,B, in_reach_per_second log.
- tests/lib/sim_rooftops.gd: edge reach, Behemoth density >= 1.0/s, ragged gaps (all failed first).
  Floor sim 53. Suites all pass on 9cff149.

## Evidence so far (notes rooftops-density/, round2/)
- Replay vs look-options af7eb05, 28 states (replay_lo_base.txt / replay_chip3.txt row x|0):
  totals -0.8/+2.6/+2.7/+0.2%. Behemoth volleys/run 5.3 -> 409, in reach while any 5.3, 3+ 52%.
- Base pacing af7eb05: 0.59 h / 4.56 h (pacing_lo.txt). Candidate: b0jeyrx8u -> pacing_lo_c.txt.
- Gate 452/452 exit 0; known-bad 73/453 exit 1 (round2/gate*.log). Sim packet posted on #63.
- Headless dry run --typical: in reach per second [7 x9, then 1 x3] (6 squads die ~9 s), 71 volleys.
  So the -6 dB half is quieter partly from fewer shots: compare per-onset peaks, not only LUFS.

## Now
- Round 2 proof rendered LOCALLY (the director allowed it; LEAD dropped the baton: up to 4 windowed
  renders). round2/local_clip (6 s, -6 dB) and local_ab (12 s, -2 then -6 dB) + crops + reports.
  The CI run 39109733215 timed out (llvmpipe).
- Audio finding: the rifle sits 2-5 dB under the kaiju's own stomp bed; -2 vs -6 makes no
  measurable difference. The 0.3 s sfx gap gives a 0.30-0.33 s crack rhythm. Waiting on LEAD:
  louder or brighter sample / 0 to +3 dB / jittered gap.
- Pacing posted on #63: evolve1 0%, tree -4.4%, totals +0.4/-0.3/+3.6/-0.5%. PR body is
  complete (no placeholders left).
- To LEAD (not mine): city_view.gd:208 normalize errors + 171 collapse sounds at a mass collapse.
Later: re-sync after P3 and #50 land; re-check the totals. #36's 130-run check runs on my head.
Tools: scratchpad clip_report.py, rifle_level.py (needs an SND log from a temporary print in
the capture; restore the file afterwards).

## Scratchpad (%TEMP%/claude/C--...festive-jemison-3fb73c/ff78c0a3.../scratchpad)
snap_lo (af7eb05 base), snap_lo_c (9cff149), dump_lo.json, pr_body.md, clip_report.py.
Replay: cd snap_x; APPDATA=<appdata_x> DUMP=<dump> CANDS='[{}]' godot --headless --path .
--script tools/roof_replay.gd

## Rules
Kill Godot by PID only. Windowed runs need override.cfg written in a separate call first. Never
git stash; stage by name. Don't touch scenes/rampage_hud.gd (no HUD change).
