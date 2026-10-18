# blender-reptile handoff, 2026-10-19 00:40
## State: awaiting lead (fresh critic on round-3 clips, notes p3/round3/). PR #54 head 47b8fe6, green.
## Round 3 (lead r2: baby CLOSE, adolescent FAIL): A start = capture camera lurch from origin + t=0
## plant rings (fixed: capture camera locks to KaijuModel.focus() from f0; ClipGait _feet_primed);
## "adolescent scroll halves" not real (world cam 5.6 u/s steady). B turn_cycle 24/26 (7/9 turn steps).
## C slam_gain 6.5 (adolescent tail tip 0.08 hips at contact); soft ring thin/small/fade-in, glow 0.55.
## D roar_rest_from/_to 48/62 (adolescent); land 2.0. Probe prints tip lowest in roar.
## Renders: local, windowed, override.cfg placed in a SEPARATE call first (guard checks before run).
## Render rules (lead, director AFK): up to ~4 windowed at once; no baton.
## PR #54 head a33dc85: + RESTEP_REACH 0.98 -> 1.0 (adolescent re-stepped on every plant; pre-existing).
## Lead 19:0x: baby game-cam clip FAILED fresh critic. Fixes pushed dfcceea (suites green):
## 1/6 feet hid under the belly (planted drift was 0, turn had 5-6 steps) -> motion_test splay 10/12 m,
##   lift 0.18/0.15 (baby/adolescent), clips re-baked; 3 capture walk starts at 0.3 s (WALK_FROM);
## 5 turn tail: tail_drag() (turn rate through a 0.3 s lag, outward) replaces the accel whip: probe
##   +10..+19 deg outside, settles 0.33 s after stop, no snap; 7 ROAR_SLAM_FRAME 47 -> 44 (tip contact,
##   probe slam 14.83 s); 8 fx.shockwave(soft) for the tail: grows 0.25 s, fades 0.4 s, wide/soft/dim.
## Adult .kclip NOT re-baked (its turn keeps the old whip; ROAR_SLAM 44 applies to it too).
## SKIP per lead: 2 shared stomp arcs, 4 black frame (trim), 9 jaw hold + 10 teal/smudge -> PR body
## as after-demo polish (#62 dust likely fixes the smudge).
## NEXT in GPU turn: cp scratchpad local_ado/override.cfg to project; bash local_ado/run.sh (both stages,
## traces); rm override.cfg; message #50 local_5325ef73-4643-4477-9507-1bb17f42af5b GPU free.
## Proof to lead: walk/turn/roar 3 s + full per stage (Blender encode ev/encode_intra30.py), 2x feet crop
## at a plant, footfall-vs-ground px numbers; update PR body. D-087 (evolve1 ~15 min) is #36's, not mine.
## Post-#57 young pacing (--runs=60): evolve1 0.66 h, 12/31 defeated, 94% city (told lead; no retune).
## In-game jaw crops DONE and committed (docs/captures/2026-10-18-croctitan-stages/ingame_*): both PASS
## the lead's bar (solid, clean V corner, no flap/bridge/blocks). Sent to lead 17:2x.
## Remaining: chain b15grpqgf (bash PID 1298975, gl_compatibility 720p): jaw_adolescent rerun in flight
## (39102659504), then game-cam baby + adolescent clips -> scratchpad ci10/{baby,adolescent}. Then 3 s
## clips per stage (walk/turn/roar) to notes p3/ + the PR, SHA to lead; lead runs a fresh critic, merges.
## KILL BY PID: TaskStop left old chain scripts alive (killed 1278033, 1293452 after duplicate runs).
## D-074b in 5814b31 (stage 1 body 0.6 / 1.15; evolve1 0.71 h, 15/33 defeated, tree 4.55 h).
## Baby jaw fix 1134f93 (mouth line -87,81,-46,87.4). PR body source: scratchpad ev/pr_p3.md.
## Lead = "Kaiju: Lead" local_106fc100-d2a4-4091-bc9a-4bda31df13ac. Art to the lead only. P3 lands BEFORE #36.

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
  baby -87,81,-46,87.4 (gape line run back to the jaw hinge, 14:2x jaw fix); adolescent -79,86.8,-61,89.6. Voxel heights 100 / 130 (adult 160).
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
- TaskStop on a background bash chain left the script alive; it kept dispatching CI captures. Kill by PID.
- forward_plus on lavapipe can hang at movie recording; gl_compatibility 720p is the fast path (lead).
- Concurrent lavapipe captures double each run (25 -> 50 min) and trip the 3000 s timeout.
- A clip's fixed stride turns the game's speed straight into cadence: check hip-heights/s per stage.
- int16 cm overflows past 327 m: long baked walks need dm (the travel field).
