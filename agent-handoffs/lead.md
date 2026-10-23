# Lead handoff, 2026-10-23 (lead session "Status check"; auto-compacts, no hand-off, no self-archive)
## Successor: register (empty file named by your CLI session id in ~/.claude/context-guard-leads/), read this, then
## GitHub (open PRs), then docs/ROADMAP.md ("Director comments" chapter, Playtest milestones D-146, Engineering
## upkeep D-159), DECISIONS D-155..D-186, and the lead board (below).

## Director state and rules in force
- He is present. Interviews: D-163..D-170 (scratchpad interview_answers.md) and D-189 (2026-10-23 evening).
- D-177 MOTION FIRST: motion and destruction are the core; every body/movement change passes the motion CI suite at
  all 3 growth steps. Order: gait fix (#175), motion pass, D-165 living predator.
- Game renamed Kaiju Evolution. Three equal visual pillars (beauty, consistency, power fantasy). Bar: "I have to love it".
- D-146: NO per-change director gates; he plays only at milestones M1-M4 (export to Desktop\Kaiju Builds\M<n>, survey
  as a web page). M1 waits for all its items, the music integration included.
- D-186 (amends D-159): builders run locally only the 1-2 suites they iterate on, then push; GitHub runs the rest.
  Lead: fresh builder per task, design + pass bars before code (heli took 6 runs without).
- D-189 ("interview me"): ATMOSPHERE LEAD session local_3dbe2472-68cf-42b3-84fa-657415483355 owns sky and sea life
  (whale), weather looks, rampage escalation (D-154 haze); cap "6 in total" = 2 engine builders per lead session;
  music "Low and creeping", Endless = Colossus track, rampage end fades under the results; helicopters "Never block
  your view" (heliflight camera bar -> camera-to-kaiju corridor). D-191 = its A1-A16 (b049ff06). Slots: its B1 takes
  my turn-weight slot when the clip is done (TELL IT), B2 the VFX lead's returned lent slot (VFX tells it). Journal
  (tools/journal.py, artifact WWrpuzmKwH6GEPr5bMFwa1) current to #175/D-191. At most 3 open PRs.
  Briefs: `bash ~/.claude/tools/engine_slot.sh && timeout ...` (staggers starts; fails while ~/.claude/focus-pause).
- D-187 "Heavier, slower", re-asked after a wrong quote: U-turn Behemoth 2 s, Colossus 3 s (today 1.63/1.80 s,
  young 0.95 unchanged), spread evenly; bar 7 = critic's >= 4 alternating real steps (> 0.3 FL, <= 40 deg); builder
  turn-weight (agent ac71d48ab1a1ff638, claude/turn-weight-d187) design approved: uturn_s 2/3 + 6 steps of 30 deg,
  trapezoid yaw (peak 1.25x mean); no-lunge bar at the feet-centre (kaiju_pos is the tail base, 7/14 u behind the
  feet); FL per step from the VFX lead; smoke StepTurn 90 deg re-pinned per D-187. Then clip + fresh motion critic.
  Hygiene: stale claude/turn-weight ba70e967 on origin. Bars met: U-turn 1.97/2.97 s, peak 1.11x, 34 deg max a step;
  bar 3 = regression guards (feet-centre <= 1.9x, origin <= 3.5x). Real inner steps need turn_slow 0.1 (near stop
  in an about-face): asked him; he said "show me them both. im cautious of the fullstop feeling terrible to play" ->
  one labelled A/B clip (A step round 0.1, B walking arc 0.5; B fails the motion gate's Colossus centre bar 0.63>0.6),
  fresh motion critic, lead's check, then to him. Offer a switchable test build if the clip can't show the feel.
  Pushed 9b425a71 (gait 24/0, motion 30/0, smoke 47/0, city 175/0; StepTurn 90 deg re-pinned 1.55-1.9 s). Rise point
  with the real Behemoth (seeds 7301/1234/98765): base 2/8/8 s, A 4/8/12 (one fails 10 s), B 3.5/9.7/10: tell him
  in the A/B question. CLIP DONE scratchpad tw/turn_ab.mp4 (faab304d; A and B look alike). B fails the motion gate's
  turn-centre-on-a-planted-foot bar (0.63 vs 0.6, older build; rerun 45 s after pause) and sometimes 3 real steps not 4. Music builder waits for a lead slot (turn-weight frees after the clip).
  kaiju_pos sits behind the feet (toe 2.4/4.8/11.6 u ahead young/Behemoth/Colossus). DEFECT: the sim stomp damage
  centres on kaiju_pos (rampage_sim.gd _stomp) while the view draws the ring at the delivering foot (rampage.gd
  _land_stomp), 5-12 u apart. Fix (bug fix under D-166, no ask): stomp centre = the delivering foot's point; check
  claw/breath origins. Next lead sim task after strike-delay (same code).
- Heli fall (VFX, claude/heli-fall) stopped after 2 FIX ("drifts"): lead OK'd air.fall_seconds 2.2 -> 1.4 in that
  branch (agent placeholder; wrecks land ~0.8 s sooner; seeded tips come to the lead). Chutes = view (VFX).
- D-188 "Keep going until critics pass" (no round cap) + "if something has failed 7 times in a row then our method is
  wrong": two failed rounds in a row = stop, find why, change the approach. Rulebook updated, rule-check item 20.
  FL (world units): young 1.235, Behemoth 2.072, Colossus 3.706. D-190 (his picks in the VFX lead's session, quotes
  checked in its transcript; a6bde2e6): "Smooth flames", "Slow chest-and-neck heave", claw "Keep it straight ahead".
- Lead/VFX split: VFX lead owns every visual item end to end; lead owns sim, gameplay, UI flow, tests, merges, docs,
  milestones, sound. Each tells the other before touching the other's files.
- D-171: new heads after the demo (Colossus unlock, evolve-screen picker = lead's UI, post-demo). D-173: wrecks also
  kill perched Taskforce agents. D-166 strike times: breath/ultimate 0.8/1.1/1.4 s, stomp 0.45 s (data). D-175/D-178.
- D-162/D-170: Tripo 6500 credits left for round 2 (serpentine python, albino) + up to 100 for the tail rig test;
  browser only. Downloads by signed URL + curl. Never edit a running bash script in place.
- Music D-184 SHIPPED: his remaster of G2 (798f3c13) = the theme, on the menu over the city sound (amends D-141) and
  the Cover source; cities C1a/C2a/C3a, each Auto split; all in C:/Users/DANTE/Downloads/kaiju_music (WAVs + stems).
  320 of 800 credits, 8 of 20 downloads; G1-G4 not to be downloaded again ("later if we need"). Revisit music later
  (ROADMAP). NEXT: a fresh builder cuts loops + layers (D-125), menu music, LICENSING_REGISTER entry (Suno Pro,
  commercial), checks vocal stems are near silent; when an engine slot frees. Brief ready: scratchpad music_brief.md (3 layers LOW/DRUMS/PEAK).

## Lead board (cross-session sends are capped at 10 between his messages)
- C:/Users/DANTE/Documents/GitHub/Kaiju-Incremental-wt/lead-board/: README.md (protocol), to-<session>.md, from-<session>.md,
  interview.md. Scratchpad board_watch.sh wakes the lead on any from-file or interview change.

## Sessions and builders
- 2026-10-23 director: "merge what they can and archive. i wanna go 1 on 1 with you". VFX + atmosphere leads ARCHIVED
  (nothing SHIP to merge). VFX handoff claude/vfx-lead-2 862f1302 (fire-smooth 4e6e90d9, heli-fall 5aee3cb6, claw-rake
  2d176ff4, living-predator ec4bb919 parked D-193). Atmosphere handoff claude/atmosphere-lead 42a8deaa (atm-escalation
  85e010c6: recapture stills; atm-rain 87fbcff7 WIP). D-193 new pipeline; D-194 Cascadeur Pro trial, test only.
- Builders (subagents, 2 slots): komodo-drift (claude/komodo-test; heavy rises facing the bank, then smoke_step_turn,
  suites, recapture -> critic); serpent round 4 (claude/serpent-slither from 5fc6647d; NEW method after r3 critic FIX
  "rope on a rail": reference-led targets, longer thinner tube stand-in, screen-space bars). Stall watcher on both.
  Tripo session local_2d9f45c9 (tripo-komodo): young Komodo critic+texture, croc "B with A's power", hybrid serpent
  3-stage board (D-206), Komodo palettes (D-205); budget 5000 total (D-204). Parked: heli-standoff 2c0c2688 (handoff heli-standoff.md; camera red =
  director question with episodes), strike-delay (STOPPED; fresh builder from its handoff), sim-leak = PR #176 (needs CI
  + go line; git-helper was stopped by him, so merge yourself via `gh pr merge --squash --match-head-commit`).

## Animation pipeline (D-193..D-196): Cascadeur, director 1-on-1
- Cascadeur Pro trial (D-194, test only; keepers remade under a paid licence). Drive it with Nekki's script server:
  he runs Commands > MCP.Start script server; `python -I C:/Users/DANTE/cascadeur_bridge/cs.py job.py` POSTs to
  127.0.0.1:8765/run (D-195 "Yes, use theirs"). Apply AutoPhysics = his click on "All Frames" (D-195); tell him first.
  Reuse ONE scene (8 scene tabs crashed it); save to NEW file names (overwriting kept the old file twice).
- Croc: legs re-rigged to the mesh (forward knee 4.25 m, hock 2.2 m; croc/v2/build_v2.py LEG_JOINTS). The GAME rig
  reptilian_adolescent.rig.json bends only at the hock: fix it when the walk comes in ("Yes, fix the game's croc leg
  rig as part of bringing the Cascadeur walk into the game").
- Komodo (D-196, full Komodo, upright, 1000 credits; 130 spent, 16,775 left): ref 96294df9 (drool kept: "its
  anatomically correct"), Smart Mesh f46b0c87 variant e73da3cf, texture 6a8a224e; rig komodo/build_komodo.py (joints
  from leg_profile.py cross-sections), Cascadeur komodo/rig/komodo_rig_v3.casc; walk croc/work/walk_keys_k.py (64 f,
  2 m steps, crouch 25 cm, own leg IK, 0 cm slide) -> AutoPhysics applied -> komodo_walk_v4_ap.casc + _joints.fbx;
  walk/idle/roar/turn done and imported on claude/komodo-test (fit() OK). D-197..D-207 logged (family, skins,
  hybrid serpent cobra->rattle->constrictor, Kaiju Creation new-game opening IN THE DEMO).

## Base and PRs
- Base = origin/claude/look-options; squash-only.
- Merged 2026-10-23: #166 3e4a7665, #170 volley e4100548, #172 night fog 4f8b8d10, #173 gait sim ede35b92, #174
  pacing-ci f68caea1 (and overnight #159-#169).
- Open: #171 beam-cost GREEN b2e8e759: go only when pacing run 39910488328 reports a last unlock of 2.15-2.35 h.
  #175 gait-fix head 681ce75c (capture route only changed), CI running: go after the VFX lead's SHIP + evidence
  (clips + motion critic) and the lead's own check; gate green at 681ce75c (motion 30/0, smoke 47/0, clips 14/0,
  gait 10/0). Motion critic FIX: Behemoth/Colossus turn ~270 deg/s on planted feet (the swivel); VFX builder measures
  sim vs view. If the sim turn rate is the cause: lead's file, steering feel = director question with the numbers.
- Not opened: claude/strike-delay (red, diagnosing), heli-look-r4 (VFX), claude/sim-speed daad0710 (measurement only:
  Convoy body polygon ~25%, bucketed building scans ~10%; sim/convoy.gd at 400 lines, split first).
- Pacing on GitHub (#174): push pacing-run/<name> with .github/pacing-run.json {"species","runs","verbose"}.

## Next queue (each brief names its ROADMAP item + decision)
- Next free slot: Kaiju Creation opening (D-207, demo): lab dish, croc genome (others locked), KAIJU juice VFX,
  zoom to black + egg crack, then the river rise. Ask him the lab's look with labelled images first.
- When a lead slot frees: music integration (D-184), then sky and sea life with the whale in the river (D-168;
  demo-end handoff plan), damage on impact (D-166, after strike-delay), sim speed-ups (D-159), Taskforce adult units.
- Heli-standoff: push -> git-helper opens the PR -> non-author sim review -> go; send the sha to the VFX lead (D-183).
- Hygiene: scratchpad hygiene_manifest.md (dead worktrees vs cap 12, backups first). His to remove (a peer's delete
  was denied, so not ours): local scratch/gait-merge (volley worktree) and gw-scratch (agent-a0c3ef106ae9686d7).

## Tools
- Lead docs worktree Kaiju-Incremental-wt/lead-docs (detach at origin/claude/look-options; python edits newline='';
  commit [skip ci]; push HEAD:claude/look-options; rebase on reject). DECISIONS.md cap 400 (scratchpad add_d186.py).
- Suno: built-in browser (he is signed in); downloads via page JS fetch /a/api/download/clip/<id>?format=wav with
  Bearer __session cookie -> signed URL -> curl. Stems: Edit > Get Stems > Auto split (50 credits; CAPTCHA is his).
- ElevenLabs: creative flow tools; set duration_seconds on the node before running. Measure takes with sfx_measure.py.
- ffmpeg: C:/Users/DANTE/AppData/Roaming/Python/Python314/site-packages/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe

## Findings
- 2026-10-23: 14 engine jobs on 16 threads held the CPU at 100%; frame-time numbers taken then are noise.
- A CI watcher must require every expected check before calling a head green (it once read green before shards ran).
- Seed-sensitive checks: probe the unit, fix behaviour or re-pin, never the threshold (D-144).
- git-helper once misread go.txt and claimed a go; only the lead writes go.txt.

Lead = "Kaiju: LEAD 10". Owns routing, merges, DECISIONS/DESIGN/STATUS, director questions, milestones, this file.
