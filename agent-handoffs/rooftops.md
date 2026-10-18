# Rooftops handoff, 2026-10-18 (D-076 / D-076a rooftop density)
## State: awaiting #50 merge (LEAD pings) + capture.yml slot (after the croc P3 chain)

## Who
Session "Rooftop density", started by "Kaiju: Lead" (local_106fc100-d2a4-4091-bc9a-4bda31df13ac).
Worktree .claude/worktrees/festive-jemison-3fb73c. Report to LEAD (SendMessage, <= 8 lines).

## Task
Director D-076 "more squads, more often", made visible. LEAD's balance call D-076a: tanks
unchanged; rifle chip scaled down per tier so each stage's total damage per run holds within ±5%;
reptilian pacing within ±5%. No HUD change (UI's area, D-061): the hit read is flash + tracer +
hide spark. PR into claude/look-options after #50 merges, synced; do not merge.

## Branches
- claude/rooftop-density (PR branch, pushed), off look-options 0817cf6. Not yet synced: needs
  look-options with #50 (+ #53 rifle gap, already on look-options).
- claude/rooftops-capture (pushed, 34854a5) = PR branch (at 7000a1f) + #50 head a0d3f36 + #53.
  Used for gate, suites and the clip. Delete after the PR merges.

## What the PR branch changes
- sim/army.gd: rifle reach = range + sim.stomp_radius() (as tanks); Army.volleys counter.
- data/tuning.json army.rooftop: chance 0.3 -> 0.8, max_by_tier [6,10,14,18] -> [20,48,48,60],
  fire_interval 2.0 -> 0.8, damage_by_tier [0.3,0.5,0.8,1.2] -> [0.03,0.04,0.08,0.12].
- scenes/rooftop_view.gd: _nearest_first (draw the squads nearest the kaiju, cap max_drawn 36).
- tools/capture/capture_rooftops.gd: stand search uses edge reach; --typical (median busy spot).
- tests/lib/sim_rooftops.gd: edge-reach check + Behemoth density check (>= 1.0 volleys/s);
  both shown failing first. tests/expected_checks.txt sim 50 -> 52.

## Evidence (notes folder rooftops-density/, side-session-notes/local_106fc100...)
- Root cause: from the centre, the kaiju's own reach killed squads before they had it in range
  (Behemoth in range 3% of the run, Colossus/Apex 0%). replay1-3, life1.txt.
- Baseline = #50 head a0d3f36: pacing 0.60 h / 4.53 h (pacing_b2.txt).
- Same 28 replayed states, totals -1.0/+1.9/+1.2/+0.1% (replay_b2_base/cand.txt).
  Pacing after 0.60 h / 4.44 h (-2.0%) (pacing_b2c.txt). Behemoth volleys/run 5.9 -> 110.
- Effect fixture on #50 head: hp halfway 239.8 vs 242.0, biomass 344 vs 326, 1.55 volleys/s.
- Hit gate (capture branch): 225/225 inside, exit 0; known-bad +2.5 u: 58/225, exit 1.
- Suites on capture branch: all 10 pass (suites_capture_branch.txt). gdlint/gdformat clean.
- PR body: scratchpad pr_body.md (copy: notes pr_body_draft.md). Placeholders left: CLIP,
  CROPS, SPARKGAIN, AUDIO.

## Next
1. When LEAD says #50 merged: merge origin/claude/look-options into claude/rooftop-density
   (floors: keep the max of each), check sim/ + data/ match a0d3f36's (else re-run replay +
   pacing via scratchpad snapshots), run tools/run_tests.sh, push, open the PR with pr_body.md.
2. Clip: only after the croc P3 chain is done and nothing is in_progress on capture.yml:
   tools/capture/ci_capture.sh --movie --renderer=gl_compatibility --fps=60
   --resolution=1280x720 --ref=<synced branch> capture_rooftops.gd -- --typical
   --out=<notes>/rooftops-density/clip. Keep the full 6 s, with audio. Then spark_gain.py and
   2x crops of three hide sparks; fill the placeholders; send to LEAD (it runs the critic).
3. After P3 merges (baby speed 0.6, hp 1.15): sync again, re-check the per-stage totals.

## Scratchpad (%TEMP%/claude/C--...festive-jemison-3fb73c/ff78c0a3.../scratchpad)
snap_b2 (#50 head + tools/pacing_dmg.gd, roof_replay.gd), snap_b2c (same + my sim/tuning),
dump_b2.json. Replay: cd snap_x; APPDATA=<appdata_x> DUMP=<dump> CANDS='[{}]' godot --headless
--path . --script tools/roof_replay.gd

## Don't touch
scenes/biped_swing.gd, scenes/gait_clip.gd, scenes/city_ground.gd, scenes/ui_kit.gd,
scenes/rampage_hud.gd (LEAD: no HUD change in this PR).
