# Lead handoff, 2026-10-18 05:40
## State: working (lead since 03:56); merge queue #31 board (doc-caps fix) -> #32 perf -> #22 r2 -> #33 sfx-bus -> #27 UI

## Who
Lead = session "LEAD" (local_106fc100...). The old lead session ("Kaiju Incremental game", local_9fac90d2-fae7-
4940-b4ac-144a87f28e6e) does Tripo only; available. Lead owns: QA gates + fresh critics, PR review + merge (squash,
`--match-head-commit`), STATUS/DECISIONS board PRs, director questions, this file, the local GPU slot (one GPU job
at a time, booked by me). The director starts sessions himself; each is told "report to LEAD" (ListAgents).
"Hardrive space balancing" is the director's own session: never message it.

## DEMO (D-050; plan C:\Users\DANTE\.claude\plans\pasted-content-id-a4a2-i-want-glistening-bubble.md)
Croc only; ends after evolve1 (Behemoth, ~20-30 min) on a DEMO COMPLETE card teasing the adult roar; new baby +
adolescent models first; SFX in; adult never played. Decisions D-050..D-061 are in docs/DECISIONS.md (board PR #31).
- P1 balance D MERGED #21; pacing rep 0.59 h to evolve1 / 4.46 h, ins 3.30, ceph 3.75 (table D +-1%). Keep as is.
- P2 D-047 croc clips: PR #22 (claude/croctitan-clips, head bc788c9 = round 2 fixes + cards A + look-options sync,
  flow 100/city 6/clips 14). Round 1 stills PASS; fresh motion-critic FIX (roar slam invisible at the game cam, no
  turn settle, walk wag too fast) -> fixes pushed; evidence (3 s game-cam clips, ~5 s roar, before/after, 2x slam +
  settle crops, card fills) due in one evidence-only push. Then: my 2x check -> FRESH motion-critic -> A/B clip to
  the director -> merge at the reviewed SHA. Critic crops r1: scratchpad critic_d047/. Clips folder: C:\Users\
  DANTE\.claude-desktop-work\side-session-notes\local_9fac90d2...\blender-reptile\d047\.
- P3 croc baby + adolescent (D-059): Tripo DONE 05:22, six-view PASS, GLBs ~/Downloads/kaiju_tripo/
  rep_croctitan_{baby,adolescent}.glb handed to blender-reptile (hand rig, weights, clips, export to assets/kaiju/
  reptilian_{baby,adolescent}.*, stage board baby/adolescent/adult -> me -> critic -> director). Sheets in #31.
- P4 SFX MERGED #8 (47e1b30; D-052, D-055). PR #33 claude/sfx-bus b7fd029: SFX/Music buses, Sound effects slider
  (settings.cfg, default 0.9 from tuning), ui_click/confirm/deny, flow 100->106, settings captures in notes sfx-bus/.
  Asked: a 5 s clip with audio of the menu sounds (director listen gate) + demo_end Sfx.roar(self) behind the
  ClipGait condition. Then army sounds PR (tank fire, shell hit, rotor; local b1f9e18), then (d) heli gun/crash.
- P5 demo slice MERGED #23 (94ebcd8; D-051). Playtest sheet docs/DEMO_PLAYTEST.md MERGED #29. kaiju-motion session
  ENDED; unassigned follow-ups: `is ClipGait` + end-card clip roar after #22; old non-croc save handled (Continue
  offers "Start a new croc", old file renamed, never deleted; flow check).
- P6 export MERGED #28 (tools/export_windows.sh + pck_check.py, tools/* excluded from the pack) and #30 (build.yml
  workflow_dispatch(ref) -> artifact KaijuIncremental-<sha>, 7 days; dispatch run 39056638725 green at 87fba2d).
  Recipe: gh workflow run build.yml --ref claude/look-options -f ref=claude/look-options; gh run download <run>
  -n KaijuIncremental-<sha>. city-calm smokes the artifact locally at the 05:40 GPU go, then is available.
- P7: the director plays the artifact build once #22 (+#27) land. Known gaps on the sheet.

## Other live sessions
- UI (local_37cf489b-ec7b-424c-8333-f0246b216c8a): PR #27 claude/ui-broadcast, look A (D-061), synced with #23 + #8
  (flow floor 100). In #27 also: D-056 biomass rename (player words only; internal keys/save unchanged; flow check
  no visible "rubble"), D-058 body font Kaiju Block for all text below heading size (no engine default; licence
  row), focus ring + crawl fixes + crawl-clearance check, controls table hides species outside the demo allow-list.
  Gate: 1080p + 4K-at-125% captures -> fresh screen-critic (every screen incl. demo_end, BEHEMOTH reveal) -> merge
  after #22. Body-font board: ../Kaiju-Incremental-wt/ui-broadcast/docs/captures/2026-10-18-ui-broadcast/.
- Performance (local_02d8efe2-2071-46af-b4f0-813e88c01810): baseline 553fdeb (GPU 6.0/9.6 ms; hitches CPU). PR #32
  claude/perf-hitches 0eeeb20: prewarm at the run's cone angle (first breath 101-159 -> 19-24 ms), VehicleParts cache
  + per-vehicle material (spawn 34-58 -> 1.5 ms), flow 100->102; merge on green. Next: breath particle pooling, then
  street-life no-feel pass (cache floats, far people every 3rd frame); civilian cap ~600 = director call later;
  sim.step profile to its handoff, no sim change without a kaiju-sim-review packet.
- Lighting (local_b98f22d9-dd85-46ab-ba01-4a6fa997f8f6): looks board -> director KEEP CURRENT (D-057), branch
  claude/lighting parked. Now: remove the legacy breath voxel jet (scenes/fx.gd breath(); the #6 beam carries the
  breath), --fixed-fps 60 on still captures, before/after CI movie + fresh motion-critic, PR to me (lead call).
- Voxel edges (local_944d7cf5-7e53-439c-9fda-16f5a95b46e4, claude/voxel-edge-shading cc4e166): CI before/after done;
  GPU slot 05:22-05:40 for the 4K A/B; then 2x rim crops, critic, Performance bench, PR + D-TBD -> director A/B.
- city-calm (local_9af27a16-0360-4923-b623-6a14a763ce49): #26 D-054, #28, #30 merged; artifact smoke at 05:40.
- blender-reptile (local_bce75838-34da-4991-a74e-b37ed5781547): #22 evidence, then P3 rig.
- Tripo session: octopus adult (8bf2f668) six-view FIX (10-11 arms, two eye pairs, no siphon); sheets in its notes
  docs/captures/2026-10-18-species/. Parked with the species plan (D-060); director call only if it resumes.
- Species plan (local_424edb4c...): plan only (D-060); -wt/species-a holds uncommitted edits; leave.
- AFL lead session: research only (Behemoth stage flat ~50 runs, one verb); report to the director, no task.
- #11 locomotion PAUSED (D-044). #3 -> main HOLD. Unsloth loaded-model fix applied 04:22 (MCP reconnect needed).
- Open for the director: Q3 Apex height (park); civilian cap; octopus mesh fix (if the plan resumes).

## Branch and checkout
Main checkout on claude/look-options. Only the lead commits here (handoffs, docs). Board PR #31 claude/board-2
(D-051..D-061, STATUS, Tripo rows, P3 sheets): doc-caps RED because this file was 132 lines; fixed by this rewrite,
merge look-options into board-2 and re-run. Worktrees (cap 8, D-053): ability-sfx, croctitan-clips, city-calm,
kaiju-motion-cacfd1 (dead session's cwd: remove when free), -wt/demo-slice (remove), ui-broadcast, lighting,
voxel-edges, species-a, army-scales (unknown owner: ask). ci-captures removed (backup in old lead notes).
Merged on look-options 2026-10-18: #21 #24 #25 #26 #23 #29 #28 #30 #8.

## Rules learnt the hard way
- Merge only the reviewed SHA (`--match-head-commit`); squash; `--delete-branch` switches the checkout. A handoff-
  only push moves the head: diff it, re-arm at the new SHA. `gh pr checks --watch --fail-fast` exits on "skipping"
  (docs-only PRs skip shards): poll until no pending, then require no fail/cancel.
- Floors conflict between parallel PRs: merge the smaller first, the next syncs to the real counts. Tell helpers the
  base SHA; one synced onto a stale base once.
- Handoffs: 120-line cap is CI-enforced (doc-caps), Write tool not heredocs, `git pull --rebase` in the background.
- Windowed Godot: override.cfg (mode=0, no_focus, -20000) first; never fullscreen in project.godot. Godot:
  C:/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe (not on PATH).
  ffmpeg: C:\Users\DANTE\AppData\Roaming\Python\Python314\site-packages\imageio_ffmpeg\binaries\ffmpeg-win-x86_64-v7.1.exe.
- CI: `lfs: true`; capture.yml 3000 s limit, one capture at a time; lavapipe misjudges lighting -> look A/Bs on the
  local GPU slot. Still captures need --fixed-fps 60 (lighting session fixing).
- `git worktree remove --force` needs the director's OK (auto mode refuses); back up first. Tripo in the built-in
  browser: Export never reaches disk, hook the anchor click for the CDN link + curl.
- Audio QA without ears: ffmpeg -> f32 envelope, onsets vs the SOUND log; the director's listen is the gate.
- Tests that hard-code a price break on balance changes (#21). After merges adding classes: `godot --headless --import`.

## Running jobs
Mine: none. GPU slot: voxel-edges to 05:40, then city-calm smoke. Helpers: blender-reptile evidence, UI captures,
Perf #32 CI, ability-vfx army PR + menu clip, lighting jet removal, voxel-edges A/B.

## Next (lead)
1. Fix #31 (merge look-options with this file into claude/board-2) -> merge. 2. #32 watcher -> merge.
3. #22 evidence -> 2x check -> FRESH motion-critic -> A/B clip to the director -> merge; assign the ClipGait end-card
roar + old-save handling to a free helper (city-calm after its smoke). 4. #33: menu clip -> director listen ->
merge. 5. Voxel-edges board -> director. 6. #27 captures -> screen-critic -> merge. 7. Demo artifact build via
build.yml dispatch -> director plays (P7). 8. Board PR after the next batch. playbook: nothing new.
