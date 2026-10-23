# Lead handoff, 2026-10-23 (lead session "Status check"; auto-compacts, no hand-off, no self-archive)
## Successor: register (empty file named by your CLI session id in ~/.claude/context-guard-leads/), read this, then
## GitHub (open PRs), then docs/ROADMAP.md ("Overnight work", Playtest milestones D-146, Engineering upkeep D-159),
## DECISIONS D-155..D-162, and the lead board (below).

## Director state and rules in force
- Game renamed Kaiju Evolution. Three equal visual pillars (beauty, consistency, power fantasy). Bar: "I have to love it".
- D-146: NO per-change director gates; he plays only at milestones M1-M4 (export to Desktop\Kaiju Builds\M<n>, survey
  as a web page). M1 waits for all its items, music from his Suno stems included (D-155).
- D-159: about 4 engine builders IN TOTAL (lead 2, VFX lead 2); touched suites only, full suite on CI; at most 3 open
  PRs; clean crowded files as you go; sim-speed measurement queued. `~/.claude/tools/engine_slot.sh` (new) staggers
  Godot starts below 6 processes: every brief says `bash ~/.claude/tools/engine_slot.sh && timeout ...`.
- Lead/VFX split: VFX lead owns every visual item end to end; lead owns sim, gameplay, UI flow, tests, merges, docs,
  milestones, sound. Each tells the other before touching the other's files.
- 2026-10-23 afternoon: he is back; the interview is DONE (9 rounds, answers in scratchpad interview_answers.md),
  recorded as D-163 to D-170 + DESIGN + ROADMAP "Interview answers" (df5309de). Work resumed, wind-down over.
- D-162/D-170: Tripo 6500 credits left for round 2 (serpentine python, albino) + up to 100 for the tail rig test;
  browser only, no API, no local ComfyUI. Tripo downloads: agents fetch by signed URL + curl (the Save dialog belongs
  to the Claude app). Never edit a running bash script in place (it broke a watcher).
- Suno: he makes the tracks this week (D-169); prompts in docs/audio/music-briefs.md; lead cuts and layers stems.

## Lead board (cross-session sends are capped at 10 between his messages)
- C:/Users/DANTE/Documents/GitHub/Kaiju-Incremental-wt/lead-board/: README.md (protocol), to-<session>.md (lead's
  instructions, sessions read them at each step and watch them when waiting), from-<session>.md (fallback reports),
  interview.md (questions for him). Scratchpad board_watch.sh wakes the lead on any from-file or interview change.

## Sessions (start_session; message by local_ id)
- vfx-lead local_46ccb461-4998-4550-a36d-66e715fcfb06, briefed 13:05 with its queue (ack pending): #166 revert to
  "wrecks crush the army too" + look SHIP; one look (D-163); heads/skins round 2 + rig test (D-164, D-170); living
  predator (D-165); strike times per growth step for D-166; Thunder Beam round 7 (claude/thunder-beam 6dbe10e5, FIX).
- taskforce and demo-end sessions are no longer listed (their PRs #161, #165 merged). Their handoffs: worktrees
  agent-a91efff177a679849 (taskforce.md) and agent-acf7f07f188a4cd34 (demo-end.md, sky and sea life plan).
- Lead's builders (subagents, Sonnet, brief scratchpad COMMON-2026-10-23.md): beam-cost (claude/beam-cost: r_beam
  cheaper so the last unlock lands ~2 h, one 1-h pacing run) and volley (claude/volley-stagger: <=2 railgun hits per
  squad per second, then a read-only audit of when pressed attacks deal damage, for D-166). Stall watcher armed.

## Base and PRs (11:50, wind-down complete)
- Base = origin/claude/look-options; squash-only. Merges need "#N go <full sha>" to the GitHub helper
  ad7455760cd21c2b0 (go.txt), CLEAN + all 14 checks + shards actually run; it trial-merges before opening a PR.
- Merged overnight (10): #159 army, #154 look sheet, #163 city sound, #160 title, #161 Taskforce core, #164 three
  growth steps, #167 weather, #168 body-chunks (tests), #169 croc standing, #165 demo end + Endless (a7ac8788,
  save v4).
- Open: #166 heli deaths (look FIX; D-167: revert to wrecks crushing the army; VFX lead resyncs and re-critics).
- Not opened: claude/sim-speed daad0710 = measurement only (checksum 2c712cc6589535dd; speed-ups: body polygon per
  Convoy step ~25%, bucketed building scans ~10%, spacing prefilter ~2-6%; sim/convoy.gd is at 400 lines, split
  first). Result-identical engineering (D-159), to start after his return.
- Next queue (lead's builders, 2 at once): sky and sea life sim with the whale in the river between the play city and
  the distant city (D-168; demo-end handoff plan), damage on impact (D-166, after the audit + VFX strike times), the
  sim speed-ups, Taskforce adult units, music stems when he sends them.

## Queued (each brief names its ROADMAP item + decision)
- Chunks inside the body: was the test fixture (PR #168), not the sim. Sim speed: measured (above).
- Music: he generates Suno tracks (docs/audio/music-briefs.md); lead cuts stems, registers docs/provenance/music.md.
- Hygiene ("get the githib hygeinic"): GitHub helper manifest in scratchpad hygiene_manifest.md; round 2 removes dead
  worktrees (28 vs cap 12) with backups, deletes only remote branches already inside the base.

## Tools
- Stall watcher: IDLE_MIN=20 bash ~/.claude/tools/stall_watch.sh $(cat scratchpad/watch_args.txt) (no spaces in paths).
- Lead docs worktree Kaiju-Incremental-wt/lead-docs (detach at origin/claude/look-options; python edits newline='';
  commit [skip ci]; push HEAD:claude/look-options; rebase on reject). DECISIONS.md cap 400 (scratchpad add_d162.py).
- ElevenLabs: creative flow tools; set duration_seconds on the node (estimate_only creates it) before running.
  Measure takes with scratchpad sfx_measure.py; true peaks exceed 0 dBFS, so set gain from the float peak.
- ffmpeg: C:/Users/DANTE/AppData/Roaming/Python/Python314/site-packages/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe

## Findings
- 2026-10-23: 14 engine jobs on 16 threads held the CPU at 100%; frame-time numbers taken then are noise.
- A CI watcher must require every expected check before calling a head green (it once read green before shards ran).
- Seed-sensitive checks: probe the unit, fix behaviour or re-pin, never the threshold (D-144).

Lead = "Kaiju: LEAD 10". Owns routing, merges, DECISIONS/DESIGN/STATUS, director questions, milestones, this file.
