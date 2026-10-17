# Lead handoff, 2026-10-18 04:38
## State: working (lead since 03:56); waiting on helpers: #22 r2, #23 jaw+title fix, #8 roar wiring, city-calm PR, Tripo board r2

## Who
Lead = session "Game demo planning" (local_106fc100...). The previous lead session ("Kaiju Incremental game",
local_9fac90d2-fae7-4940-b4ac-144a87f28e6e) now does ONLY P3 Tripo (director 03:56). It reports to me at milestones.
Lead owns: helper QA gates + fresh critics, PR review + merge (squash, `--match-head-commit`), STATUS/DECISIONS
board PRs, director questions (ask-the-director), this file, the local GPU slot. Tripo credits (D-023) and
docs/provenance/tripo.md: the Tripo session; it sends me the provenance rows.

## DEMO (D-050, director 03:35; plan C:\Users\DANTE\.claude\plans\pasted-content-id-a4a2-i-want-glistening-bubble.md)
Croc titan (reptilian) only; ends after evolve1 (Behemoth, ~20-30 min) on a "demo complete" card that teases the
adult roaring; baby + adolescent get NEW models first; SFX unpaused; adult never played (stage_for tier 3).
- P1 balance D: MERGED #21 (81afe80); board #24 MERGED (80ff088). Pacing (comment on #21): reptilian evolve1 0.59 h
  / 4.46 h, insectoid 0.46 / 3.30, cephalopod 0.49 / 3.75 (table D 4.43 / 3.26 / 3.70). Director 03:55: KEEP as is.
- P2 D-047: PR #22 (claude/croctitan-clips a88a4d4 + local 7d3f761 cards A). Stills QA PASS. Fresh motion-critic
  04:10: FIX, sent with pass bars at the GAME cam: (1) roar slam invisible (tail never leaves the ground 14.30-15.03 s):
  tip above hip line >=0.3 s then street hit <=0.15 s on the head peak + stomp fx at the tip + 0.2 s shake, fx only;
  clip shows recovery; (2) turn: overshoot >=6 deg, settle 0.3-0.5 s, body stops first; (3) walk: one wave per
  stride (~1.8-2 s), amplitude 0.6-0.75. Critic crops: scratchpad critic_d047/. Cards A done locally (croc fill 0.42
  -> 0.56). Round 2 = ONE batched push (fixes + cards + side clips + look-options sync) -> my check -> FRESH critic
  -> A/B clip to the director -> merge at the reviewed SHA.
- P3 baby + adolescent: Tripo session. Refs board v1 docs/captures/2026-10-17-reptile-design/
  croctitan_stage_refs_board.png (realism-critic FIX: B2 arms clear; A2 blunt head, low nub spines, neutral
  stance); round 2 generated 03:49. Next: board r2 to the director (through me), Smart Mesh, texture, six-view,
  GLBs to blender-reptile. Also asked it to download the octopus adult texture 8bf2f668 for the species session.
- P4 SFX: ability-vfx (local_24621710-3f9c-4f67-ae39-8fa4b6192106), PR #8 head 2a2edb5 (roar on the reveal + Sfx entry, army: tank_fire, shell_hit, heli_rotor loop with distance fade; flow floor 76->87). Roar APPROVED D-055. Merge order: #26 first (city floor 5->6), then #8 syncs look-options, I merge on green. Next job given: (e) mixer bus + SFX volume slider in settings (new PR), then (f) UI sounds. Earlier head 32ecfa1 (dials crack_min_interval
  2.5 s + footstep_min_interval 0.25 s, roar.ogg draft + provenance). Director 04:30 listened to r2 clips
  (...ability-sfx-d050/r2/): SHIP AS IS = D-052 (in #25's Board and log; helper logs it in #8 too). Now (b): roar in
  the evolution reveal + a Sfx entry for the end card (option 1: not under Atomic Breath, no new power); then I merge
  #8 at that SHA when green. (c) army sounds (tank fire, shell hit, rotor) = a NEW PR after #8.
- P5 demo slice: PR #23 (claude/demo-slice b358f79 + #21 merged in; flow 91). QA on CI stills: flow PASS; FIX
  sent: end card idle only unless ClipGait (old procedural roar hangs the jaw); D-051 (director 04:20): reveal
  title = node name BEHEMOTH, not "REPTILIAN ADOLESCENT" (same push, flow check failing first). Clip in:
  ...side-session-notes\local_9fac90d2...\demo-slice\clip\capture-39051911218-0\clip.mp4 (re-check after the fix).
  Next job after: clip roar on the end card via ClipGait once #22 merges; the end card also calls the roar Sfx.
- P6: city-calm proves a local export (branch claude/export-windows in its worktree; templates installed; pack check
  = fontdata bytes + kvox bytes). Its exe smoke launch is HELD until the Performance bench ends (~04:45). The
  director's build: me.
- P7 director plays the exe.

## Other live sessions
- city-calm (local_9af27a16-0360-4923-b623-6a14a763ce49): director 03:53 "remove the level crossing hellscape".
  Fix 54e9f16 on claude/city-calm-streets (zebras at 1 central junction, key city.zebra_junctions, city floor 5->6);
  PR #26 (55231be): my defect check PASS, director 04:35 ship AFTER (D-054); merge-on-green watcher armed. Export proof next; smoke launch held until the GPU slot frees (~04:45).
- Performance (local_02d8efe2-2071-46af-b4f0-813e88c01810, handoff agent-handoffs/performance.md, director-approved):
  demo baseline bench tools/capture/bench_rampage.gd, reptilian at Behemoth, 1080p x3 + 4K x3; has the local GPU
  slot 04:25-04:45; results in its own handoff only.
- Species plan (local_424edb4c-bc64-4094-8463-da44fe4cf0e4, "Character animation implementation plan"): director-
  approved docs/superpowers/plans/2026-10-18-mantis-octopus-game-ready.md (mantis + octopus game-ready, stacks on
  #22). OUTSIDE the demo (D-050/D-044); told: no demo files, one GPU job at a time, PRs to me. Worktree
  ../Kaiju-Incremental-wt/species-a.
- #11 locomotion PAUSED (D-044); the species plan folds its findings in and closes #11 unmerged. #3 -> main on HOLD.
- Unsloth loaded-model fix APPLIED 04:22 (director OK; memory-shared/local-models-companion.md; MCP reconnect needed).

## Director decisions today (log in board PRs): D-050 demo (#21), D-051 reveal title (#23), D-052 SFX ship (#25),
D-053 worktrees one per live session (#25 MERGED 444ed01), D-054 streets: zebras only at the central junction (#26, director 04:35), D-055 croc roar on reveal + end card, not under breath (#8, 04:35), D-TBD-species-models 04:27 (species session's first PR): keep all six
mantis/octopus meshes, croc hand rig + welded weights, octopus first; octopus texture 8bf2f668 now critical path. Stale branches kaiju-skin-weights{,-before} deleted 04:21.
Open for the director: Q3 Apex height (not needed for the demo; park).

## Branch and checkout
Main checkout on claude/look-options (6185a0a+). Only the lead commits here (handoff, docs). PR #25
claude/worktree-cap (cap 8 + CI-capture rule in CLAUDE.md) merging on green via my watcher. Worktrees: 7 live
(ability-sfx, croctitan-clips, city-calm, kaiju-motion-cacfd1 = kaiju-motion's cwd, delete when that session ends;
-wt/demo-slice, lighting, voxel-edges); ci-captures removed (files backed up in the old lead's notes folder
ci-captures-worktree-backup/; its CLAUDE.md note is in #25). Lint: `bash tools/lint/worktrees.sh`.

## Merged on look-options: 2026-10-17 #15 #17 #18 #16 #20 #19 #14; 2026-10-18 #21 #24.

## Rules learnt the hard way
- Tripo: default export name; `find` refs; stay in the signed-in tab; Remove Lighting per page; inspect every texture.
- Merge only the reviewed SHA (`--match-head-commit`). Squash. `gh pr merge --delete-branch` switches the checkout.
- Windowed Godot: separate command writes override.cfg (mode=0, no_focus, -20000) first; never fullscreen in
  project.godot. Godot: C:/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe
  (`GODOT=... tools/run_tests.sh`; not on PATH). ffmpeg: imageio_ffmpeg's binary at
  C:\Users\DANTE\AppData\Roaming\Python\Python314\site-packages\imageio_ffmpeg\binaries\ffmpeg-win-x86_64-v7.1.exe.
- CI checkout needs `lfs: true`. capture.yml: 3000 s hard limit, run captures one at a time. CI game-cam clips are
  1280x720 @30 fps (lavapipe): say so in critic briefs.
- `rm` with variables: "${VAR:?}". After merges that add classes: `godot --headless --import`.
- Subagents without a shell can't read private PRs: stage the diff for them.
- Tests that hard-code a price break on every balance change (#21: claws 12->15, growth total band).
- `git worktree remove --force` is refused by auto mode: back the files up and ask the director, then retry once.
- Write handoffs with the Write tool, not a bash heredoc + python (quoting broke once).
- Audio QA without ears: decode with ffmpeg to f32, per-frame envelope, onsets vs the helper's SOUND log; the
  director's listen is the gate, the lead checks timing and density only.

## Running jobs
Mine: merge-on-green watcher on #26 (then arm one for #8 after its sync). No override.cfg, no windowed Godot. Performance session holds the GPU slot.
Helpers: blender-reptile r2 batch (CI captures), kaiju-motion jaw+title fix, ability-vfx roar wiring, city-calm
captures + export build, Tripo session board r2 + octopus texture.

## Next (lead)
1. #22 r2 -> my 2x check -> FRESH motion-critic -> A/B 3 s clip to the director -> merge at the reviewed SHA.
2. #8 roar SHA -> merge on green; tell kaiju-motion the Sfx call. 3. #23 fix push -> stills + clip check -> merge.
4. city-calm PR -> crops check -> one labelled picture to the director -> merge. 5. Tripo board r2 -> realism-critic
-> director. 6. 04:45: release the GPU slot to city-calm's smoke launch. 7. Board PR after each merge batch.
Director comments live in DECISIONS.md; this project keeps no roadmap comment chapters. playbook: nothing new.
