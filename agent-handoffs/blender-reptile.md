# blender-reptile handoff, 2026-10-18 13:00
## State: running a check (bsbmaeg9k: full pacing at 0.6/1.15 -> /tmp/pacing_final.txt, then all
## suites -> /tmp/suites_d074b.txt; the first full run hit a 900 s timeout). Capture chain bagkdqt14
## queued behind shell-hit-hp + military-ai. P3 = TOP PRIORITY (last thing the demo build waits on).
## Director chose 0.6 / hp_mult 1.15 (D-074b: "~0.6 h unreachable at 0.6 speed; accepts ~0.71 h").
## Young sweep (--runs=60): 0.71 h, 15/33 defeated (45%), 87% city. Growth floor set to 26 (uncommitted).
## PR lands BEFORE #36 (army scales). PR body draft scratchpad ev/pr_p3.md: fill table, JAWS, CLIPS.
## Director 10:5x: baby + adolescent APPROVED (D-073). Lead = "Kaiju: Lead" local_106fc100-d2a4-...
## Art to the lead only.

## D-074 REVISED (director 11:4x via lead 12:53): speed_mult ~0.6 + more stage-1 hp, tuned in data so
## time to evolve1 stays ~0.6 h and ~half the early runs end in defeat. Re-pace; before/after table in
## the PR. Order: P3 PR lands BEFORE #36 (army scales); #36 tunes its young stage against my numbers.
## Pushed 80b8aa4 had the old 0.35 "move" section. Uncommitted now: section renamed "body"
## {speed_mult, hp_mult} (top-level default 1.0/1.0; stage 0 0.6 / hp TBD from sweep); Growth.stage_stats
## scales hp too; growth test adds an hp check (floor 25 -> 26; it FAILS at hp_mult 1.0 = shown failing).
## Baseline (x1.0): evolve1 0.58 h, 28 runs, 19/28 defeated, 94% city. Old 0.35: 0.95 h, 30/45, 37%.
## Next: pick hp_mult, full pacing run for the table, suites, commit, push BEFORE the chain reaches the
## game-cam captures (jaw captures don't depend on tuning), jaw verdict, PR (body: scratchpad ev/pr_p3.md,
## update the D-074 text + table).

## Done
- #22 (D-047 croc titan adult clips + tail + species cards) MERGED into look-options at 8065ebd.
- Follow-up for the adult (after P3, its own PR off look-options): validate the probe against footage
  with a known-bad control first (lead found screen settle 0.8 s vs probe 0.42, dip 2% snapped vs
  6% eased, slam ~0.17 s after the tail lands, no bounce). Bars: tail contact on the head-peak frame
  with a visible bounce; dust/ring held ~0.3 s at ~4x a step, visible at the game cam; dip ~5% eased
  ~0.15 s; turn settle on screen <= 0.5 s; trim the roar's dead 1.1 s; before/after aligned, no black
  first frame, a street with buildings.

## P3: croc titan baby (tier 1) + adolescent (tier 2) - branch claude/croctitan-p3 (this worktree), pushed b7cc9dd
## (synced look-options 434bb49: flow 130; my flow check lives in tests/lib/flow_demo.gd)
- GLBs (never commit): ~/Downloads/kaiju_tripo/rep_croctitan_{baby,adolescent}.glb; scratch p3/
  croctitan_baby.glb, croctitan_adolescent.glb (adolescent turned +90 deg Z by p3/rot.py).
- motion_test.py: KNOWN["CB"], ["CA"] (hand-measured on p3/grid_*.png, headgrid_*.png); per-model
  stride, cycle, bounce, tail_strides, tail_sway; walk baked as WALK_CYCLES 7 strides with
  TAIL_WALK_PERIOD = tail_strides * T; root travel stored in dm (adolescent overflowed cm).
- Data: reptilian_{baby,adolescent}.{kvox,rig.json,vskin,kclip}; test/croctitan_{baby,adolescent}
  .skin.json/.skinw/.skinf; skin_weights.json lists all three. Mouth lines (re-origined on pelvis):
  baby -87,81,-52,86.5; adolescent -79,86.8,-61,89.6. Voxel heights 100 / 130 (adult 160).
- Recipe per stage: motion_test export <vox>; rig_voxel.py <glb> assets/kaiju/<name> reptilian <vox>;
  skin_faces.py; rig_from_skin.py <kvox> <skin.json> <mouth>; motion_test clips; bake_all.sh.
- Tests: clips 14 (every stage on ClipGait); flow 130 (incl. end card's adult ClipGait + roars). New
  checks shown failing without the kclips. All suites green.
- Probe (capture_clips --probe --stage=X): baby stride cycle 0.40 s (was 0.28: stride 44 m, the
  max its legs reach), tail 1.40 s, settle 0.40 s; adolescent stride 0.91 s, tail 1.60 s.
- Evidence so far: docs/captures/2026-10-18-croctitan-stages/ (stage_board, joint_crops_2x,
  blender_walk_roar_sheet, fit_sheet), also notes blender-reptile/p3/. Sent to lead 10:45 with
  the baby-speed flag (game speed 5.5 u/s = 3.4 hip/s on the baby: a design call) and the baby
  mouth-shard nit.
- Next: when ci9 lands: 3 s game-cam clips per stage (walk/turn/roar) to notes p3/, crops, PR into
  claude/look-options ("art: ..."), body with probe numbers, SHA to lead. One self-check, nits listed.

## Rules
- Capture queue: one run at a time overall; check in_progress and queued before any dispatch.
- No new worktree (guard over limit); old local branch claude/croctitan-stages is stale (delete refused).
- LF writes (gdformat writes CRLF: normalise). Stage by name; no stash; Blender -b only.

## Findings for the lead (theirs to record)
- Concurrent lavapipe captures double each run (25 -> 50 min) and trip the 3000 s timeout.
- A clip's fixed stride turns the game's speed straight into cadence: check hip-heights/s per stage.
- int16 cm overflows past 327 m: long baked walks need dm (the travel field).
