# Lead handoff, 2026-10-21 late (lead 10; CLI session 1df8b1cf, registered in ~/.claude/context-guard-leads/)
## Successor: register (empty file named by your CLI session id in ~/.claude/context-guard-leads/), read this, then
## GitHub (open PRs), then the notes folder below. Director's /goal: playable build with building carving first draft.
## Plan = docs/ROADMAP.md "Post-demo plan" phases A-H; research picks "R n.m" -> docs/research/2026-10-21/ (01-24).
## Comments: docs/roadmap/2026-10-21-director-comments.md (#1-#46 today; #45-46 minimal HUD, #33 neck approved).

## Director state: at the PC, often gaming. Clips/captures render on the LOCAL GPU always (RTX 4070 SUPER; off-screen
## no_focus override.cfg, --windowed; two calls: write the override, then launch) until he says pause (~/.claude/focus-pause).
## Up to 2 headless Godot per agent. Never a visible window or dialog. Subagents up to 8 (RULEBOOK Kaiju exception).

## Notes folders
- NEW (lead 10's agents): C:\Users\DANTE\AppData\Local\Claude-Data\claude_pzs8sxrjxfjjc\side-session-notes\local_df2c2989-951e-4b20-9998-9c23b0a37f42\
  BRIEF-COMMON.md + RULES-NOW.md = shared rules; each agent writes <task>\handoff.md at milestones.
- Nimbalyst mailbox: C:\Users\DANTE\Documents\Nimbalyst Tutorial\kaiju-mailbox\ (to-nimbalyst tasks, to-kaiju results).

## 2026-10-22 day (lead session status-check-b96b26, registered in context-guard-leads; supersedes the Team list below)
- Base = origin/claude/look-options = main; squash-only repo, so the base moves on every merge. Old branches are rebuilt
  as their own commits cherry-picked onto the newest tip (scratchpad WAVE1-COMMON.md has the builder rules).
- Merged today: PR #147 crowds 6x (c07c50ae). PR #144 turn open (turn builder updating it).
- Director rulings 2026-10-22: comments #55-63, D-132 (1.0 demo on Itch, invite-only, when the reptilian stage is 100%),
  D-133 (landmark stable ~12, 3 per stage rotate by seed; new 8: bridge tower, opera shells, coaster, donut sign, power
  station, airport tower WITH planes flying in/out, port cranes, refinery; Tripo models made carvable), D-134 (Tripo 9000
  credits today; start 19115, stop at 10115), #60 all CPU/GPU/screen/Godot slots ours, #63 atmosphere list (clouds,
  weather, birds, 1 whale per run, fire crews, ambulances, dogs, clubs, banks, hotels, trains, boats: details to ask).
  RULE: helpers on Sonnet unless complex (RULEBOOK). PC piloting allowed (computer-use: Claude Work, File Explorer, msedgewebview2).
- Wave 1 subagents (resumed after a restart; Opus, left to finish): city-memory (+landmark unload if no pop-in), perf-scans
  (suite running, -> claude/perf-scans-v2), perf-tiles, audit-shared, audit-sim (rebuilt off fire), clumsy-army (strays
  probe, on claude/clumsy-army-v2), turn (#144), camera. They push, never open PRs; lead reviews diffs, opens PRs (max 3).
- Wave 2 (Sonnet unless complex) as slots free: fire-spread (Opus), intro, rubble (Opus), explosions, dash, UI, ui-art
  (WIP renderer committed da048e0a on claude/ui-art), then the landmark stable and atmosphere once he answers details.
- Tripo (built-in browser, logged in): croc-head icon HD model c9b2b460 generating (65 cr); set Private, six-view,
  export default name, then voxelize/render via claude/ui-art tools. Still to make: dash foot, button plate.
- Worktrees: 9 merged ones removed (leftovers in Kaiju-Incremental-wt/_leftovers-2026-10-22).
- rule-check.py gave no answers (0/14): the Sonnet rule is recorded but NOT proven.
- Director: back soon for an interview; ask about atmosphere details, landmark look boards, wave 2 order.

## Team (lead 10's subagents; die with this session; re-brief from NEW notes <task>\handoff.md)
- ui (claude/ui-redesign adba1267): minimal HUD done (HUD share 3.19% -> 1.37%; rings bottom-left, plain timer red
  last 10 s, thin meter, small biomass, no controls text). Screen critic running; then show director before/after and
  ASK: remove the first-run controls card too? (one-line change). Drafting pr-body.md, no PR yet.
- camera (claude/camera-growth b8ffe2a9): critic FIX on cameraA_topple_fade.mp4: head too high 1.9-3.6 s, zoom bob
  0-2 s, dither opacity cap 0.35 over the kaiju, fade ramp 12-15 frames. Re-render 4K, one critic re-check.
- neck (claude/croc-neck c39873cd): NECK_SHARE 0.75 APPROVED by director. Builder now on audit P1 (claude/audit-ci:
  #5 tuning-key CI check, #25 function-size ratchet, #10 dead code, #9 single-subclass bases).
- explosions (claude/city-explosives), dash (claude/dash-burst), turn (option B): each in a full local suite, then one
  GPU clip -> QC 2x + motion critic. Dash burst.avi: trim first 194 frames.
- intro (claude/intro-cinematic round 9), rubble (claude/rubble-break round 4): fixing; clips to QC.
- perf (a0a59, output file stays 0 bytes, so not on the stall watcher): camera-led stream on claude/city-memory, then
  claude/perf-scans.
- Stall watcher: scratchpad stall_watch.py <id>=<name> ...; 8 min idle flag -> check Godot processes
  (scratchpad godot_ps.ps1) before acting; builders in long full suites are left off it.
- Nimbalyst (Opus High): 008 tier-4 probe running; queued 014 crowds, 015 tile multimeshes, 016 fire spread,
  017 audit P2, 018 audit P3. 001-013 results read. Review diffs before pushing anything of Nym's.

## 2026-10-22 00:20 (usage ran out mid-step)
- Tripo HUD icons (D-127, up to 3000 cr; balance was 19155, stop at 16155): driven in the BUILT-IN browser (rulebook: default,
  director "as a default always use your own browser"); local file upload is blocked there, so text prompts only. 4 free GPT Image 2.5
  croc-head refs made (studio image history 2026-10-22 00:11). I clicked "Generate HD Model" (65 cr) on ref 1 as the turn was
  stopped: CHECK whether it ran, set it Private, log a docs/provenance/tripo.md row. Still to make: dash foot, button plate; Thunder
  Beam reuses the head with our own beam FX. Builder a9c7 (intro) builds render_icon.gd + voxel digits on claude/ui-art, then 2 last
  intro fixes. Show director voxel vs smooth board.
- Text-to-motion: director picked "Soldiers and crowd" (one 20-cr clip for an action the free presets lack). Log as D-128 first.
  Report: notes tripo-motion\report.md.
- Critic FIX sent: rubble (final round), camera (frame + dither), intro (2 items, last round). UI: rings 80 px, biomass 44 px, margins
  120 px in flight; then ask director about the first-run controls card. Roadmap #47 (icons), #48 (python + Komodo heads).

- Handed off: ui a0ebed0a (recapture 04_rampage left), dash cd8614b8 (full suite unrun; tank flips; clip burst.avi, baby hidden
  in dust), turn ba70e967 (#144; stage-1 rise-point walk 10.0-13.6 s vs 10 s bar because of stepped turns; ASK director:
  DIRECTOR DECIDED 2026-10-22: "Just make the croc turn like 5% faster" -> raise the stepped-turn rates 5% in tuning.json
  on claude/turn-weight, rerun the city rise-point check (bar 10 s unchanged), log it as roadmap comment #49; clip not rendered), camera 38c76538 (head-bone framing check, full
  suite, 4K clip left), neck/audit-ci 0c5ee924 (P1 done: tuning_keys + complexity ratchet in preflight, 5 dead fns gone;
  croc-neck final), rubble 391a6626 (WIP: critic items 1-4, 6 coded, no suite or clip yet; item 5 tint jumps unfound;
  handoff in notes rubble-break\handoff.md), perf: city-memory 8747ddf6 (camera-led stream done, stage-4 nearest box
  37->60 m; full suite rerun needed) + perf-scans 010285eb (code written, suite not green, ms unmeasured). ASK director:
  landmarks hold 13192 of 24000 chunks; may out-of-view landmarks stop being always meshed? Dash depth can't be held.
  explosions 58dafcee (round-5 WIP ce8287a6; full suite, GPU clip, series.py measures left; agent-handoffs/explosives-view.md).
  PR #144 (turn, ba70e967) gdlint RED, 7 issues: gait_clip.gd:381 line >100 and file >400 lines; kaiju_model.gd:96
  animate() >4 args and file >400 lines; body_contact.gd:134 line >100, :47 class-definitions-order;
  smoke_step_turn.gd:66 line >100. The two file splits are the turn builder's job (Auto-fix is on for #144).
  ui-art builder (a9c7) was STOPPED by the director mid-task, no handoff: check ../Kaiju-Incremental-wt/ui-art for
  uncommitted render_icon.gd + voxel digits work (it was updating render_icon.gd for a new API), commit it as WIP by name,
  then finish the board. Its 2 last intro fixes (frame-57 debris pop, hand-over stutter 165-170) are also still open. Neck frame-48 "gap" = negative space (director).

## PR queue after QC (max 3 open): #144 turn-weight, emerge-shore, camera-growth, intro-cinematic, rubble-break,
## city-explosives, croc-neck, dash-burst, ui-redesign, city-memory, clumsy-army; capture-native (no speed-up: keep?).
## Audit P4 (scene refactors, pixel-identical) after the croc batch merges. No octopus/insect work until croc ships (D-124).
## After the batch: fire visuals (R 26.5, D-126), then water (R 21; Nym's 013 code map).

## NEXT
1. QC each clip as it lands (2x crops yourself, then a fresh critic; only SHIP reaches him, one decision each).
2. Director questions pending: first-run controls card; stages 2-3 far-box look stills once the camera-led stream exists.
3. Merge passing branches in queue order; Build 5 after the batch.

## Findings
- Seed-sensitive checks (swipe topple, tank standoff, tank crab, growth lots, military retreat 21/24) flip with branch
  changes to city or walk: probe the unit, fix the behaviour or re-pin the fixture, never the threshold.
- A dark patch inside a silhouette may be negative space between parts (jaw vs forearm), not a seam: trace its border.
- Release smoke must run from the repo root (relative --script path).

## Tools
- Lead docs worktree Kaiju-Incremental-wt/lead-docs (detached; git pull --ff-only first; python edits newline='';
  commit docs [skip ci], push HEAD:claude/look-options). DECISIONS.md cap 400 lines (roll to docs/archive/).
- ffmpeg: python -c "import imageio_ffmpeg;print(imageio_ffmpeg.get_ffmpeg_exe())".
- Native dll for local runs: copy Kaiju-Incremental-wt/carve-play/native/bin/*.dll into native/bin/.

Lead = "Kaiju: LEAD 10". Owns QA gates, merges, DECISIONS/STATUS, director questions, this file. playbook: nothing new.
