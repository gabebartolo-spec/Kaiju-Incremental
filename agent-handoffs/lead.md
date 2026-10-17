# Lead handoff, 2026-10-18 05:00
## State: working (lead since 03:56); merge queue #8 (after sync) -> #28 -> #22 r2 -> #27; GPU slot: lighting to 05:20, voxel-edges to 05:40

## Who
Lead = session "LEAD" (was "Game demo planning", local_106fc100...). The previous lead session ("Kaiju Incremental
game", local_9fac90d2-fae7-4940-b4ac-144a87f28e6e) does ONLY P3 Tripo (director 03:56). Lead owns: QA gates + fresh
critics, PR review + merge (squash, `--match-head-commit`), STATUS/DECISIONS board PRs, director questions, this
file, the local GPU slot (one Godot/Blender GPU job at a time, booked by me). Tripo credits + docs/provenance/tripo.md:
the Tripo session. The director also starts sessions himself; each is told "report to LEAD" when found (ListAgents).

## DEMO (D-050, director 03:35; plan C:\Users\DANTE\.claude\plans\pasted-content-id-a4a2-i-want-glistening-bubble.md)
Croc titan only; ends after evolve1 (Behemoth, ~20-30 min) on a "demo complete" card teasing the adult roar; baby +
adolescent get NEW models first; SFX unpaused; adult never played (stage_for tier 3).
- P1 balance D: MERGED #21 (81afe80); board #24 (80ff088). Pacing (comment on #21): reptilian evolve1 0.59 h / 4.46 h,
  insectoid 0.46 / 3.30, cephalopod 0.49 / 3.75 (table D 4.43 / 3.26 / 3.70). Director 03:55: KEEP as is.
- P2 D-047: PR #22 (claude/croctitan-clips a88a4d4; cards A local 7d3f761). Stills QA PASS. Fresh motion-critic 04:10
  FIX, pass bars at the GAME cam: (1) roar slam invisible: tip above hip line >=0.3 s then street hit <=0.15 s on the
  head peak + stomp fx at the tip + 0.2 s shake (fx only), clip shows recovery; (2) turn: overshoot >=6 deg, settle
  0.3-0.5 s; (3) walk: one wave per stride (~1.8-2 s), amplitude 0.6-0.75. Critic crops: scratchpad critic_d047/.
  Round 2 = ONE batched push (fixes + cards + side clips + look-options sync) -> my check -> FRESH critic -> A/B clip
  to the director -> merge at the reviewed SHA. Then kaiju-motion: `is ClipGait` + end-card clip-roar clip.
- P3 baby + adolescent: Tripo session. Director 04:4x approved the refs (docs/captures/2026-10-17-reptile-design/
  croctitan_stage_line.png, critic PASS) and the Smart Mesh spend (~260 credits); submitting now; also downloads
  the octopus adult texture 8bf2f668 (director yes). A stray Chrome "My Assets" tab froze its Tripo tab; no Kaiju
  session drives Chrome (species session confirmed). Next: meshes -> six-view -> GLBs to blender-reptile.
- P4 SFX: ability-vfx (local_24621710-3f9c-4f67-ae39-8fa4b6192106), PR #8 head ed0d8ea (dials, roar.ogg + Sfx.roar on
  the reveal, flow 84; army sounds moved to local branch claude/army-sfx-wip b1f9e18 for a new PR). D-052 ship SFX
  r2 (04:30), D-055 roar on reveal + end card (04:35). Told 04:52: #23 merged, sync look-options (flow floor 92 +
  its checks), one push, SHA to me -> I merge on green. Next: (e) mixer bus + SFX volume slider in settings (new PR),
  then (f) UI sounds, then army PR.
- P5 demo slice: MERGED #23 (94ebcd8, flow floor 92): croc-only select, demo end card after the Behemoth reveal
  (idle unless ClipGait), D-051 reveal title = node name (BEHEMOTH). kaiju-motion next: docs/DEMO_PLAYTEST.md (P7
  sheet) on a new branch; then the clip-roar follow-up after #22.
- P6 export: PR #28 (claude/export-windows 8510a77, city-calm): tools/export_windows.sh + pck_check.py; exe 126.7 MB,
  real font bytes + kvox bytes proven (failing-first), smoke 450 frames clean, title_1080p_frame300.png real fonts.
  Asked before merge: exclude tools/* from the pack + assert, re-export, re-smoke, SHA. Next for city-calm: build.yml
  workflow_dispatch(ref) export + pack check + artifact KaijuIncremental-<sha>.zip; the director's demo build comes
  from that artifact once #22 + #8 land.
- P7 director plays the exe (sheet from kaiju-motion).

## Other live sessions (ListAgents 04:55; messages to "Game UI elements design" and "Hardrive space balancing" are
HELD by their permission mode: tell the director)
- UI ("Game UI elements design"): PR #27 claude/ui-broadcast 7a7ab3d, director picked look A "Emergency Broadcast"
  (D-TBD-ui-look-broadcast in its body); captures pending (1080p CI, 4K at 125% to follow). Gate: fresh screen-critic
  on every screen incl. demo_end + BEHEMOTH reveal; merge AFTER #8 and #22, synced. My brief is held undelivered.
- Lighting (local_b98f22d9-dd85-46ab-ba01-4a6fa997f8f6, claude/lighting, -wt/lighting, 3429e6e): director asked for
  beautiful realistic lighting + atmosphere, then playable dramatic night. scenes/city_lighting.gd split out,
  looks.json golden/dusk/night, sim floor 39->40, suites green. GPU slot 04:58-05:20 for game-cam A/B (A-D labelled,
  1080p + 4K) + luminance p10/p50 + art-qa-critic -> me -> ONE director decision. CI run 39053401383 = skyline only.
- Voxel edges ("Game shader selection", local_944d7cf5-7e53-439c-9fda-16f5a95b46e4, claude/voxel-edge-shading
  cc4e166, -wt/voxel-edges): director: prototype voxel edge shading, labelled before/after through the lead.
  voxel_edge.gdshaderinc, strengths in looks.json. CI before/after 1080p runs 39052984488 / 39053097548 finishing;
  GPU slot 05:20-05:40 for 4K A/B; then 2x rim crops, critic, Performance bench, PR + D-TBD-voxel-edges.
- Skill trees ("Incremental game skill trees"): unknown brief; asked to report in (keep reptilian road to Behemoth
  20-30 min, re-pace with tools/pacing.gd).
- Hard drive ("Hardrive space balancing"): told hands off live Kaiju checkouts/worktrees/scratchpads/notes/Tripo
  downloads without asking me; message HELD.
- Performance (local_02d8efe2-2071-46af-b4f0-813e88c01810, agent-handoffs/performance.md): baseline 553fdeb: 1080p
  GPU 6.0 ms pre-evolve / 9.6 ms Behemoth; "4K" clamped to 1977x1080 (not verified); hitches are CPU: signature
  first use 126-170 ms, tank/heli spawn 35-45 ms (VehicleParts rebuilds meshes), street life 4.6 ms/frame. Task
  given: fix PR (VehicleParts cache, pre-warm the signature, report street-life cap), bench before/after, re-bench
  as #22/#8/#28 land.
- city-calm (local_9af27a16-0360-4923-b623-6a14a763ce49): #26 MERGED (55231be, D-054 zebras only at the central
  junction); now #28 export (above). Worktree city-calm holds claude/export-windows; removes after #28.
- Species plan (local_424edb4c-bc64-4094-8463-da44fe4cf0e4): director 04:50 "plan only, not execution": builder
  stopped, nothing pushed; -wt/species-a holds uncommitted edits + the untracked plan (also untracked in the main
  checkout: docs/superpowers/plans/2026-10-18-mantis-octopus-game-ready.md). Leave until the director says.
- #11 locomotion PAUSED (D-044). #3 -> main on HOLD. Unsloth loaded-model fix APPLIED 04:22 (MCP reconnect needed).

## Director decisions today (board PR after this merge batch): D-050 demo (#21), D-051 reveal title (#23),
D-052 SFX ship + D-053 worktrees one per live session (#25 MERGED 444ed01), D-054 streets (#26), D-055 roar (#8),
D-TBD-species-models 04:27 (keep all six mantis/octopus meshes, croc hand rig, octopus first; execution paused
04:50), D-TBD-ui-look-broadcast (#27), P3 refs + ~260 Tripo credits approved. Open: Q3 Apex height (park).

## Branch and checkout
Main checkout on claude/look-options (94ebcd8+). Only the lead commits here (handoffs, docs); Performance and the
species session also wrote handoffs/plans here. Worktrees 7-8 (cap 8, D-053): ability-sfx, croctitan-clips,
city-calm, kaiju-motion-cacfd1 (kaiju-motion's cwd; delete when that session ends), -wt/demo-slice (delete after
#23: told), lighting, voxel-edges, species-a. ci-captures removed (backup: old lead notes ci-captures-worktree-backup/).

## Merged on look-options: 2026-10-17 #15 #17 #18 #16 #20 #19 #14; 2026-10-18 #21 #24 #25 #26 #23.

## Rules learnt the hard way
- Tripo: default export name; `find` refs; stay in the signed-in tab; Remove Lighting per page; inspect every texture.
- Merge only the reviewed SHA (`--match-head-commit`); squash; `--delete-branch` switches the checkout. A helper's
  handoff-only push moves the head: diff it, re-arm the watcher at the new SHA.
- Windowed Godot: separate command writes override.cfg (mode=0, no_focus, -20000) first; never fullscreen in
  project.godot. Godot: C:/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe
  (`GODOT=... tools/run_tests.sh`; not on PATH). ffmpeg: imageio_ffmpeg's binary at
  C:\Users\DANTE\AppData\Roaming\Python\Python314\site-packages\imageio_ffmpeg\binaries\ffmpeg-win-x86_64-v7.1.exe.
- CI checkout needs `lfs: true`. capture.yml: 3000 s hard limit, one capture run at a time; CI game-cam clips are
  1280x720 @30 fps lavapipe: software rendering misjudges lighting/fog, so look A/Bs use the local GPU slot.
- `rm` with variables: "${VAR:?}". After merges that add classes: `godot --headless --import`.
- Subagents without a shell can't read private PRs: stage the diff for them.
- Tests that hard-code a price break on every balance change (#21). Floors conflict between parallel PRs: merge the
  smaller first, the next syncs and resolves to real counts.
- `git worktree remove --force` is refused by auto mode: back up, ask the director, retry once (worked).
- Write handoffs with the Write tool. `git pull --rebase` can take >2 min here: run it in the background.
- Audio QA without ears: ffmpeg -> f32 envelope, onsets vs the helper's SOUND log; the director's listen is the gate.

## Running jobs
Mine: none (watchers for #26/#23 done). GPU slot: lighting until 05:20, then voxel-edges until 05:40.
Helpers: blender-reptile r2 batch; ability-vfx #8 sync; city-calm #28 addition; kaiju-motion playtest sheet;
lighting A/B; voxel-edges CI runs; Performance hitch fixes; Tripo session Smart Mesh submissions.

## Next (lead)
1. #8 sync SHA -> watcher -> merge. 2. #28 SHA -> watcher -> merge; then city-calm's build.yml dispatch PR.
3. #22 r2 -> 2x check -> FRESH motion-critic -> A/B clip to the director -> merge; then kaiju-motion clip-roar.
4. Lighting board -> my check -> one director decision (A-D). 5. Voxel-edges board -> same. 6. #27 captures ->
screen-critic -> merge after #8/#22. 7. Tripo meshes -> six-view check -> blender-reptile. 8. Board PR (decisions
above + STATUS rows for the new sessions). 9. Tell the director the two held messages (UI, hard drive).
Director comments live in DECISIONS.md; no roadmap comment chapters. playbook: nothing new.
