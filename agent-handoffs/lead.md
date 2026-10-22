# Lead handoff, 2026-10-23 (lead session "Status check"; auto-compacts, no hand-off, no self-archive)
## Successor: register (empty file named by your CLI session id in ~/.claude/context-guard-leads/), read this, then
## GitHub (open PRs), then docs/ROADMAP.md (Playtest milestones D-146) and docs/DECISIONS.md D-139..D-147.

## Director state and rules in force
- Game renamed Kaiju Evolution (save folder kept). Three visual pillars, equal (DESIGN.md "Visual pillars"): beauty,
  consistency (one look per effect), power fantasy ("Apex Predator, King of Monsters, Godkiller, Planetbreaker";
  "our enemies are many, but they ultimately are our prey"). Bar: "I have to love it" (RULEBOOK critic-rounds line).
- D-146: far fewer clips; NO per-change director gates. Lead merges green, critic-passed work. He playtests only at
  milestones M1 feel pass, M2 Taskforce agents, M3 demo complete, M4 Itch RC: export an .exe to a fixed folder and
  write that milestone's exhaustive survey THEN, not before ("dont make the surveys now").
- VFX lead = second in command: Opus session "vfx-lead", local_46ccb461-4998-4550-a36d-66e715fcfb06 (worktree on
  claude/vfx-lead, rebased to origin/claude/look-options). Owns every effect + its art QA; its SHIP is final for
  effects; the lead only routes. NEVER let it idle. Its queue: (1) docs/VFX_STYLE.md + contact sheet, (2) verdicts on
  the explosions rework and the title fire/Colossus (proof scratchpad/fc/fire_compare.png), (3) helicopter deaths
  (D-140), (4) BuildingView.lift_piece collapse defect (scenes/building_view.gd ~204), (5) Taskforce effects,
  (6) texture board (3 styles, walls+roofs first) then rollout, (7) graphics preview scene, (8) load-screen board (~20).
- GPU always unless ~/.claude/focus-pause exists. Every Godot run under timeout. Stop only own PIDs.
- Ask him a lot (AskUserQuestion), but never what DESIGN/DECISIONS already answer (night play = D-106 random time).

## Base and PRs
- Base = origin/claude/look-options = main; squash-only; open PRs synced by merging the base.
- GitHub helper subagent (ad7455760cd21c2b0) merges green PRs at exact head sha (--match-head-commit), cap 3 open.
- Merged recently: #149 turn (57a1f7fc). #152 fire: CLEAN at b72f550d, held for the fire builder's next push
  (breath cover 24 circles ~0.65 ms/breath accepted). D-144: tanks caught by the longer breath just die.

## Builders (subagents; transcript = .../b2b0bc5b.../subagents/agent-<id>.jsonl; watcher args scratchpad/watch_args.txt)
- ui (aae3577c954b0b7d8, claude/ui-redesign): title per his mockup (menu left column, one wide New Kaiju, logo above),
  baked Colossus silhouette + faint red eye, game fire from windows, water shiver on footfall, boot 13 s -> ~5 s.
  Now: flow + ui suites, stills, push, ready PR -> VFX lead review. Row ~36% width vs mockup 34%.
- three-steps (a4e343e24c232918d): D-135 three growth steps. Baseline pacing for old 4 steps 3.30 h; demo target
  90+ min (D-145): flag if far off. Adolescent city held at 80 (RiverQuay crate rule). Then sim-review packet, PR.
- explosions (a681216347970b2b1): fireball rework using the game fire (r7 opaque cubes rejected) -> VFX lead -> PR;
  then Taskforce PR 1 sim core (commit 01f80b9d; plan Kaiju-Incremental-wt/post-fx/agent-handoffs/taskforce-plan.md,
  questions answered by D-143/D-145).
- turn (a49f6845ba127d3bb, claude/director-cleanup): Thunder Beam rename (one data string), cut breath camera swing,
  remove BRANCH/CAPSTONE labels, cut "AIR FORCE GROUNDS ALL HELICOPTERS", roars on ultimate + dash with cooldown.
- post-fx (a2793c08ae17ca604): vignette + impact fringe (railgun_hit event fires fringe; red pulse <25% hp thin band;
  clip passed, goes to M1). Then claude/time-of-day (random per run, never twice in a row, options toggle) suites,
  4K options-row still for the screen critic, PR.
- army (a93ebc729b932307f, claude/clumsy-army-v2): full suite, PR + sim-review packet.
- fire (ab3379115fcf064da): #152 push.

## Ruled, not started (each brief names ROADMAP item + decision)
- Taskforce (D-137/139/141/143/145): agents, frost, railgun, gas soldiers, mechs, gunships, all before the demo.
- Demo (D-145): all three cities, 90+ min, thanks screen with stats + feedback link, pause-menu feedback, fresh start.
- Post effects SSR after the demo (D-142). Threat Dossier after the demo (D-147). Narrative cards after demo (#76).
- Boot cut further (engine+autoloads 7.8 s) queued after the ui PR.

## Tools
- Stall watcher: SKIP_PIDS="..." bash ~/.claude/tools/stall_watch.sh $(cat scratchpad/watch_args.txt), background;
  re-arm after each flag; it also flags bash "until" loops older than 90 min (staleloop).
- Lead docs worktree Kaiju-Incremental-wt/lead-docs (detached at origin/claude/look-options; python edits newline='';
  commit [skip ci]; push HEAD:claude/look-options; rebase on non-fast-forward). DECISIONS.md cap 400 lines
  (scratchpad add_d1xx.py rolls oldest to docs/archive/decisions_2026-10.md).
- ffmpeg: C:/Users/DANTE/AppData/Roaming/Python/Python314/site-packages/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe
- Native dll for local runs: copy Kaiju-Incremental-wt/carve-play/native/bin/*.dll into native/bin/.

## Findings
- Seed-sensitive checks flip with city/walk changes: probe the unit, fix behaviour or re-pin, never the threshold;
  but after a design change, first ask whether the check still fits the fiction (D-144).
- Compare a new effect side by side with the existing one of its kind before passing it (explosions r7).
- Release smoke runs from the repo root.

Lead = "Kaiju: LEAD 10". Owns routing, merges, DECISIONS/DESIGN/STATUS, director questions, milestones, this file.
