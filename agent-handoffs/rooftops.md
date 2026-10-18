# Rooftops handoff, 2026-10-18 (D-076 / D-076a rooftop density)
## State: running a check (pacing b0jeyrx8u) + awaiting CI capture baton from croc #54

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

## Now (LEAD 2026-10-18 ~06:40 UTC: #50 in rework, don't wait; this PR goes first)
- PR #63 https://github.com/gabebartolo-spec/Kaiju-Incremental/pull/63, head 92bb053 = synced
  with look-options af7eb05 (#56 #51 #57 #62 #53 in). Suites all 9 pass (suites_synced.txt).
  Auto-fix on. Tables in the body are #50-head numbers, labelled; replace with look-options ones.
- bvrm2j6wy: snap_lo (af7eb05) base pacing -> dump_lo.json -> replay base + cand (snap_lo_c =
  92bb053) -> cand pacing. Outputs scratchpad pacing_lo.txt, replay_lo_*.txt, pacing_lo_c.txt.
- bibqqy81q: waits for capture.yml empty, then dispatches the clip on claude/rooftop-density.
- Then: hit gate + known-bad on the synced branch; spark_gain.py + three 2x crops; PR update.
If #50 lands first: re-sync floors once.
## Critic round 1 FAILED (LEAD relay): one sniper, sparks on one pixel, metronome, no rifle audio
Fixed in 17e3570/9cff149 (suites all 9 pass):
- army.rooftop range 24, chance 1.0, max [30,96,96,120], chip [0.01,0.012,0.03,0.05]. Replay vs
  look-options af7eb05 (replay_lo_base.txt / replay_chip3.txt): -0.8/+2.6/+2.7/+0.2%. Behemoth
  squads in reach while any 5.3 (was 1.9), >=3 52% of run, 7.5 volleys/s in range.
- scenes/rooftop_aim.gd (new, RooftopAim): random of 3 nearest bones, 20-80% along. Gate
  452/452, known-bad 73/453 exit 1 (notes round2/).
- Sparks 6 frames x1.5; tracer 3-piece fading trail; PARAPET_IN 2 voxels.
- sfx: rifle -12 -> -2 dB, gain_jitter_db {rifle: 3}. Rifle was played but buried.
LEAD 2026-10-18: local GPU BLOCKED (director gaming). Renders on CI capture.yml, baton order
stadium -> croc -> ME -> greenery (local_9af27a16...) -> #50 (local_5325ef73...); croc hands to me.
Rifle now -6 dB (4780aae); capture --rifle-ab=-2,-6 renders 12 s (6 s each) for the loudness A/B:
report integrated loudness + peak per half; keep -6 unless -2 needed. Sim packet posted on #63.
CI dispatch: tools/capture/ci_capture.sh --movie --renderer=gl_compatibility --fps=60
--resolution=1280x720 --ref=claude/rooftop-density capture_rooftops.gd -- --typical --rifle-ab=-2,-6
--out=<notes>/rooftops-density/round2/clip ; when done pass the baton to greenery.
OLD NEXT: render on GPU turn (override.cfg, --typical, out notes round2/clip), then spark_gain, gap
list, audio onset list (ffmpeg -> wav, rms flux), squads-in-reach probe, 2x crops; send LEAD;
pass slot to croc #54 (local_bce75838...) -> #50 (local_5325ef73...). Then update PR body tables.
## Since PR open (head 51a2d5d)
- f731cbe: rooftop_view hides squads whose figure would stand > 4% of screen (near-camera giants
  found in my local clip, zoom_near_tower_0096.png). File at its 400-line cap.
- 51a2d5d: DIRECTOR (in this session): "make sure that shooters arent firing in unison, should give
  the impression of an improvised, unrehearsed resistance". Sim: interval_jitter 0.5 (own stream
  Seeds.derive(rng, 0x2008), mean unchanged); view: rifles 2..14 frames ragged. Sim check (floor 53)
  failed first with jitter 0. Fixed #53's flow_rifle_sounds check (gap left open by live volleys +
  counted all sounds). Sound session gone; LEAD told.
- First local clip (pre-fix): clip/. Re-render clip2/ at fa3ba10 code: 14 volleys, ragged gaps
  3..63 frames, 41 sparks all peak >= 0.89 (gain med 0.76), crops 0096 before/after + 3 sparks.
  Sent to LEAD. GPU slot passed to greenery with LEAD's queue (stadium, croc #54, #50).
- fa3ba10: hidden (looming / past max_drawn) squads still spark on the hide (LEAD); sim 53, flow 138.
- After re-measure: replace the PR's balance section (base pacing_lo.txt vs pacing_lo_c.txt,
  replay_lo_base/cand.txt), mention interval_jitter, the looming rule and the flow_rifle_sounds fix.
- Base pacing on af7eb05: 0.59 h / 4.56 h; totals 183.3/200.7/475.0/690.2 (pacing_lo.txt).

## Older plan (superseded where it conflicts)
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
