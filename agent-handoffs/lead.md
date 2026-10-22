# Lead handoff, 2026-10-23 (lead session "Status check"; auto-compacts, no hand-off, no self-archive)
## Successor: register (empty file named by your CLI session id in ~/.claude/context-guard-leads/), read this, then
## GitHub (open PRs), then docs/ROADMAP.md (Playtest milestones D-146, Engineering upkeep D-159), DECISIONS D-148..D-159.

## Director state and rules in force
- Game renamed Kaiju Evolution (save folder kept). Three equal visual pillars (DESIGN "Visual pillars"): beauty,
  consistency, power fantasy. Bar: "I have to love it".
- D-146: NO per-change director gates. Lead merges green, critic-passed work. He plays only at milestones M1-M4:
  export an .exe to Desktop\Kaiju Builds\M<n>, survey as a web page with fields, written only then (D-152).
  M1 waits for all its items, atmosphere included (D-155). Version DEMO 0.1, rising per milestone.
- D-159 (2026-10-23): about 4 engine-running builders IN TOTAL (lead's + VFX lead's; proposed 2 each, awaiting the
  VFX lead's ack and count); builders run only touched suites, the full suite is CI only; at most 3 open PRs;
  builders clean crowded files / grandfathered long functions they touch; sim-speed measurement queued.
- Lead/VFX split (RULEBOOK): VFX lead owns every visual item end to end; lead owns sim, gameplay, UI layout and
  flow, tests, merges, docs, milestones; each tells the other before touching a file the other's builders are in.
- Every session keeps its app task list current. Ask him a lot, never what DESIGN/DECISIONS answer; an agent-added
  game rule found in review goes to him as a question in the fiction's words.
- 02:27 "no godot for 30 mins", 02:58 "pause for 30 more mins": loop b623ho9x1 (scratchpad no_godot_until.sh)
  stops our --script Godot runs until 03:28, then deletes ~/.claude/focus-pause. Subagents and the VFX lead told.
- D-161 (docs a57866d5): railgun hits the body's middle; mid-smash or iced only the dash dodges; pierces buildings;
  armour softens it; frost only lands on a still kaiju. Sent to taskforce with D-160 and the #161 review fixes; the
  reviewer (aa9275ca32eecec08) probes fixes 4-5 after 03:28. Sent to demo-end. Still to send: vfx-lead thunder note.
- (Was unsent, now sent except vfx-lead):
  taskforce = D-160 gate (about 3 min of rampage time in the adolescent city, counter in the save, default on load +
  round-trip check; its one-key gate at 6787982b is not enough) + sim review coming + touched suites after 03:28.
  demo-end = "exit 127" was my pause loop and the focus guard blocks windowed runs only while focus-pause exists
  (both end 03:28): rerun flow/smoke then; amended ending (final node -> thanks -> endless) accepted; endless entry
  from the thanks screen + upgrade-tree button accepted; people eaten/fled as view counts OK for the thanks screen;
  push the branch, PR only when open PRs <= 3. vfx-lead = the thunder sound for the Thunder Beam is the lead's
  (sound), queued.
- D-160: the Taskforce first joins after a few minutes total in the adolescent city (docs d9198a92).

## Sessions (start_session; message by local_ id)
- vfx-lead local_46ccb461-4998-4550-a36d-66e715fcfb06 (Opus): #154 look sheet (critic FIX round, then "#154 PASS"),
  explosions r9 handed over (claude/city-explosives-v2 5a9697db, not resynced, reads cream not orange-red: fire
  family fix is theirs), heli deaths, lifted-piece cut faces, thunder-beam rework, lit smoke, atmosphere looks,
  #160 SHIP.
- taskforce local_45625dd0-b212-4edd-a154-fd32b4dd7fa7: PR #161 (claude/taskforce-core a25487e5 after the helper's
  README merge); 4 checks were failing at handover (late-step railgun dodge, dash shatters frost, grenade miss,
  effect fixture). Needs a sim review before "#161 go".
- demo-end local_d3ef25ef-1809-40da-9618-2b29226929f4 (Sonnet): thanks screen at final upgrade, endless mode
  (D-156), then weather pick, sky/sea life sim, Taskforce adult units. Told: no new PR until open PRs are <= 3.

## Base and PRs
- Base = origin/claude/look-options = main; squash-only. GitHub helper subagent ad7455760cd21c2b0 merges at exact
  head (--match-head-commit). Merged today: #155 post-fx (d8f812f2), #158 feedback button (66af2589).
- Merged today: #155 post-fx, #158 feedback, #162 director cleanup (57a2c6a5), #156 time of day (1a0b7a73).
- #154 VFX look sheet: on "#154 PASS" from the VFX lead. #159 army: after its fixer's push + green + lead check.
- #160 title: D-158 amended to option C (Colossus ~185 m, ~7 deg tilt, 163 m tower lowered on the title only); needs
  VFX lead SHIP + screen critic. #161 held (above). #157 roadmap journal is not ours.

## Builders (subagents; transcript .../b2b0bc5b.../subagents/agent-<id>.jsonl; scratchpad/watch_args.txt)
- three-steps a4e343e24c232918d: after 02:58 touched suites, push, PR + sim-review packet, then after-pacing run
  (killed at run 17 by the pause; target last unlock ~2 h, D-156). Fix pacing.gd header "3-5 hours" to ~2 h.
- city-sound a883e071aee1e9e5f (D-155 panic then eerie quiet).
- fix159 aef759596a568ac00: #159 sim-review items; strays probes max 2 at once.
- title160 a200bd8ccf893338a: option C + menu round-2 fixes; stills to the VFX lead.
- Stood down (no refill under D-159): explosions, turn, feedback, ui.

## Queued (each brief names its ROADMAP item + decision)
- Chunks inside the body after a chewed topple (seeds 3, 8, 22; tests/lib/sim_body_contact.gd _chew_to_topple
  "worst"): sim-side (BodyContact chew/hold or Collapse.settle drops chunks into the held body); VFX lead confirmed
  the view is not involved. ROADMAP Engineering upkeep.
- Sim speed measurement (D-159). Music: director generates Suno tracks from docs/audio/music-briefs.md; lead cuts and
  layers stems, registers in docs/provenance/music.md.
- Leader's escape helicopter (D-149) and Threat Dossier (D-147): after the demo.

## Tools
- Stall watcher bb02rl3c5 (IDLE_MIN=35 during the pause; back to 20 after): bash ~/.claude/tools/stall_watch.sh
  $(cat scratchpad/watch_args.txt), background; re-arm after each flag.
- Lead docs worktree Kaiju-Incremental-wt/lead-docs (detach at origin/claude/look-options; python edits newline='';
  commit [skip ci]; push HEAD:claude/look-options; rebase on reject). DECISIONS.md cap 400 (scratchpad add_d159.py
  pattern rolls oldest to docs/archive/decisions_2026-10.md).
- ffmpeg: C:/Users/DANTE/AppData/Roaming/Python/Python314/site-packages/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe
- Native dll for local runs: copy Kaiju-Incremental-wt/carve-play/native/bin/*.dll into native/bin/.

## Findings
- 2026-10-23: 14 engine jobs on 16 threads held the CPU at 100%; frame-time numbers taken then are noise.
- Seed-sensitive checks: probe the unit, fix behaviour or re-pin, never the threshold; after a design change first
  ask whether the check still fits the fiction (D-144).
- Compare a new effect side by side with the existing one of its kind before passing it (explosions r7-r9).

Lead = "Kaiju: LEAD 10". Owns routing, merges, DECISIONS/DESIGN/STATUS, director questions, milestones, this file.
