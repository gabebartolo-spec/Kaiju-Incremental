# Lead handoff, 2026-10-23 (lead session "Status check"; auto-compacts, no hand-off, no self-archive)
## Successor: register (empty file named by your CLI session id in ~/.claude/context-guard-leads/), read this, then
## GitHub (open PRs), then docs/ROADMAP.md ("Overnight work", Playtest milestones D-146, Engineering upkeep D-159),
## DECISIONS D-155..D-162, and the lead board (below).

## Director state and rules in force
- 14:15 "im afk", "work for 3 hours" (to ~17:15): questions go to the lead board's interview.md AFK section; ask
  them on his return. Keep-awake on. New GitHub helper subagent git-helper (go.txt protocol, scratchpad git_helper_notes.md).
- D-177 MOTION FIRST: motion and destruction are the core; every body/movement change passes a motion CI suite at
  all 3 growth steps (VFX gait builder writes it from its probe; lead merges). Order: gait fix, gate, motion pass, D-165.
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
- D-171: new heads come after the demo, unlocked with the Colossus (evolve-screen picker = lead's UI, post-demo).
- D-173: wrecks also kill perched Taskforce agents (#166 part 1c). D-166 strike times: breath/ultimate 0.8/1.1/1.4 s,
  stomp 0.45 s (data), dash after the crouch: lead's builder after the volley audit.
- His walk complaint (adolescent legs twitchy, swivels): VFX lead diagnosing, top of its next slot (ROADMAP comments).
- Night white glow (his screenshot: haze over the left towers): VFX lead suspects BuildingFade + FSR; stills after 14:14.
- D-175: per-squad volleys kept (0.6 s); volley builder does the strike delays next (claude/strike-delay).
- 13:29 "no godot for next 45 minutes": scratchpad no_godot_until2.sh holds all team Godot until 14:14.
- D-162/D-170: Tripo 6500 credits left for round 2 (serpentine python, albino) + up to 100 for the tail rig test;
  browser only, no API, no local ComfyUI. Tripo downloads: agents fetch by signed URL + curl (the Save dialog belongs
  to the Claude app). Never edit a running bash script in place (it broke a watcher).
- Suno: he makes the tracks this week (D-169). His first takes were "way too intense" and the old guide didn't match
  Suno's UI: D-172 = brooding, building, one mood growing; music-briefs.md rewritten from help.suno.com (Sept 2026;
  then D-174: the lead runs Suno in the built-in browser (he's signed in; 800 credits; he picks by ear), D-176 darker
  not heavier, Godzilla-like menace; D-181 one theme, Cover per city; D-182 Jaws/Godzilla/Imperial March, not epic.
  Rejected in turn: heroic, same city to city, epic/Nolan, staccato endless build, Y set "too whimsicial, almsot
  Harry Potteresque, go harder on the Godzillla reference". D-184 SHIP: his remaster of G2 (798f3c13) = the theme,
  menu over city sound (amends D-141) + Cover source; he picked C1a/C2a/C3a; all split (Auto split, he did one
  CAPTCHA) and downloaded with stems to Downloads/kaiju_music (320 of 800 credits, 8 of 20 downloads). NEXT: a builder
  cuts loops + layers (D-125), menu music, LICENSING_REGISTER entry, when an engine slot frees. Download recipe: song More options > Download > WAV > Unlock & Download, then page JS
  fetch /a/api/download/clip/<id>?format=wav with Bearer __session cookie -> signed URL -> curl. Revisit music later.
- D-185 claw swipe: heavy raking arc (VFX lead owns; it set bars). Hidden browser pane: clicks can time out; retry.

## Lead board (cross-session sends are capped at 10 between his messages)
- C:/Users/DANTE/Documents/GitHub/Kaiju-Incremental-wt/lead-board/: README.md (protocol), to-<session>.md (lead's
  instructions, sessions read them at each step and watch them when waiting), from-<session>.md (fallback reports),
  interview.md (questions for him). Scratchpad board_watch.sh wakes the lead on any from-file or interview change.

## Sessions (start_session; message by local_ id)
- vfx-lead local_46ccb461-4998-4550-a36d-66e715fcfb06, acked its order: slot 1 #166, slot 2 one look phase 1 (grade, far blur, ground), asset
  worker python r2 + colour tables + rig test (Komodo head slot asked), then D-165, then Thunder Beam r7. Queue: #166 revert to
  "wrecks crush the army too" + look SHIP; one look (D-163); heads/skins round 2 + rig test (D-164, D-170); living
  predator (D-165); strike times per growth step for D-166; Thunder Beam round 7 (claude/thunder-beam 6dbe10e5, FIX).
- taskforce and demo-end sessions are no longer listed (their PRs #161, #165 merged). Their handoffs: worktrees
  agent-a91efff177a679849 (taskforce.md) and agent-acf7f07f188a4cd34 (demo-end.md, sky and sea life plan).
- Lead's builders (subagents, Sonnet, brief scratchpad COMMON-2026-10-23.md): beam-cost (claude/beam-cost: r_beam
  at x0.3 only, D-167 amended: the beam alone can't reach 2 h, he chose ~2.25 h; one 1-h pacing run) and volley (claude/volley-stagger: <=2 railgun hits per
  squad per second, then a read-only audit of when pressed attacks deal damage, for D-166). Stall watcher armed.

## Base and PRs (11:50, wind-down complete)
- Base = origin/claude/look-options; squash-only. Merges need "#N go <full sha>" to the GitHub helper
  ad7455760cd21c2b0 (go.txt), CLEAN + all 14 checks + shards actually run; it trial-merges before opening a PR.
- Merged overnight (10): #159 army, #154 look sheet, #163 city sound, #160 title, #161 Taskforce core, #164 three
  growth steps, #167 weather, #168 body-chunks (tests), #169 croc standing, #165 demo end + Endless (a7ac8788,
  save v4).
- 15:00: #166 MERGED (3e4a7665; look r3 FIX flagged for M3, r4 on claude/heli-look-r4). Open: #170 volley (D-178
  rework e5d24848; sim re-look FIX: _can_join reads rail_cd before later gunners decrement (split lock), cooldown drift
  after round 1 (lead ruled: cooldown from the volley's first shot, D-178 every volley), roof check; beam-cost fixes
  after its heliflight suite, repro scratchpad volley_port.py; go only on the fixed head green), #171 beam (pacing hours pending, run from 16:02). pacing-ci a601bbac on origin, not opened yet.
  16:37: night-fog SHIP 4524e90c (VFX lead) = #172; go on green AND once its evidence folder is found (path asked). gait-step-len pushed
  #173 fix 841f93e2 re-review SHIP, go armed; #170 2d6710fa re-review SHIP, go armed; #174 7d54a279 go armed;
  pacing run 39910488328 (GitHub) for #171; strike-delay red on military (volley builder diagnosing);
  #171 CLOSED to free its slot (git-helper reopens after pacing hours); #172 night-fog MERGED 4f8b8d10; #174
  pacing-ci held (needs pacing-run/** push trigger: beam-cost after #170 fix; workflow_dispatch needs main);
  sha sent to the VFX lead (gait-fix 9d436583 rebases on it). Volley builder back on strike-delay reruns.
  Next slot: claude/gait-step-len (volley builder), then claude/gait-fix (VFX, motion gate), then strike-delay.
- D-179 pacing workflow (beam-cost builder, claude/pacing-ci); D-180 skins need a cohesive range (post-demo).
- Godot hold until 16:01 ("no godot for 75min" at 14:46), scratchpad no_godot_until2.sh.
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
