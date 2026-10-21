# Mantis and Octopus Game-Ready Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Every task also follows `kaiju-pr`, `kaiju-proof-evidence` and, for anything visual, `art-qa-critic` (lead 2x crops, then a FRESH `motion-critic`, then the director).

**Goal:** The insectoid (mantis) and the cephalopod (octopus) play as well as the croc titan does after the demo: three stages each on hand-made Blender rigs with welded weights, authored clips for the moves a procedural gait cannot sell, their species powers animated by the body, and a director playtest of each.

**Architecture:** The croc pipeline (D-045..D-047) is generalised from "a biped" to "a body plan": `tools/blender/motion_test.py` keeps the shared load / weights / export / clips code and takes the armature and the keys from a body-plan module (biped, hexapod, radial); `.kclip` carries any number of feet; the in-game clip player is split from `ClipGait` into a body-plan-neutral `ClipPlayer` that `ClipGait` (biped), `ClipHexapodGait` and `ClipRadialGait` drive. The mantis is mostly authored (walk, dart, turn, leap, glide, perch, lay, roar) over procedural foot planting; the octopus is mostly procedural (its grips are decided by buildings at runtime) with authored layers for the mantle, the lash, the grab, the throw and the ink.

**Tech Stack:** Godot 4.7.2 GDScript (static typing), Blender 4.x `-b` Python (numpy), Tripo Studio (existing meshes), GitHub Actions captures (`tools/capture/ci_capture.sh`), `tools/run_tests.sh` suites.

**Spec:** `docs/SPECIES.md` (D-035, D-037); `docs/DECISIONS.md` D-022, D-036, D-038, D-041, D-044, D-045, D-047, D-049; the director's motion briefs in `agent-handoffs/species-motion.md` ("disturb and disgust"; "slide, push and pull, grab edges, never tip-toe; never wind-up-toy"); the croc evidence bar in `agent-handoffs/blender-reptile.md`.

## Global Constraints

- Godot 4.7.2, static typing on; `sim/` has no Node, Scene or UI dependency; presentation reads sim events and never decides outcomes (CLAUDE.md hard rule 3). Every file in this plan under `scenes/` and `tools/` is presentation or tooling.
- Determinism: every gait, twitch and physics chain draws from the rig's seeded RNG; no clock reads.
- Balance stays in data: no new tunable in code; clip timings live in the `.kclip`; the sim reads nothing new.
- gdlint: 400 lines per file, at most 4 args per function, 20 public methods. `ClipGait` is 303 lines: the split in Task 2 is required, not optional.
- Licensing: the mantis and octopus meshes are the CLEARED Tripo row in `docs/LICENSING_REGISTER.md` (line 9); no new source enters `assets/` without a row. Tripo credits are unlimited (D-023); every task logged in `docs/provenance/tripo.md`.
- Machine rules: one Blender process per task (`blender -b`), one Godot per agent, captures on CI (`ci_capture.sh --ref <branch> -f renderer=forward_plus`), never windowed Godot while the director plays. GLBs live in `~/Downloads/kaiju_tripo/`, never committed.
- PR rules (`kaiju-pr`): one PR per task below, base `claude/look-options`, body per the template, floors only up, Board and log section carries `D-TBD-*`, Auto-fix OFF, merge only the reviewed SHA. `docs/STATUS.md` and `docs/DECISIONS.md` are edited only by the merge role.
- Evidence bar (from the croc, D-047): Blender renders side + three-quarter at 640x480; foot slide per clip in cm of a 100 m body (walk <= 12, turn <= 90); worst joint bend <= 25 deg per joint on chains; a FRESH motion-critic per round; the director sees one decision per question with labelled images or a clip.
- Prerequisite: PR #22 (croc clips, `claude/croctitan-clips`) merged into `claude/look-options`. Every file this plan modifies is at its PR #22 state.

## Review Focus

Inputs the spec implies but no existing test exercises; each has its test in the task named.
1. A `.kclip` with a different foot count than the rig's gait expects (a biped file on a hexapod rig, or a v1 two-foot file): `KaijuClips.fit` must refuse with a reason, never index past the frame (Task 2).
2. A rig whose tentacle count differs from the clips' (the octopus adult has 13 chains, the adolescent and baby 10): the clips must fit per chain name and leave unmatched chains procedural, never crash (Task 11).
3. The sim turns faster than any clip: a 180 deg heading error mid-walk on the mantis must not freeze the clip, double-trigger a turn or slide the feet past `RESTEP_GAP` (Task 7).
4. A glide held past the landing, or released before the leap peaks: the body must land in the clip's land pose on `glide_land` and never stay airborne (Task 8).
5. A grab whose target vanishes (helicopter shot down mid-reach: `grab` then no `throw_land`): the tentacle must return to procedural reach within one `throw_seconds`, the carried object cleared (Task 12).

---

## Phase A: director gate and pipeline generalisation (4 tasks)

### Task 1: Director decision: models for the mantis and the octopus

**Files:**
- Create: `docs/captures/2026-10-18-mantis-octopus-models/model_board.png` (labelled board: each species, three stages, Tripo six-views side by side; built with `tools/blender/six_view.py` from the GLBs)
- Create: `docs/captures/2026-10-18-mantis-octopus-models/octopus_auto_vs_hand.mp4` (the "head detached" octopus capture beside the croc's D-045 motion-test clip, 3 s each, labelled)

**Interfaces:**
- Produces: a director decision `D-TBD-species-models` with two answers: (a) keep the approved Tripo meshes (mantis 9668b815 / 0161ad14 / 06ed8a12, octopus 8bf2f668 / a328effe / 6176590f) or redesign one; (b) the order (mantis first, recommended: its clip pipeline is the closest to the croc's). Every later task assumes (a) = keep; a redesign inserts a Tripo task like the croc's D-046/D-048 before Task 5 or Task 10 and changes nothing else.

- [ ] **Step 1: Build the board.** Run `blender -b --python tools/blender/six_view.py -- <glb> <out.png>` for the six GLBs; compose the 2x3 board with labels (species, stage, Tripo id, texture verdict from `docs/provenance/tripo.md`).
- [ ] **Step 2: Lead QA** at 2x on every tile (`art-qa-critic`): limb count, symmetry, texture artefacts, the mouth. Anything failing is noted on the board, not hidden.
- [ ] **Step 3: Ask the director** (`ask-the-director`): one question, recommended option first: "Keep the approved mantis and octopus meshes and give them the croc's hand rig (recommended: D-045 showed the bad octopus motion was our auto rig, not the mesh), or redesign <species> first?" with the board and the clip. The order question only after the first is answered.
- [x] **Step 4: Record** the answer in the next PR's Board and log as `D-TBD-species-models`; the board stays under `docs/captures/`.

**Decided (director, 2026-10-18 04:27):** keep all six approved meshes on the croc's Blender hand rig; **octopus first**. Execution order: Phase A, then Phase C (Tasks 10-12), then Phase B (Tasks 5-8), then the species-list tasks (13, 9) after the D-050 demo ships (the merge role asked that no demo file is touched before then), then Task 14.

### Task 2: `.kclip` with N feet and a body-plan-neutral `ClipPlayer`

**Files:**
- Modify: `scenes/kaiju_clips.gd` (header `feet`; frame layout computed from the header)
- Create: `scenes/clip_player.gd` (`class_name ClipPlayer extends RefCounted`: the state bookkeeping, cross-fade and blended pose lifted out of `ClipGait`)
- Modify: `scenes/gait_clip.gd` (keeps the biped decisions, foot planting, the tail spring and `or_biped`; drives a `ClipPlayer`)
- Modify: `tools/blender/motion_test.py` `clips_export()` (writes `feet`; tips and contacts per listed foot)
- Create: `tools/capture/png_diff.py` (PR #22's scratch `ev/pngdiff_game.py`, committed)
- Test: `tests/run_clips_tests.gd`

**Interfaces:**
- Consumes: `KaijuClips.read(path) -> KaijuClips`, `fit(rig: KaijuRig) -> String`, `pose_at(clip: String, t: float) -> Pose`, `KaijuClips.mix(a: Pose, b: Pose, w: float) -> Pose`, `frames_of`, `loops`, `has_clip` (PR #22).
- Produces:
  - `KaijuClips.feet: Array[String]` (foot game-bone names in frame order; a v1 file without `feet` reads as `["leg_l2", "leg_r2"]`); `Pose.tips: Array[Vector3]` and `Pose.planted: Array[bool]` sized `feet.size()` (replacing the two-foot fields). Header key `feet`; `frame_bytes = bones * 8 + 6 + 6 * feet + 2 + 4 + 2`.
  - `ClipPlayer.new(clips: KaijuClips)`; `go(clip: String, at_frame: float) -> void`; `advance(dt: float) -> void`; `pose() -> KaijuClips.Pose` (blended); `queue_once(clip: String) -> void`; `settle(moving: bool) -> void`; `state: String`, `clip_time: float`, `done: bool` (a non-looping clip at its last frame), `blend: float`. `BLEND_SECONDS := 0.25` moves here.

- [ ] **Step 1: Write the failing tests** in `tests/run_clips_tests.gd`:
  - `the croc clip file still loads with two feet`: `clips.feet == ["leg_l2", "leg_r2"]`, `pose_at("walk", 0).tips.size() == 2`.
  - `a four-foot header lays out its frames`: build a `KaijuClips` from an in-test byte array (header with `feet` of 4 names, 3 bones, 2 frames), assert `_frame_bytes == 3 * 8 + 6 + 24 + 2 + 4 + 2` and `pose_at(clip, 1).planted[3] == true`.
  - `clips for other feet than the rig's do not fit` (Review Focus 1): `fit(croc_rig)` with a header `feet` of 4 names returns a non-empty string containing `"feet"`.
  - `the clip player plays a one-shot and settles`: `ClipPlayer` on the croc clips, `queue_once("roar")`, advance past `frames_of("roar") / fps`, `settle(false)`, assert `state == "idle"` and `blend == 1.0` within `BLEND_SECONDS`.
- [ ] **Step 2: Run** `GODOT=<godot> tools/run_tests.sh clips`. Expected: FAIL (no `feet`, no `ClipPlayer`).
- [ ] **Step 3: Implement** `feet` in `KaijuClips._load` (default when absent), the `Pose` arrays, `fit` comparing `feet` with the rig's bones; `ClipPlayer` with the signatures above (moved from `ClipGait`: `_go`, `_from/_from_time/_blend`, the `mix` call); `ClipGait.update` becomes `track`, `_choose` (biped decisions), `player.advance`, `_apply(player.pose())`, `_plant_feet`, `_swing_tail`.
- [ ] **Step 4: Update** `clips_export()` to write `feet` (biped `["leg_l2", "leg_r2"]`) and loop tips/contacts over the module's foot list; re-export the croc (`blender -b --python tools/blender/motion_test.py -- <croc glb> <scratch> C clips`) and `cmp` the frame bytes after the header against `assets/kaiju/reptilian_adult.kclip`: identical.
- [ ] **Step 5: Run** `tools/run_tests.sh clips smoke` and gdlint. Expected: PASS; clips floor 13 -> 17; every file under 400 lines.
- [ ] **Step 6: Evidence**: CI `tools/capture/capture_clips.gd --cam=game` on the croc before and after, `png_diff.py` per frame: the croc's motion is unchanged (max per-frame diff 0 outside the HUD clock).
- [ ] **Step 7: Commit and open the PR** `tools: clips carry any number of feet; ClipPlayer split from ClipGait`, the diff plot in Evidence, "Not exercised: hexapod and radial players (Tasks 7, 11)".

### Task 3: `motion_test.py` takes its armature from a body-plan module

**Files:**
- Create: `tools/blender/bodyplans/__init__.py`, `tools/blender/bodyplans/biped.py` (the current `BONES`, `KNOWN`, IK setup, `pose_frame`, `path`, `tail_*`, `GAME_BONES`, `GAME_CLIPS`, `game_bone()` moved verbatim)
- Modify: `tools/blender/motion_test.py` (new positional arg `plan` = `biped | hexapod | radial`, default `biped`; keeps load/normalise, `weights_for`, `export`, `clips_export`, render, measure, crops, diff, fit report)
- Modify: `tools/kaiju_skin/rig_from_skin.py` (`GAME_BONES` read from `<x>.skin.json` key `game_bones`, biped list when absent; `rig.json "type"` from `body_plan`)
- Create: `tools/blender/test_bodyplans.sh`

**Interfaces:**
- Produces the body-plan module contract; each module exports: `KNOWN: dict`, `LANDMARK_KEYS: list[str]`, `build_bones(L) -> list[tuple]` (name, head, tail, parent, up, deform), `setup_constraints(rig)`, `pose_frame(clip, f, P)`, `path(clip)`, `GAME_BONES: list[str]`, `GAME_CLIPS: list[tuple]`, `FEET: list[tuple[str, str]]` (game foot bone, Blender tip bone), `game_bone(blender_name) -> str`, `JAW: str | None`.
- Produces: `<stem>.skin.json` gains `"game_bones": [...]` and `"body_plan": "<plan>"`.

- [ ] **Step 1: Write the check script** `tools/blender/test_bodyplans.sh`: runs `motion_test.py` tasks `export` and `clips` for the croc (`C`, `plan=biped`) into a scratch dir and `cmp`s the `.skinw` and every `.kclip` frame after the header against `assets/kaiju/test/croctitan.skinw` and `assets/kaiju/reptilian_adult.kclip`; exits 1 on any difference.
- [ ] **Step 2: Run it.** Expected: FAIL (unknown argument `biped`).
- [ ] **Step 3: Move** the biped code into `bodyplans/biped.py`; `motion_test.py` does `PLAN = importlib.import_module(f"bodyplans.{plan}")` and calls the contract; `export()` writes `game_bones` and `body_plan`.
- [ ] **Step 4: Run** `tools/blender/test_bodyplans.sh`. Expected: PASS (byte-identical weights and frames).
- [ ] **Step 5: Run** `rig_from_skin.py assets/kaiju/reptilian_adult.kvox assets/kaiju/test/croctitan.skin.json -90.5,82.5,-58,87` into a scratch copy; `diff` the `rig.json` against the committed one: identical.
- [ ] **Step 6: Commit and open the PR** `tools: motion_test takes a body-plan module (biped unchanged)`; Evidence = the script's output; floors unchanged.

### Task 4: Hexapod and radial gaits guard their bones; `rig_from_skin` gathers per plan

**Files:**
- Modify: `tools/kaiju_skin/rig_from_skin.py` (a game bone's chain is its `gathers` list from the skin header, not the biped neighbour rule; the mouth arg ignored for `hexapod` and `radial`)
- Modify: `scenes/gait_hexapod.gd`, `scenes/gait_radial.gd` (`_init` checks every bone it poses exists; `push_warning` and skip otherwise)
- Test: `tests/run_smoke_tests.gd`

**Interfaces:**
- Consumes: today's `rig.json` bone lists (hexapod 32 bones; radial `mantle0` + `tentacle<i>_<j>`).
- Produces: `rig_from_skin.py <name.kvox> <x.skin.json> [mouth]` for any `body_plan`.

- [ ] **Step 1: Write the smoke checks** `every bone the hexapod gait poses exists on the insectoid rigs` (iterate `HexapodGait.LEGS` x `0..2`, `thorax0/1`, `abdomen0..2`, `head0`, `arm_l/r 0..2`, `mandible_l/r`, `antenna_l/r 0..2`) and `every chain root the radial gait reads exists on the cephalopod rigs`. Run `tools/run_tests.sh smoke`: PASS already on the auto rigs; these guard the hand rigs of Tasks 6 and 11.
- [ ] **Step 2: Implement** the gathering change and the `_init` guards.
- [ ] **Step 3: Run** `tools/run_tests.sh smoke` and `tools/blender/test_bodyplans.sh`. Expected: PASS; smoke 27 -> 29.
- [ ] **Step 4: Commit and open the PR** `tools: rig_from_skin gathers bones per body plan`.

## Phase B: the mantis (insectoid), authored over procedural (5 tasks)

Motion brief (director, D-022/D-038, species-motion handoff): it must "disturb and disgust": hard holds then darts, nothing eases, twitches at rest, exoskeletal snaps; the roar rears and flares the scythes and mandibles. Powers (SPECIES.md): scuttle, leap then hold-to-glide, climb (perch on a tower, the weight topples it), Brood (eggs laid, elephant-sized young).

Authored vs procedural split (locked here):

| Move | Owner | Why |
|---|---|---|
| idle (twitch bed) | clip `idle` (72 f loop) + `HexapodUpper` twitches on top | authored breathing and abdomen pulse; twitches stay random and seeded |
| walk / skitter | clip `walk` (one dart cycle, 4 feet, loop) + procedural foot locking and catch steps | authored leg timing sells "insect"; planting keeps feet off the slide |
| hold | `ClipHexapodGait` freezes the walk clip for `HOLD` seconds | holds are a gait decision; the clip cannot know when |
| turn on the spot | clip `turn_left` (+ mirrored `turn_right`) | the croc's method |
| leap | clip `leap` (crouch, launch, tuck), non-loop | a leap must coil first |
| glide | clip `glide` (loop: legs tucked, scythes forward, abdomen raised) | held while `sim.airborne` |
| land | clip `land` (splay, crush, recover) | on `glide_land` |
| perch / climb | clip `perch` (loop: low wide coiled stance, scythes half up) | `climbing(on)` |
| lay eggs | clip `lay` (abdomen down-curl pulse x3) | on `eggs_laid` |
| roar | clip `roar` (rear, flare, spasm end) | authored; `HexapodUpper`'s flare bypassed |
| scythe strike | procedural (`HexapodUpper` lash) | target-aimed; a clip cannot aim |
| antennae | physics chain (`physics: true`) | as today |

### Task 5: Mantis hand rig and welded weights (Blender)

**Files:**
- Create: `tools/blender/bodyplans/hexapod.py`
- Create: `assets/kaiju/test/mantis_{baby,adolescent,adult}.skin.json`, `.skinw`, `.skinf` (`export` task, then `tools/kaiju_skin/skin_faces.py`)
- Create: `docs/captures/2026-10-19-mantis-rig/fit_sheet_<stage>.png`, `weights_sheet_<stage>.png`, `flex_<stage>.png`

**Interfaces:**
- Produces `hexapod.py`: `KNOWN["MA" | "MJ" | "MB"]` (adult / adolescent / baby) landmarks `spine` (abdomen tip, thorax, neck), `head`, `mandible`, `arm` (coxa, femur, tibia, claw tip; left), `leg_front` and `leg_hind` (coxa, femur, tibia, tarsus, tip; left), `antenna` (base, tip); `build_bones` emitting deform bones `thorax0/1, head, abdomen0..2, legF_{L,R}_{coxa,femur,tibia,tarsus}, legH_*, arm_{L,R}_{coxa,femur,tibia}, antenna_{L,R}_0..2, mandible_{L,R}` plus non-deform `foot_ctrl_{F,H}_{L,R}`, `knee_pole_*`, `claw_tgt_{L,R}`; `GAME_BONES` = the 32 names in `assets/kaiju/insectoid_adult.rig.json` order; `FEET = [("leg_l2", "tarsus_F_L"), ("leg_r2", "tarsus_F_R"), ("hind_l2", "tarsus_H_L"), ("hind_r2", "tarsus_H_R")]`; `JAW = None`.

- [ ] **Step 1: Landmarks.** Per stage GLB (`~/Downloads/kaiju_tripo/mantis_{adult,adolescent,baby}_tex.glb`), run `motion_test.py <glb> <out> MA fit hexapod` with auto landmarks; correct `KNOWN` by hand until every joint sits inside the mesh at the real pivot.
- [ ] **Step 2: Fit sheet.** Task `fit` renders bones over the see-through mesh, side and front. Lead QA at 2x: coxae on the thorax, tibia and tarsus joints at the visible knee bends, scythe hinge at the femur-tibia bend, mandible hinges at the head.
- [ ] **Step 3: Weights.** `weights_for` with hexapod regions (thorax, abdomen, each leg by its own chain, scythes, head, mandibles, antennae); export; `skin_faces.py` for `.skinf`. Render the weights sheet (each bone a flat colour) and a flex test (every joint bent 40 deg): no island, no tearing at coxa-thorax, the abdomen does not pull the hind legs.
- [ ] **Step 4: Verify** `python tools/blender/verify_skin.py <skin.json>` for all three stages; `bone_sheet.py` fragments 0.
- [ ] **Step 5: PR** `art: mantis hand rig and welded weights (3 stages)`: fit, weight and flex sheets, the three `assets/kaiju/test/mantis_*` sets. "Not exercised: in-game (Task 6)".

### Task 6: Mantis skins in the game (three stages)

**Files:**
- Modify: `assets/kaiju/insectoid_{baby,adolescent,adult}.kvox`, `.rig.json`, `.vskin` (rebuilt)
- Modify: `docs/LICENSING_REGISTER.md` line 9 (the build column names `rig_from_skin.py` beside `rig_voxel.py`)
- Test: `tests/run_smoke_tests.gd` (Task 4's bone checks now run on the hand rigs)

**Interfaces:**
- Consumes: Task 5 skins; `rig_voxel.py` for voxels and colours only: `blender -b --python tools/blender/rig_voxel.py -- <glb copy> assets/kaiju/insectoid_<stage> insectoid <100 | 130 | 160> 0`, then `rig_from_skin.py <kvox> <skin.json>`, then `GODOT=<godot> bash tools/kaiju_skin/bake_all.sh`.
- Produces: `insectoid_<stage>.rig.json` with `"type": "hexapod"` and the 32 bones in today's names and order, so `HexapodGait` and `HexapodUpper` run unchanged.

- [ ] **Step 1: Rebuild** the three stages (voxel heights 100 / 130 / 160, today's `rig.json "height"`).
- [ ] **Step 2: Run** `tools/run_tests.sh smoke tentacles powers`. Expected: PASS (smoke's skin-drift check reads the new `.vskin`).
- [ ] **Step 3: Capture** BEFORE (auto rig, `origin/claude/look-options`) and AFTER on CI: `tools/capture/capture_motion.gd --cam=game` 20 s walk / turn / roar on the procedural gait, plus `--tint`. Lead 2x crops: coxa joints at full step, scythe hinge at the strike, mandibles at the roar, abdomen at the pulse; the ownership sheet shows no leg voxels owned by the thorax.
- [ ] **Step 4: Fresh `realism-critic`** on stills, fresh `motion-critic` on the clips (this round judges the SKIN, not the motion).
- [ ] **Step 5: PR** `art: mantis on the Blender hand rig (3 stages)`; Evidence = before/after sheet, crops, critic verdicts; Board and log: the register row.

### Task 7: `ClipHexapodGait` and the mantis idle / walk / turn / roar clips

**Files:**
- Modify: `tools/blender/bodyplans/hexapod.py` (`pose_frame`, `path`, `GAME_CLIPS` for `idle`, `walk`, `turn`, `roar`)
- Create: `assets/kaiju/insectoid_{baby,adolescent,adult}.kclip`
- Create: `scenes/gait_clip_hexapod.gd` (`class_name ClipHexapodGait extends HexapodGait`)
- Modify: `scenes/kaiju_rig.gd` (gait choice: `ClipHexapodGait.or_hexapod(rig, clips)` beside `ClipGait.or_biped`)
- Modify: `scenes/gait_hexapod.gd` (`plant(leg, land)` and `lift(leg, seconds, shift)` made public for the clip gait)
- Modify: `tools/capture/capture_clips.gd` (`--species=insectoid`)
- Test: `tests/run_clips_tests.gd`

**Interfaces:**
- Consumes: `ClipPlayer` (Task 2); `KaijuClips.feet` (4 for the mantis).
- Produces: `ClipHexapodGait.or_hexapod(p_rig: KaijuRig, p_clips: Variant) -> KaijuGait`; `update(delta: float)`; `roar()`; `hold_for(seconds: float) -> void` (freezes the walk at its frame); `stride() -> float`; public `player: ClipPlayer`, `walk_cycles: float`. `HexapodUpper` keeps twitches and strikes; its roar `display` is bypassed while `roar` plays.
- Clip acceptance (`motion_test.py` task `measure`, 100 m body): walk foot slide <= 8 cm per planted foot; dart travel per cycle = `stride_m` within 2 %; hold frames have body travel 0.0000; turn yaw 90 deg in <= 0.3 s (adult) with a foot in the air before the body turns; roar rears the thorax >= 25 deg and flares both scythes >= 60 deg from rest, ends in a spasm not a hold; worst bend <= 25 deg per joint; antennae not keyed.

- [ ] **Step 1: Write the failing tests** in `tests/run_clips_tests.gd`:
  - `the mantis adult moves by its clips`: `rig.gait is ClipHexapodGait`.
  - `a mantis hold freezes the walk clip`: `hold_for(0.3)`, advance 0.3 s at walking speed; `player.clip_time` unchanged, all four locked feet unchanged.
  - `a mantis walk plants four feet without slide`: 4 s straight walk at adult speed; `foot_drift() <= 0.08 * hip_height`.
  - `a sharp sim turn mid-walk keeps the feet under RESTEP_GAP` (Review Focus 3): `model_yaw` 180 deg from `body_yaw` while moving; after 1 s every planted foot is within `RESTEP_GAP` strides of its clip spot and `player.state == "walk"`.
  - `the mantis roar plays once and settles`: `roar()`, advance past `frames_of("roar") / fps`; `player.state == "idle"`.
- [ ] **Step 2: Run** `tools/run_tests.sh clips`. Expected: FAIL (no clip file, no class).
- [ ] **Step 3: Author the clips** in `hexapod.py` (the walk as a dart: two diagonal foot pairs, each swing `SWING_DART` 0.075 s of frames, body pitch-down `DART_PITCH` on launch, abdomen counter-curl); export per stage, one Blender process per clip: `blender -b --python tools/blender/motion_test.py -- <glb> assets/kaiju MA clips hexapod <clip>` (the tool appends to the stage's `.kclip`).
- [ ] **Step 4: Measure** with task `measure` (and a `chain_stats` task for the abdomen, the tail task renamed for any chain); iterate until every acceptance line passes; keep the numbers for the PR.
- [ ] **Step 5: Implement** `ClipHexapodGait` (`_choose` with `hold_for` reusing `HexapodGait`'s hold timer; `_plant_feet` over `clips.feet.size()` feet via `plant/lift`; `_apply` sets every clip bone except antennae; `HexapodUpper.update` runs after with `calm` from the clip state).
- [ ] **Step 6: Run** `tools/run_tests.sh clips smoke`; gdlint. Expected: PASS; clips floor 17 -> 22.
- [ ] **Step 7: Evidence**: Blender renders side + three-quarter per clip per stage; CI `capture_clips.gd --species=insectoid --cam=game` BEFORE (procedural) and AFTER (clips), `png_diff.py`, 2x crops of feet at contact and scythes at the roar peak; `tools/capture/screen_motion.py` holds-vs-darts contrast >= 4.6x (species-motion's r3c bar). Lead QA, fresh motion-critic, then the director sees one labelled clip.
- [ ] **Step 8: PR** `art: mantis idle, walk, turn and roar from Blender clips`; "Not exercised: leap, glide, perch, lay (Task 8)".

### Task 8: Mantis power clips: leap, glide, land, perch, lay

**Files:**
- Modify: `tools/blender/bodyplans/hexapod.py` (`leap`, `glide`, `land`, `perch`, `lay`)
- Modify: `assets/kaiju/insectoid_*.kclip` (the five clips appended)
- Modify: `scenes/gait_clip_hexapod.gd` (`leap()`, `glide(on: bool)`, `land()`, `climbing` override, `lay()`)
- Modify: `scenes/kaiju_model.gd` (hooks `leap()`, `glide(on: bool)`, `lay_eggs()`, no-ops on other bodies, the `climbing(on)` pattern at `kaiju_model.gd:154`)
- Modify: `scenes/powers_view.gd` (`glide_start` -> `_hook("leap", [])` then `_hook("glide", [true])`; `glide_land` -> `_hook("glide", [false])` + `_hook("land", [])`; `eggs_laid` -> `_hook("lay_eggs", [])`; the leap ability without a hold -> `leap` + `land`)
- Test: `tests/run_clips_tests.gd`, `tests/run_powers_tests.gd`

**Interfaces:**
- Consumes: sim events `glide_start`, `glide_land {reach}`, `eggs_laid {at}`; `sim.airborne`; `sim.stand_y`.
- Produces: `KaijuModel.leap() -> void`, `glide(on: bool) -> void`, `lay_eggs() -> void`; `ClipHexapodGait` states `leap`, `glide`, `land`, `perch`, `lay`.
- Clip acceptance: leap crouch >= 0.15 s before launch and all four feet leave contact within 2 frames of each other; glide loops seamlessly (frame 0 vs last <= 0.5 deg per bone); land: contacts within 1 frame of each other, thorax drops >= 20 % of hip height and recovers in <= 0.4 s; perch keeps every foot planted; lay: the abdomen tip reaches ground height three times within `hatch_seconds` (2.0 s, `data/tuning.json`).

- [ ] **Step 1: Write the failing tests**:
  - `a glide held past landing lands in the land pose` (Review Focus 4): `glide(true)`, then `glide(false)` + `land()` on the same frame; after `frames_of("land")` the state is `idle` and no foot is above ground + `RESTEP_LIFT`.
  - `a glide released before the peak still lands`: `leap()`, `glide(true)` for 0.1 s, `glide(false)`; the state goes `leap` -> `land` -> `idle`.
  - `perch holds every foot planted`: `climbing(true)` for 2 s; every foot planted every frame.
  - `laying eggs curls the abdomen three times`: sign changes of `abdomen2` pitch over the clip >= 6.
  - `run_powers_tests.gd`: `the powers view asks the body to leap and glide`: a stub kaiju with the three methods records the calls on `glide_start` and `glide_land`.
- [ ] **Step 2: Run** `tools/run_tests.sh clips powers`. Expected: FAIL.
- [ ] **Step 3: Author, export, measure** the five clips per stage (Task 7 steps 3-4).
- [ ] **Step 4: Implement** the gait states, the model hooks, the view hooks.
- [ ] **Step 5: Run** `tools/run_tests.sh clips powers smoke`; gdlint. Expected: PASS; clips 22 -> 26, powers 24 -> 25.
- [ ] **Step 6: Evidence**: CI `tools/capture/capture_powers.gd --species=insectoid`: a leap, a hold-to-glide across a street, a perch on a tower until it topples, eggs then hatchlings; 3 s clips each at the game camera; 2x crops of feet at landing and the abdomen at laying. Lead QA, fresh motion-critic, director decision "the mantis moves like this" (one clip, four moves labelled).
- [ ] **Step 7: PR** `art: mantis leap, glide, perch and brood clips`.

### Task 9: Mantis species-select card, stages board and pacing check

**Files:**
- Modify: `data/tuning.json` (`demo.species` gains `"insectoid"`; the key the demo's P5 adds)
- Create: `docs/captures/2026-10-2x-mantis-stages/stages_board.png` (baby / adolescent / adult side by side at the game camera, labelled)
- Test: `tests/run_flow_tests.gd`

- [ ] **Step 1: Write the failing flow check** `the species select shows every allowed species`: with `demo.species == ["reptilian", "insectoid"]` two cards exist.
- [ ] **Step 2: Run** `tools/run_tests.sh flow`. Expected: FAIL (one card).
- [ ] **Step 3: Add** `insectoid` to `demo.species`.
- [ ] **Step 4: Run** `tools/run_tests.sh flow`, then `godot --headless --path . --script tools/pacing.gd -- --species=insectoid`: hours to complete within D-049's 3.26 h +- 20 % (no balance change in this plan; a drift is reported in the PR, not fixed).
- [ ] **Step 5: Evidence**: 4K species-select still (`tools/capture/capture_screens.gd`; the mantis head no longer cut, PR #22's nit), the stages board, the pacing table. Lead QA, fresh screen-critic.
- [ ] **Step 6: PR** `data: the mantis joins the playable species`; Board and log: `D-TBD-mantis-game-ready` for the playtest verdict (Task 14).

## Phase C: the octopus (cephalopod), procedural with authored layers (4 tasks)

Motion brief (director, D-036, species-motion handoff): "slide, push and pull, grab edges, never tip-toe; never wind-up-toy"; "limbs like the heads of a hydra"; the auto-rig capture was rejected ("head detached, limbs a static, awkward mesh"). Powers: 360 hydra limbs, grab and throw (tanks, cars, helicopters), push/pull/climb/squeeze, Corrosive Ink.

Authored vs procedural split (locked here):

| Move | Owner | Why |
|---|---|---|
| crawl (reach, grip, surge, drag) | procedural `RadialGait` on the hand-rig weights | grips are chosen by the city at runtime |
| mantle breath, head, eyes | clip `idle` (loop) layered on `mantle0` and `head` only | authored life in the body while the limbs work |
| lash (ring attack) | clip `lash` (every tentacle whips out and back, 0.6 s) on every tentacle not gripping | a whole-body whip reads only when all limbs move together |
| grab | clip `grab` on ONE tentacle (reach, close, lift), the tip pinned by IK to the target | the clip gives the coil and the lift; IK gives the target |
| throw | clip `throw` on that tentacle (wind back, snap), release at the snap frame | timed to `throw_seconds` (0.7 s) |
| ink | clip `ink` (mantle contracts, head drops, siphon pulse) | mantle only; tentacles keep crawling |
| squeeze | procedural (`RadialGait` contracts the ring) | driven by the sim's gap width |
| roar | clip `roar` (mantle puffs, every tentacle rears) | authored; `RadialGait`'s ripple bypassed |
| climb (edge pull-up) | procedural grips (existing) | as crawl |

### Task 10: Octopus hand rig and welded weights (Blender)

**Files:**
- Create: `tools/blender/bodyplans/radial.py`
- Create: `assets/kaiju/test/octopus_{baby,adolescent,adult}.skin.json`, `.skinw`, `.skinf`
- Create: `docs/captures/2026-10-2x-octopus-rig/fit_sheet_<stage>.png`, `weights_sheet_<stage>.png`, `flex_<stage>.png`

**Interfaces:**
- Produces `radial.py`: `KNOWN["OA" | "OJ" | "OB"]` landmarks `mantle` (base, crown), `head` (centre, beak), `eye` (left), `tentacles` (N polylines, root on the ring, 6 joints each, traced on the mesh; N per model as today's `rig.json`: adult 13, adolescent 10, baby 10); `build_bones` emitting `mantle0`, `head`, `tentacle<i>_<0..5>` deform bones plus non-deform `tip_ctrl_<i>` (6-bone IK); `GAME_BONES` = today's `rig.json` order plus `head` (new; `RadialGait` ignores bones it does not pose); `FEET = []`; `JAW = None`; `LAYERS: dict` (clip -> game bones it touches: `idle: [mantle0, head]`, `ink: [mantle0, head]`, `lash` and `roar`: every tentacle + mantle, `grab` and `throw`: `tentacle0_*`, re-targeted at play time).
- Produces: `.kclip` header key `layers` (clip -> bone list); `KaijuClips.layers(clip: String) -> Array[String]` (empty = every bone).

- [ ] **Step 1: Landmarks and fit** per stage as Task 5 steps 1-2; each tentacle's six joints lie on the mesh's medial line (the fit report prints the worst joint-to-centre-line distance per chain; <= 3 % of body height).
- [ ] **Step 2: Weights** with radial regions: mantle, head, each tentacle by geodesic distance from its own chain with a tapered bound (species-motion's lesson: tentacles never own head voxels). Flex test: every tentacle curled 60 deg per joint; no mantle tearing at the roots; the head stays attached (the director's defect).
- [ ] **Step 3: Verify** `verify_skin.py`; `bone_sheet.py` fragments 0, slate islands 0, unchained runs 0.
- [ ] **Step 4: PR** `art: octopus hand rig and welded weights (3 stages)` with fit, weight and flex sheets.

### Task 11: Octopus skins in the game and `ClipRadialGait` layers

**Files:**
- Modify: `assets/kaiju/cephalopod_{baby,adolescent,adult}.kvox`, `.rig.json`, `.vskin` (rebuilt as Task 6, species `cephalopod`)
- Create: `assets/kaiju/cephalopod_*.kclip` (`idle`, `roar`)
- Create: `scenes/gait_clip_radial.gd` (`class_name ClipRadialGait extends RadialGait`)
- Modify: `scenes/kaiju_clips.gd` (`layers`), `scenes/kaiju_rig.gd` (`ClipRadialGait.or_radial`)
- Modify: `scenes/gait_radial.gd` (`Arm.authored: bool` the procedural reach skips; mantle breathe and roar ripple skipped while a layer owns `mantle0`)
- Test: `tests/run_clips_tests.gd`, `tests/run_tentacles_tests.gd`

**Interfaces:**
- Produces: `ClipRadialGait.or_radial(p_rig: KaijuRig, p_clips: Variant) -> KaijuGait`; `play_layer(clip: String, arm: int = -1) -> void` (arm = the tentacle index the clip's `tentacle0_*` bones map to; -1 = the clip's own bones); `update(delta)`: `RadialGait.update` first, then every active layer's pose applied to its bones only; `roar()` plays `roar`.
- `KaijuClips.fit` for a radial rig: matches `mantle0`, `head` and each `tentacle<i>_<j>` by name; chains the rig has and the clips lack stay procedural; chains the clips have and the rig lacks refuse with the chain name (Review Focus 2).

- [ ] **Step 1: Write the failing tests**:
  - `the octopus adult crawls by RadialGait with clip layers`: `rig.gait is ClipRadialGait`.
  - `clips for fewer tentacles than the rig fit and leave the rest procedural` (Review Focus 2): a 10-chain header on the 13-chain adult: `fit` returns "" and `arms[10..12].authored == false` after `play_layer("lash")`.
  - `clips for a tentacle the rig lacks do not fit`: a 13-chain header on the baby: a reason containing `tentacle12`.
  - `an idle layer moves the mantle while the arms crawl`: 2 s walk; `mantle0` pitch range > 0.01 rad and at least one arm reached.
  - `run_tentacles_tests.gd`: the 18 existing checks pass on the hand rig (regression guard, no new check).
- [ ] **Step 2: Run** `tools/run_tests.sh clips tentacles`. Expected: FAIL.
- [ ] **Step 3: Rebuild** the three stages; author and export `idle` (72 f mantle breath, a blink via `head`, loop) and `roar` (mantle puffs 15 %, every tentacle rears 45 deg at the root in 0.25 s, settles in 0.5 s).
- [ ] **Step 4: Implement** `layers`, `ClipRadialGait`, `Arm.authored`.
- [ ] **Step 5: Run** `tools/run_tests.sh clips tentacles smoke`; gdlint. Expected: PASS; clips 26 -> 30.
- [ ] **Step 6: Evidence**: CI capture BEFORE (auto rig) / AFTER (hand rig + idle layer): 20 s crawl through a block with building-edge grips (species-motion's open item 2), `--tint` ownership, 2x crops: the head-to-mantle join at the surge, a tentacle root at full reach, a grip on a corner. Fresh realism-critic (stills) and motion-critic (clip). The director sees one labelled before/after clip: "head attached, limbs alive".
- [ ] **Step 7: PR** `art: octopus on the Blender hand rig with idle and roar layers`.

### Task 12: Octopus grab, throw, lash and ink layers

**Files:**
- Modify: `tools/blender/bodyplans/radial.py` (`lash`, `grab`, `throw`, `ink`)
- Modify: `assets/kaiju/cephalopod_*.kclip`
- Modify: `scenes/gait_clip_radial.gd` (`grab(limb_hint, at)` and `throw(toward)` override `RadialGait`'s: the layer on the chosen arm, the tip pinned to `at` through the hold frames, release at the snap frame; `lash()`; `ink()`)
- Modify: `scenes/kaiju_model.gd` (`lash()`, `ink()` hooks, no-ops elsewhere)
- Modify: `scenes/powers_view.gd` (`limb` event -> `_hook("lash", [])` once per `limb_interval`; `ink` -> `_hook("ink", [])`; `_thrown` keeps its tween, the tip comes from the layered arm)
- Test: `tests/run_clips_tests.gd`, `tests/run_tentacles_tests.gd`

**Interfaces:**
- Consumes: sim events `limb {limb, at}`, `grab {kind, from, to}`, `throw_land {kind, at, radius}`, `ink {reach}`; `data/tuning.json powers`: `throw_seconds` 0.7, `grab_cooldown` 2.5, `limb_interval` 0.7, `ink_seconds` 4.0; `PowersView.REACH_SHARE` 0.43 and `LIFT_SHARE` 0.22.
- Produces: `KaijuModel.lash() -> void`, `ink() -> void`; `ClipRadialGait.grab / throw / lash / ink`.
- Clip acceptance: lash: every free tip travels >= 1.5 x its rest reach and returns within 0.6 s, no tip passes through the mantle; grab: the tip within 0.03 rig units x scale of `at` from the hold frame to the release; carried height `HOLD_HEIGHT`; throw: release at `(REACH_SHARE + LIFT_SHARE) * throw_seconds`; ink: mantle contracts >= 20 % at the pulse, head drops, over in <= 0.5 s, then the idle layer resumes.

- [ ] **Step 1: Write the failing tests**:
  - `a grab layer pins the tip to the target`: `grab(0, at)`; through the hold frames `limb_tip(0)` is within 0.03 of `at`.
  - `a throw releases at the snap frame`: `throw(toward)`; `limb_tip(0)` leaves `at` toward `toward` no earlier than the release frame; `arms[0].authored` clears at the clip's end.
  - `a grab whose throw never comes returns to procedural` (Review Focus 5): `grab(0, at)` and no `throw` for `throw_seconds + 0.1`: `arms[0].authored == false`, `limb_tip(0)` back at ground height.
  - `a lash whips every free tentacle`: with arm 0 gripping, `lash()`; arms 1..N reach >= 1.5 x rest reach, arm 0 stays on its grip.
  - `ink contracts the mantle and ends`: `ink()`; `mantle0` pulses and returns within 0.5 s.
- [ ] **Step 2: Run** `tools/run_tests.sh clips tentacles`. Expected: FAIL.
- [ ] **Step 3: Author, export, measure** the four clips per stage.
- [ ] **Step 4: Implement** the overrides, the hooks, the view changes.
- [ ] **Step 5: Run** `tools/run_tests.sh clips tentacles powers smoke`; gdlint. Expected: PASS; clips 30 -> 35.
- [ ] **Step 6: Evidence**: CI `capture_powers.gd --species=cephalopod`: a tank grabbed and thrown into a tower, a helicopter plucked from the air, a lash in a crowded block, ink on a building that dissolves; 3 s clips each; 2x crops of the holding tip with the tank, the release frame, the mantle at the ink pulse. Lead QA, fresh motion-critic, director decision (one clip, four moves labelled).
- [ ] **Step 7: PR** `art: octopus grab, throw, lash and ink layers`.

### Task 13: Octopus species-select card, stages board and pacing check

The shape of Task 9 for `cephalopod`: `demo.species` gains `"cephalopod"`, the flow check expects three cards, the 4K card still shows no clipped tentacle (PR #22 set its distance to 16.1), the stages board, pacing within D-049's 3.70 h +- 20 %. PR `data: the octopus joins the playable species`; Board and log: `D-TBD-octopus-game-ready`.

## Phase D: director playtests and close-out (1 task)

### Task 14: The director plays each species; only blocking notes are fixed

**Files:**
- Modify: `agent-handoffs/lead.md` and the species' handoffs (rewrite, 120-line cap)
- Create: `docs/captures/2026-10-2x-species-playtest/<species>_notes.md` (the director's words verbatim, one line each, the fix PR beside those fixed)

- [ ] **Step 1: Windows export** from `claude/look-options` (the demo's P6 method) with both species in `demo.species`.
- [ ] **Step 2: The director plays** the mantis, then the octopus, from title to the first evolution each.
- [ ] **Step 3: Triage**: every note logged; a note that stops the species being played (a broken move, a crash, a card that does not open) gets a fix PR with the croc's evidence bar; taste notes queue for the next decision.
- [ ] **Step 4: Board and log**: `D-TBD-mantis-game-ready` and `D-TBD-octopus-game-ready` recorded by the merge role; PR #11 closed unmerged (its findings are folded into Tasks 7 and 11); `species-motion` and `kaiju-motion` handoffs closed; `bash tools/lint/worktrees.sh` shows <= 4 live worktrees.

## Extra consideration: why the animation is harder here, and what the plan does about it

1. **More contacts.** The mantis plants four feet (the croc two) and `.kclip` v1 hard-codes two. Task 2 makes the foot count data so the exporter and the gait agree by header, and refuses mismatches instead of misreading bytes.
2. **Two body plans in one tool.** `motion_test.py` builds one biped armature at import time. Task 3 moves the armature into a module and proves the croc re-exports byte-identically before any insect bone exists, so a later defect belongs to the new module, never to the shared code.
3. **Clips cannot know the city.** The octopus grips and the mantis perch depend on buildings at runtime. The croc's "clip plus procedural foot planting" becomes "clip layers over a procedural gait" for the octopus (Task 11 `layers`) and "clip with gait-owned holds and perches" for the mantis (Task 7 `hold_for`). The split tables lock which side owns each move, so nobody authors a clip for a move the city decides.
4. **Many chains.** 13 tentacles x 6 bones = 79 bones, and the stages differ in count. Task 11 fits per chain name and leaves extra chains procedural; the per-arm `authored` flag keeps the two systems from fighting over one bone.
5. **The director's bar is motion, not stills** (memory `original-not-godzilla`). Every visual task ends with a FRESH motion-critic on a game-camera clip at game speed, and the director gets one decision per species per phase (skin, locomotion, powers), never a wall of renders.
6. **Measurable acceptance per clip** (slide cm, bend deg per joint, hold travel 0.0000, release-frame share, tip pin distance) is written into each task so a reviewer can reject a clip without taste; taste stays the director's.
7. **Order.** Mantis first (Tasks 5-9) while Phase A's tooling is fresh; the octopus (Tasks 10-13) can run in parallel on a second Blender role once Task 4 merges, with the lead as the single QA gate. One Blender process per agent; Tripo is needed only if Task 1 says redesign.
