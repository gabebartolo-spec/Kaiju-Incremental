# blender-reptile handoff, 2026-10-18 14:30
## State: running a check. PR #54 OPEN (P3 into claude/look-options), head 1134f93, Auto-fix on, sim
## review PASS (lead). Synced look-options b810d1a; floors real (smoke 30, flow 135, growth 26); green.
## Lead jaw review 13:59: baby mouth corner flap -> FIXED 1134f93 (mouth line run to the jaw hinge
## -87,81,-46,87.4; jaw 3430 -> 3962 voxels; re-baked). Offline proxy (scratchpad jaw/open_sim.py:
## .kvox split opened 45 deg, rigid hinge) before/after in notes p3/jaw_proxy_*. Adolescent proxy clean.
## Capture chain b15grpqgf (gl_compatibility 720p: forward_plus hangs on lavapipe) waits for military-ai re-shoot AND #51 plain-stats, then jaw_baby, jaw_adolescent,
## baby, adolescent one at a time -> scratchpad ci10/. Bar (lead): 2x at roar peak, clean upper and
## lower jaw edges, no skin bridge/flap, no floating red/green blocks (adolescent: thin green shard), open jaw
## SOLID at 2x (proxy checkerboard was my rasterising; cube proxy p3/jaw_proxy_baby_after_cubes.png is solid).
## Then: crops + clips into docs/captures/2026-10-18-croctitan-stages/, edit PR body PENDING lines,
## SHA to lead; lead runs a fresh critic on the clips and merges. P3 = TOP PRIORITY, lands BEFORE #36.
## D-074b in 5814b31 (stage 1 body 0.6 / 1.15; evolve1 0.71 h, 15/33 defeated, tree 4.55 h).
## Lead = "Kaiju: Lead" local_106fc100-d2a4-4091-bc9a-4bda31df13ac. Art to the lead only.

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
- Concurrent lavapipe captures double each run (25 -> 50 min) and trip the 3000 s timeout.
- A clip's fixed stride turns the game's speed straight into cadence: check hip-heights/s per stage.
- int16 cm overflows past 327 m: long baked walks need dm (the travel field).
