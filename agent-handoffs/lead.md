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
- Lead/VFX split (D-189) suspended while the VFX lead is archived: the lead owns visuals too.
- D-171: new heads after the demo (Colossus unlock, evolve-screen picker = lead's UI, post-demo). D-173: wrecks also
  kill perched Taskforce agents. D-166 strike times: breath/ultimate 0.8/1.1/1.4 s, stomp 0.45 s (data). D-175/D-178.
- Tripo: browser only, signed URL + curl downloads; budget D-204+D-213 (10,000 total; caps serpent 850, croc 600). Never edit a running bash script.
- Music D-184 SHIPPED: his remaster of G2 (798f3c13) = the theme, on the menu over the city sound (amends D-141) and
  the Cover source; cities C1a/C2a/C3a, each Auto split; all in C:/Users/DANTE/Downloads/kaiju_music (WAVs + stems).
  320 of 800 credits, 8 of 20 downloads; G1-G4 not to be downloaded again ("later if we need"). Revisit music later
  (ROADMAP). NEXT: a fresh builder cuts loops + layers (D-125), menu music, LICENSING_REGISTER entry (Suno Pro,
  commercial), checks vocal stems are near silent; when an engine slot frees. Brief ready: scratchpad music_brief.md (3 layers LOW/DRUMS/PEAK).

## Lead board (cross-session sends are capped at 10 between his messages)
- C:/Users/DANTE/Documents/GitHub/Kaiju-Incremental-wt/lead-board/: README.md (protocol), to-<session>.md, from-<session>.md,
  interview.md. Scratchpad board_watch.sh wakes the lead on any from-file or interview change.

## Sessions and builders
- 1-on-1 since 10-23 (VFX/atmosphere leads archived). 2026-10-24 (director AFK): komodo-carve2 claude/komodo-test MET D-208 bar (90.9%/0/0; baked clip tracks), perf probe
  + recapture pending. Serpent motion r8 SHIP (claude/serpent-slither b022be85); show him clip + size stills A/B/C,
  ask haze + shadow preset (90 m/8192; blur 1.5->0.5 in city_environment.gd). Skins: A/C/D SHIP, skins-r7 on B/E/F
  (E re-masked: ref orange was soil). Croc adult touchup adult2/touchup/ (tail restored, teeth, scutes v2 FAILED ->
  scutes v3-v6 all critic-FIX; critics misread D-108 'not godzilla shaped' (body, not plates): board
  croc_new/models/adult2/touchup/croc_scute_options.png (A tall v3 / B mid v5 / C tiles v6) = his taste call). Serpent set + mecha
  board accepted. 10-24 interview (06a3b5bc): D-217 mecha "B Lab-white" (tripo-komodo 3D, cap 400); D-218 serpent
  size "A Today" + fix the hood from above (builder claude/serpent-hood); D-219 he HATES the fat adult croc: remake
  "Teen's build, grown up" (tripo-komodo, chest/length <= 0.28, cap 800), plates re-asked on the new body. Still to
  ask on return: haze A/B + shadow A/B (cascadeur_bridge/look_boards/, lead-checked; heli dropped: today = D-183), teen size, croc plates on adult3 (a3174b0f SHIP, sent). Skins D-220 (C+D, blue
  via Tripo text). AFK "dont chase minute improvements": casc-anim idle, script server down (his click). On return
  send casc-anim: teen idle v3 FIX (breath 56-60 f, >=14 px; snort bell 5 in/5 out, chin clears chest; glance 10-12 f;
  hand off the foot f70-105; head +6 deg, mouth ajar), teen walk v9 body (speed <=1.4x, plant drop, forearms).
  Turn v14 FIX again (near hand on the fold 0-2 px, near foot skates 56 px vs maker's '4 cm', dead stop f198):
  D-188 METHOD CHANGE before v15 (pin the foot with Cascadeur's fixed-point/IK, measure on render, not bones). #177 merged (exports now ship .kclip). casc-anim (D-214/D-216 Cascadeur stays; bridge Quick Rig
  works): adult idle body SHIP (tongue prop pending), turn v12 FIX (near hand), teen walk v7 FIX tail, teen idle v3.
  Sessions waiting on him: tripo-komodo (asked him directly), casc-anim (a prompt). Budget 10,000 (D-204, D-213). Parked: heli-standoff 2c0c2688 (handoff heli-standoff.md; camera red =
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
- Open: #171 beam-cost GREEN b2e8e759: go only when pacing run 39910488328 reports a last unlock of 2.15-2.35 h.
  #175 gait-fix head 681ce75c (capture route only changed), CI running: go after the VFX lead's SHIP + evidence
  (clips + motion critic) and the lead's own check; gate green at 681ce75c (motion 30/0, smoke 47/0, clips 14/0,
  gait 10/0). Motion critic FIX: Behemoth/Colossus turn ~270 deg/s on planted feet (the swivel); VFX builder measures
  sim vs view. If the sim turn rate is the cause: lead's file, steering feel = director question with the numbers.
- Not opened: claude/strike-delay (red, diagnosing), heli-look-r4 (VFX), claude/sim-speed daad0710 (measurement only:
  Convoy body polygon ~25%, bucketed building scans ~10%; sim/convoy.gd at 400 lines, split first).

## Next queue (each brief names its ROADMAP item + decision)
- Next free slot: Kaiju Creation opening (D-207, demo): lab dish, croc genome (others locked), KAIJU juice VFX,
  zoom to black + egg crack, then the river rise. Ask him the lab's look with labelled images first.
- When a lead slot frees: music integration (D-184), then sky and sea life with the whale in the river (D-168;
  demo-end handoff plan), damage on impact (D-166, after strike-delay), sim speed-ups (D-159), Taskforce adult units.
- Heli-standoff: push -> git-helper opens the PR -> non-author sim review -> go; send the sha to the VFX lead (D-183).

## Tools
- Lead docs worktree Kaiju-Incremental-wt/lead-docs (detach at origin/claude/look-options; python edits newline='';
  commit [skip ci]; push HEAD:claude/look-options; rebase on reject). DECISIONS.md cap 400 (scratchpad add_d186.py).
- Suno: built-in browser (he is signed in); downloads via page JS fetch /a/api/download/clip/<id>?format=wav with
  Bearer __session cookie -> signed URL -> curl. Stems: Edit > Get Stems > Auto split (50 credits; CAPTCHA is his).

## Findings

Lead = "Kaiju: LEAD 10". Owns routing, merges, DECISIONS/DESIGN/STATUS, director questions, milestones, this file.
