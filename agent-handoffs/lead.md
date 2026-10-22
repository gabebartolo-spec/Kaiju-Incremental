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
- 2026-10-23 ~03:25 he went to sleep, then work: "work for 5 hours, if theres something you need my eye or a question
  you need to ask, add it to the interview and continue working". NO AskUserQuestion until he is back; then run the
  interview from the lead board's interview.md (AskUserQuestion, one decision each, images first).
- D-162: Tripo 8000 credits for snake/Komodo head options and croc skin concepts (VFX lead runs it in the built-in
  browser); boards go to the interview. Every Tripo download opens a Save dialog owned by the Claude app, which
  computer use may not control (guarded): agents fetch models by signed URL (browser network requests + curl) instead.
  One Komodo dialog was left open at 04:30 for him. Never edit a running bash script in place (it broke a watcher).

## Lead board (cross-session sends are capped at 10 between his messages)
- C:/Users/DANTE/Documents/GitHub/Kaiju-Incremental-wt/lead-board/: README.md (protocol), to-<session>.md (lead's
  instructions, sessions read them at each step and watch them when waiting), from-<session>.md (fallback reports),
  interview.md (questions for him). Scratchpad board_watch.sh wakes the lead on any from-file or interview change.

## Sessions (start_session; message by local_ id)
- vfx-lead local_46ccb461-4998-4550-a36d-66e715fcfb06: #154 r2 + fresh critic -> "#154 PASS"; Thunder Beam (wires the
  lead's 3 sounds from Downloads/kaiju_sfx_raw/thunder_beam/final/README.md); heads+skins (D-162); heli-deaths pushed
  9b947478 (PR queued); idle audit fix only after his answer; voxel-look stills when the reader's report lands;
  explosions r10; #160 SHIP; D-155 atmosphere looks.
- taskforce local_45625dd0-b212-4edd-a154-fd32b4dd7fa7: #161 at f0209f96 RED on CI (taskforce_gate "save and reload
  keep the clock", run 39813584987); review fixes 1,3,6,7 to confirm; reviewer probes fixes 4-5.
- demo-end local_d3ef25ef-1809-40da-9618-2b29226929f4: suites, push claude/demo-end (PR queued); weather pick only
  after "go weather" in its to-file.

## Base and PRs
- Base = origin/claude/look-options; squash-only. GitHub helper ad7455760cd21c2b0 merges only on my "#N go" at the
  exact head; its watcher now requires all 14 checks present before "green" (an early green was reported once).
- Open: #154 (VFX look sheet, waits "#154 PASS"), #159 army (waits fix159 push + my check), #160 title (head c7b0887b,
  CI running; needs VFX lead SHIP + screen critic), #161 (red, above), #157 roadmap journal (not ours).
- PR queue when open PRs < 3: three-steps (M1), city sound (M1), heli-deaths (VFX), demo-end.

## Builders (subagents; transcripts .../b2b0bc5b.../subagents/agent-<id>.jsonl; scratchpad/watch_args.txt)
- three-steps a4e343e24c232918d: touched suites, push, no PR yet; after-pacing 2 h run waits for my go.
- city-sound a883e071aee1e9e5f; fix159 aef759596a568ac00; title160 a200bd8ccf893338a (stills to the lead, then to the
  VFX lead); sim reviewer aa9275ca32eecec08 (fixes 4-5 probes on #161).
- Readers (no engine): kaiju animation research a5cc46e61edbb65cf, AI-3D pipeline research a238d53ea23dd2bd6 (incl.
  Aseprite, Meshy and SpriteCook plugins), voxel-look research ac037c79822051ffd (Opus). Reports land in the scratchpad
  (research_*.md) -> interview questions. Idle audit done: scratchpad idle_audit.md.

## Queued (each brief names its ROADMAP item + decision)
- Chunks inside the body after a chewed topple (seeds 3, 8, 22), sim fix. Sim speed measurement (D-159).
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
