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
  Every brief says `bash ~/.claude/tools/engine_slot.sh && timeout ...` (staggers Godot starts below 6 processes).
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
  Heli fall = view arc between the sim's death and crash points; #175 MERGED 3a3ee03d (go.txt cleared).
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
- vfx-lead local_46ccb461-4998-4550-a36d-66e715fcfb06: smooth fire rollout (claude/fire-smooth) then heli fall, breath
  default, claw on the snout line. Holds my lent slot until the breath job closes (asked to return it).
- Lead's builders (subagents, Sonnet, common brief scratchpad COMMON-2026-10-23.md):
  - beam-cost (agent a1448c3e2dfa8c9e5, ~586k tokens) on claude/heli-standoff (D-183), worktree volley-d178: fly-by
    strafing pass outside the camera arc; runs heliflight only, pushes, reports sha; then refresh (fresh builder).
    Run 6 red; WIP 4e0d6637 (local). Trace: every claw-band miss is in pull-back. Cause A (sim): the kaiju jumps
    17-27 u/s at Behemoth/Colossus in turns (suspect BodyContact._swing about the planted foot, same as the gait
    critic's 270 deg/s): measured 100% _swing. Cause B fixed (0.6 s smoothed anchor), run 7 WIP 8f729ebb: 3 left
    (camera Behemoth/Colossus, claw Colossus), all from the swing. STOOD DOWN: pushed backup 2c0c2688 (no PR),
    handoff heli-standoff.md; a fresh builder rebases on turn-weight and reruns heliflight; camera still red then =
    director question with episodes. Worktree volley-d178 prunable (all pushed). Learnings filed (2cb3d956).
- Pacing runs die from a LEAK: RSS +240 MB a run (15.2 GB at run 80, tee run 39920885597). Cause (sim-leak builder,
  agent a99d69e0317e5c842, claude/sim-leak): RefCounted cycles (23 classes hold `sim`), so every dropped RampageSim
  lives on, in the game too (rampage.gd, title_backdrop.gd). Fix: RampageSim.dispose(); bars flat memory + same
  checksum. #171 waits for it. git-helper's local pacing-run branches: delete denied, his hygiene list.
  - volley (agent ac92f78143e5f1af5, ~551k tokens) on claude/strike-delay (D-166): military red on 3 checks; paired
    seeds 0-47 per city, delays on vs off, before any re-pin (D-144); different distributions = a behaviour change to
    report (maybe a director question). Then refresh.
- git-helper (agent a145028402855b958): opens PRs, merges ONLY on a `<pr> <full sha>` line in scratchpad go.txt
  (lead writes it; CLEAN, 14+ checks, all 4 shards SUCCESS). Watcher bjfndxbrl; pacing waiter b9pyyaosi.
- Stall watcher bosw631nr: IDLE_MIN=25 PROC_MIN=80 MAX_MIN=120 LOOP_MIN=120 over scratchpad watch_args.txt.

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
