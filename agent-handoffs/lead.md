# Lead handoff, 2026-10-18 04:18
## State: working (lead since 03:56); waiting on helpers: #22 r2, #23 jaw fix, #8 r2 clips, city-calm PR, Tripo board r2

## Who
Lead = session "Game demo planning" (local_106fc100...). The previous lead session ("Kaiju Incremental game",
local_9fac90d2-fae7-4940-b4ac-144a87f28e6e) now does ONLY P3 Tripo (director 03:56). It reports to me at milestones.
Lead owns: helper QA gates + fresh critics, PR review + merge (squash, `--match-head-commit`), STATUS/DECISIONS
board PRs, director questions (ask-the-director), this file. Tripo credits (D-023) and docs/provenance/tripo.md:
the Tripo session; it sends me the provenance rows.

## DEMO (D-050, director 03:35; plan C:\Users\DANTE\.claude\plans\pasted-content-id-a4a2-i-want-glistening-bubble.md)
Croc titan (reptilian) only; ends after evolve1 (Behemoth, ~20-30 min) on a "demo complete" card that teases the
adult roaring; baby + adolescent get NEW models first; SFX unpaused; adult never played (stage_for tier 3).
- P1 balance D: MERGED #21 (81afe80); board #24 MERGED (80ff088). Pacing (comment on #21): reptilian evolve1 0.59 h
  / 4.46 h, insectoid 0.46 / 3.30, cephalopod 0.49 / 3.75 (table D 4.43 / 3.26 / 3.70). Director 03:55: KEEP as is.
- P2 D-047: PR #22 (claude/croctitan-clips a88a4d4). Stills QA PASS (feet, tail root, top-down, jaw). Species
  cards: I chose option A (sway +-40 deg round the 3/4 view, tight fit = old lead's "3/4 side-on"). Fresh
  motion-critic 04:10: FIX. Sent with pass bars at the GAME cam: (1) roar slam invisible (tail never leaves the
  ground 14.30-15.03 s): tip above hip line >=0.3 s then street hit <=0.15 s on the head peak + stomp fx at the tip
  + 0.2 s shake, fx only; clip to show recovery; (2) turn: overshoot >=6 deg, settle 0.3-0.5 s, body stops first;
  (3) walk: one wave per stride (~1.8-2 s), amplitude 0.6-0.75. Critic crops in scratchpad critic_d047/. Round 2 =
  one batched push (fixes + cards A + look-options sync) -> my check -> FRESH critic -> A/B clip to the director.
- P3 baby + adolescent: Tripo session. Refs board v1 docs/captures/2026-10-17-reptile-design/
  croctitan_stage_refs_board.png (realism-critic FIX: B2 arms clear; A2 blunt head, low nub spines, neutral
  stance); round 2 generated 03:49 (Nano Banana Pro). Next: board r2 to the director (through me), Smart Mesh,
  texture, six-view, GLBs to blender-reptile for rig/weights/clips/export.
- P4 SFX: ability-vfx (local_24621710-3f9c-4f67-ae39-8fa4b6192106), PR #8 head 2195d54, flow floor 76->83,
  licences CLEARED, 13 files in provenance. Clips r1: C:\Users\DANTE\.claude-desktop-work\side-session-notes\
  local_9fac90d2.../ability-sfx-d050/. Answers 04:05: stomps every 0.7 s on average (26/52-frame alternation, sim
  rule D-004: keep); crack was on every stomp (Claws 3 + Behemoth clears crack_stomp_power 1.8) -> FIXED
  crack_min_interval 2.5 s + footstep_min_interval 0.25 s (local 2dc3297). Told it: push, re-cut the 3 clips into
  ability-sfx-d050/r2/, then (b) croc roar for the end card + in-game roar, then (c) tank fire, shell hit, rotor
  loop; licences first. My check on r2: audio onsets (imageio ffmpeg) vs run.log. The director's listen is the gate.
- P5 demo slice: PR #23 (claude/demo-slice b358f79; flow 91). QA on CI stills (run 39051576948): flow PASS; FIX
  sent: end card plays the old procedural roar (jaw hangs as a flap) -> idle only unless ClipGait; next job: the
  clip roar on the end card after #22 merges. It merges look-options in (no force-push). Clip run 39051911218
  pending. Select-card crop on the still = #22's fix. Director wording Q: reveal title "REPTILIAN ADOLESCENT"
  vs node "Behemoth".
- P6: city-calm proves a local export (branch claude/export-windows inside its worktree; 4.7.2 templates installed;
  pack check = fontdata bytes + kvox bytes; smoke launch, isolated APPDATA, no focus steal). The director's build: me.
- P7 director plays the exe.

## Other live work
- city-calm (local_9af27a16-0360-4923-b623-6a14a763ce49): director 03:53 "remove the level crossing hellscape"
  = zebra paint at every avenue junction arm + mid-block (scenes/city_ground.gd). Fix 54e9f16 on
  claude/city-calm-streets (zebras at 1 central junction, key city.zebra_junctions, city floor 5->6); CI
  BEFORE/AFTER 1080p stage 1 + Behemoth + 2x crops; PR next. Auto-fix off, no merge; reports to me.
- #11 locomotion (mantis/octopus) PAUSED (D-044), not in the demo. #3 look-options -> main on HOLD.
- Unsloth script bug fix awaits director OK (memory-shared/local-models-companion.md).

## Director queue (old file: C:\Users\DANTE\.claude-desktop-work\side-session-notes\local_9fac90d2.../lead/
director_queue.md). Open: Q3 Apex height (not needed for the demo; park); reveal wording (stage name vs Behemoth);
housekeeping OK: delete remote branches claude/kaiju-skin-weights-before and claude/kaiju-skin-weights (#19 merged).

## Branch and checkout
Main checkout is on claude/look-options (80ff088+). Only the lead commits here (handoff, docs). Worktrees: 7
checkouts (cap 4): ability-sfx, blender-reptile, ci-captures (3 dirty), kaiju-motion, city-calm and more; the
stale three are gone. Ask helpers to remove theirs when their PRs merge.

## Merged on look-options: 2026-10-17 #15 #17 #18 #16 #20 #19 #14; 2026-10-18 #21 #24.

## Rules learnt the hard way
- Tripo: default export name; `find` refs; stay in the signed-in tab; Remove Lighting per page; inspect every texture.
- Merge only the reviewed SHA (`--match-head-commit`). Squash. `gh pr merge --delete-branch` switches the
  checkout to the base branch.
- Windowed Godot: separate command writes override.cfg (mode=0, no_focus, -20000) first; never fullscreen in
  project.godot. Godot path: C:/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe
  (`GODOT=... tools/run_tests.sh`; not on PATH). ffmpeg: not on PATH; use imageio_ffmpeg's binary
  C:\Users\DANTE\AppData\Roaming\Python\Python314\site-packages\imageio_ffmpeg\binaries\ffmpeg-win-x86_64-v7.1.exe.
- CI checkout needs `lfs: true` (fonts are LFS). capture.yml: 3000 s hard limit, run captures one at a time.
- `rm` with variables: "${VAR:?}". After merges that add classes: `godot --headless --import`.
- Subagents without a shell can't read private PRs: stage the diff for them.
- Tests that hard-code a price break on every balance change: #21 moved claws 12->15 and the growth total band.
- Critic clips: CI game-cam captures are 1280x720 @30 fps (lavapipe), not 1080p60; say so in briefs.
- Write handoffs with the Write tool, not a bash heredoc + python (an apostrophe broke the quoting once).

## Running jobs
Mine: none (pacing done, critic done, #24 merged). No override.cfg, no windowed Godot.
Helpers: blender-reptile r2 (side captures CI 39050777699 + fixes), kaiju-motion clip run 39051911218 + jaw fix,
city-calm captures + export branch, ability-vfx r2 clips, Tripo session refs board r2.

## Next (lead)
1. #22 r2 -> my 2x check -> FRESH motion-critic -> A/B 3 s clip to the director -> merge at the reviewed SHA.
2. #8 r2 clips -> onset check -> one listen decision to the director (three clips, labelled).
3. #23 after the jaw fix + clip -> merge; then its ClipGait roar follow-up after #22.
4. city-calm PR -> defect check on BEFORE/AFTER crops -> one labelled picture to the director -> merge.
5. Tripo board r2 -> my defect check (realism-critic) -> director (labelled A/B).
6. Director Qs to batch when he is back: reveal wording; stale remote branches delete OK; Unsloth fix OK.
Director comments live in DECISIONS.md (D-050); this project keeps no roadmap comment chapters. playbook: nothing new.
