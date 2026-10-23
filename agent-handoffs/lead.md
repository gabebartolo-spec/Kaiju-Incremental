# Lead handoff, 2026-10-23 (lead session "Status check"; auto-compacts, no hand-off, no self-archive)
## Successor: register (empty file named by your CLI session id in ~/.claude/context-guard-leads/), read this, then
## GitHub (open PRs), then docs/ROADMAP.md ("Director comments" chapter, Playtest milestones D-146, Engineering
## upkeep D-159), DECISIONS D-155..D-186, and the lead board (below).

## Director state and rules in force
- He is present (not AFK). The interview is DONE (answers in scratchpad interview_answers.md, D-163..D-170).
- D-177 MOTION FIRST: motion and destruction are the core; every body/movement change passes the motion CI suite at
  all 3 growth steps. Order: gait fix (#175), motion pass, D-165 living predator.
- Game renamed Kaiju Evolution. Three equal visual pillars (beauty, consistency, power fantasy). Bar: "I have to love it".
- D-146: NO per-change director gates; he plays only at milestones M1-M4 (export to Desktop\Kaiju Builds\M<n>, survey
  as a web page). M1 waits for all its items, the music integration included.
- D-186 (amends D-159): builders run locally only the 1-2 suites they iterate on, then push; GitHub runs the rest.
  Lead: fresh builder per task, design + pass bars before code (heli took 6 runs without).
- D-159: about 4 engine builders IN TOTAL (lead 2, VFX lead 2); at most 3 open PRs; clean crowded files as you go.
  Every brief says `bash ~/.claude/tools/engine_slot.sh && timeout ...` (staggers Godot starts below 6 processes).
- Lead/VFX split: VFX lead owns every visual item end to end; lead owns sim, gameplay, UI flow, tests, merges, docs,
  milestones, sound. Each tells the other before touching the other's files.
- D-171: new heads after the demo (Colossus unlock, evolve-screen picker = lead's UI, post-demo). D-173: wrecks also
  kill perched Taskforce agents. D-166 strike times: breath/ultimate 0.8/1.1/1.4 s, stomp 0.45 s (data).
- D-175: per-squad volleys kept (0.6 s). D-178: cooldown from a volley's first shot.
- D-162/D-170: Tripo 6500 credits left for round 2 (serpentine python, albino) + up to 100 for the tail rig test;
  browser only. Downloads by signed URL + curl. Never edit a running bash script in place.
- Music D-184 SHIPPED: his remaster of G2 (798f3c13) = the theme, on the menu over the city sound (amends D-141) and
  the Cover source; cities C1a/C2a/C3a, each Auto split; all in C:/Users/DANTE/Downloads/kaiju_music (WAVs + stems).
  320 of 800 credits, 8 of 20 downloads; G1-G4 not to be downloaded again ("later if we need"). Revisit music later
  (ROADMAP). NEXT: a fresh builder cuts loops + layers (D-125), menu music, LICENSING_REGISTER entry (Suno Pro,
  commercial), checks vocal stems are near silent; when an engine slot frees. Recipe in docs/provenance/music.md.
- VFX lead items he raised today: D-185 claw swipe = heavy raking arc; breathing too big and fast (bars 4/6/8 s
  period, 0.8/0.6/0.5% amplitude); night fog SHIP merged (#172), queued cross-hatch, weak night silhouette, D-154 haze.

## Lead board (cross-session sends are capped at 10 between his messages)
- C:/Users/DANTE/Documents/GitHub/Kaiju-Incremental-wt/lead-board/: README.md (protocol), to-<session>.md, from-<session>.md,
  interview.md. Scratchpad board_watch.sh wakes the lead on any from-file or interview change.

## Sessions and builders
- vfx-lead local_46ccb461-4998-4550-a36d-66e715fcfb06: owns #175 gait-fix (motion gate), gait clips, fire round 6
  (white share <=20%) then the helicopter look, breathing fix, claw swipe after gait, living predator phase A.
- Lead's builders (subagents, Sonnet, common brief scratchpad COMMON-2026-10-23.md):
  - beam-cost (agent a1448c3e2dfa8c9e5, ~586k tokens) on claude/heli-standoff (D-183), worktree volley-d178: fly-by
    strafing pass outside the camera arc; runs heliflight only, pushes, reports sha; then refresh (fresh builder).
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
  (clips + motion critic) and the lead's own check; local gate was green (motion 30/0, shin jerk 2.7/4.3).
- Not opened: claude/strike-delay (red, diagnosing), heli-look-r4 (VFX), claude/sim-speed daad0710 (measurement only:
  Convoy body polygon ~25%, bucketed building scans ~10%; sim/convoy.gd at 400 lines, split first).
- Pacing on GitHub (#174): push pacing-run/<name> with .github/pacing-run.json {"species","runs","verbose"}.

## Next queue (each brief names its ROADMAP item + decision)
- When a lead slot frees: music integration (D-184), then sky and sea life with the whale in the river (D-168;
  demo-end handoff plan), damage on impact (D-166, after strike-delay), sim speed-ups (D-159), Taskforce adult units.
- Heli-standoff: push -> git-helper opens the PR -> non-author sim review -> go; send the sha to the VFX lead (D-183).
- Hygiene: scratchpad hygiene_manifest.md (dead worktrees vs cap 12, backups first); local scratch/gait-merge branch
  in the volley worktree.

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
