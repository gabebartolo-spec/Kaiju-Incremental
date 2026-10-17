# Lead handoff, 2026-10-18 04:05
## State: working (lead since 03:56: QA queue #8 SFX, D-047, city-calm; #21 CI; director state report sent)

## Who
Lead = session "Game demo planning" (local_106fc100...). The previous lead session ("Kaiju Incremental game",
local_9fac90d2-fae7-4940-b4ac-144a87f28e6e) now does ONLY P3 Tripo (director 03:56). It reports to me at milestones.
Lead owns: helper QA gates + fresh critics, PR review + merge (squash, `--match-head-commit`), STATUS/DECISIONS
board PRs, director questions (ask-the-director), this file. Tripo credits (D-023) and docs/provenance/tripo.md:
the Tripo session; it sends me the provenance rows.

## DEMO (D-050, director 03:35; plan C:\Users\DANTE\.claude\plans\pasted-content-id-a4a2-i-want-glistening-bubble.md)
Croc titan (reptilian) only; ends after evolve1 (Behemoth, ~20-30 min) on a "demo complete" card that teases the
adult roaring; baby + adolescent get NEW models first; SFX unpaused; adult never played (stage_for tier 3).
- P1 balance D: PR #21 claude/balance-d (head 6c9bcb2+; 6/7 checks green at 04:00). Suites green at floors.
  Pacing reptilian: evolve1 0.59 h (run 28), evolve3 3.85 h, tree 4.46 h (table D 4.43). Director 03:55: KEEP as is;
  human time confirmed at P7. Insectoid/cephalopod pacing still running in my scratchpad (pacing_*.log); add to
  the #21 body when done. D-050 text is in docs/DECISIONS.md on the branch (old lead asked for it there).
- P2 D-047 adult clips: blender-reptile, claude/croctitan-clips 4a35fed (clips own tail0..8 at runtime, 0.189 rad
  check; species cards fit height). Capture runs: 39050652051 green, 39050777699 running (one at a time now; the
  earlier reds were capture.yml's 3000 s limit when two runs overlap). Owed before PR: in-game 2x tail root,
  BEFORE/AFTER clip, side clips. Then my QA (2x crops) + FRESH motion-critic -> director.
- P3 baby + adolescent: Tripo session. Refs board v1 docs/captures/2026-10-17-reptile-design/
  croctitan_stage_refs_board.png (realism-critic FIX: B2 arms clear; A2 blunt head, low nub spines, neutral
  stance); round 2 generated 03:49 (Nano Banana Pro; GPT Image failing on Tripo's side). Next: board r2 to the
  director (through me), Smart Mesh, texture, six-view, GLBs to blender-reptile for rig/weights/clips/export.
- P4 SFX: ability-vfx (local_24621710-3f9c-4f67-ae39-8fa4b6192106), PR #8 head 2195d54 synced to dbff208,
  flow floor 76->83, licences CLEARED, 13 files in provenance. Clips with audio: C:\Users\DANTE\.claude-desktop-work\
  side-session-notes\local_9fac90d2-fae7-4940-b4ac-144a87f28e6e\ability-sfx-d050\{stomp,building_fall,breath}.mp4
  + run.log. MY QA 04:02 from run.log: stomp_2 every 26 frames (0.43 s vs stomp_interval 0.7), stomp_crack on EVERY
  stomp, footsteps irregular (gaps 81/51/78/78/53 frames). Asked the helper to explain (no push) + prepare a
  footstep min-interval knob in tuning "sfx". No ffmpeg on PATH (can't frame-check locally). Director's listen is
  the gate; present only after the timing answers.
- P5 demo slice: kaiju-motion (local_fd14d508...; session "Kaiju locomotion"), claude/demo-slice (capture run
  39051576948 running). Brief: tuning `demo` {enabled, species allow-list, end_node evolve1}; species_select
  filter; main.gd -> scenes/demo_end.gd after the evolve1 reveal (adult roar, DEMO COMPLETE, Title/Quit); save
  round-trip; flow checks failing first; real-input GUI run + 1080p captures + clip. Rebase after #21.
- P6 Windows export from look-options: me, after P5 (export_presets.cfg "Windows Desktop"; build.yml is main-only).
- P7 director plays the exe.

## Other live work
- city-calm (local_9af27a16-0360-4923-b623-6a14a763ce49): director 03:53 "remove the level crossing hellscape"
  = zebra paint at every avenue junction arm + mid-block (scenes/city_ground.gd). Branch claude/city-calm-streets
  off ed1d2d9; new key city.zebra_junctions (1). Evidence: CI BEFORE/AFTER 1080p stage 1 + Behemoth, 2x junction
  crops, suites green. Auto-fix off, no merge; reports to me.
- #11 locomotion (mantis/octopus) PAUSED (D-044), not in the demo. #3 look-options -> main on HOLD.
- Unsloth script bug fix awaits director OK (memory-shared/local-models-companion.md).

## Director queue (old file: C:\Users\DANTE\.claude-desktop-work\side-session-notes\local_9fac90d2.../lead/
director_queue.md). Still open: Q3 Apex height (not needed for the demo; park). Housekeeping needing his OK:
delete remote branches claude/kaiju-skin-weights-before and claude/kaiju-skin-weights (#19 merged).

## Branch and checkout
Main checkout C:\Users\DANTE\Documents\GitHub\Kaiju Incremental is on claude/balance-d (PR #21). After #21
merges: `git checkout claude/look-options && git pull`, delete balance-d, and work in a worktree per task
(cap 4; live now: ability-sfx, blender-reptile, ci-captures (3 dirty), kaiju-motion + stale city-growth,
game-flow, kaiju-look-test = clean, merged; kaiju-motion was told to remove the stale three). The old lead's
look-options commits are pushed (dbff208..ed1d2d9). Only the lead commits in the main checkout.

## Merged on look-options 2026-10-17: #15 #17 #18 #16 #20 #19 #14.

## Rules learnt the hard way
- Tripo: default export name; `find` refs; stay in the signed-in tab; Remove Lighting per page; inspect every texture.
- Merge only the reviewed SHA (`--match-head-commit`). Squash; #21 carries old-lead handoff commits (fine).
- Windowed Godot: separate command writes override.cfg (mode=0, no_focus, -20000) first; never fullscreen in
  project.godot. Godot path: C:/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe
  (`GODOT=... tools/run_tests.sh`; not on PATH).
- CI checkout needs `lfs: true` (fonts are LFS). capture.yml: 3000 s hard limit, run captures one at a time.
- `rm` with variables: "${VAR:?}". After merges that add classes: `godot --headless --import`.
- Subagents without a shell can't read private PRs: stage the diff for them.
- Tests that hard-code a price break on every balance change: #21 moved claws 12->15 and the growth total band.

## Running jobs
Mine: background pacing.gd (insectoid, then cephalopod) in session scratchpad; no override.cfg, no windowed Godot.
Helpers: blender-reptile captures (CI), kaiju-motion demo-slice capture (CI), city-calm BEFORE captures (CI),
ability-vfx answering SFX timing questions, Tripo session on refs board r2.

## Next (lead)
1. SFX: read the helper's timing answers; if crack-on-every-stomp is by design, FIX to conditional; then present
   the three clips to the director as one listen decision (ask-the-director, clips not stills).
2. D-047 PR when it opens: 2x crops, fresh motion-critic, then director (A/B: Blender clips vs old, 3 s clip).
3. #21: add pacing numbers, merge on green (lead = merge role now), board PR for STATUS rows + D-050 done.
4. city-calm BEFORE/AFTER crops -> my defect check -> director (one picture, labelled).
5. Record 03:35-04:00 director comments in docs/ROADMAP.md demo chapter (not yet done).
playbook: nothing new.
