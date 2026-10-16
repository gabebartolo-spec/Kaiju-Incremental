# Lead handoff, 2026-10-17 03:10
## State: working (director gaming 02:00: "take a break from art and build some of game"; no windowed Godot)

## Task
Lead for Kaiju Incremental: kaiju sculpts and skins (Tripo -> rig_voxel), art/motion QA of every helper,
director decisions. Decisions D-022..D-040 in docs/DECISIONS.md. Live ones: D-031 locomotion (reptile =
Godzilla/T-rex medium lean, T-rex *grace*), D-032 looks first / perf later, D-034 Tripo skins, D-035/D-037
species kits as upgrade-tree nodes (docs/SPECIES.md), D-039 city grows per evolution, D-040 ultimates on
their own button (E / pad Y). Credits unlimited (director); log every task in docs/provenance/tripo.md.

## Branch and commit
claude/look-options (PR #3 to main on HOLD until the director has seen the work). Merged in today: #5 street
life, #6 ability VFX, #7/#9 city (RES 8 buildings, edges). Open into it: #8 SFX (paused), #10 reptile
locomotion, #11 species locomotion (stacked on #10), #12 species powers.

## Models (all source GLBs in ~/Downloads/kaiju_tripo/; copy to scratch before Blender)
- Reptile: all 3 stages rigged from olive textures (rep_*_tex_olive.glb) and in look-options; kaiju-motion
  re-rigs them with a jaw bone on PR #10.
- Mantis: adult skin approved (mantis_adult_tex.glb, D-038); nymph skin v2 PASSED (mantis_baby_tex.glb, sent). Adolescent 0161ad14 v2 REJECTED (orange limbs), v3 generating. Old note: nymph + adolescent skins
  v1 rejected (blue / orange belly); v2 (strict "every part dark" prompt) generated, NOT YET CHECKED: open
  /workspace/texture/<id>, look, export only if dark chitin + red eyes, then send to kaiju-motion.
- Cephalopod: baby 6176590f (octo_baby.glb, director "i love him"), adolescent a328effe (octo_adolescent.glb),
  adult 8bf2f668 (octo_2.glb, 10+ tentacles). Untextured: next, one skin prompt for all three, check each.

## Director motion notes 00:44-00:46 (sent to kaiju-motion for round 5)
- Arms flail like "limp scarves" on sharp turns: arms become posed muscle, not spring chains.
- Shoulder plates swing left/right, "like hes dance walking": plates on arm bones + torso yaw; upper body one stable mass.
- Reptile round 5 = REJECT (arm fling on turn 6.9-7.5 s; baby chest holes, roar plant, cadence; summary over-claimed). Round 6 = arms + plates first. Mantis textured bone sheet PASS.
- Look test (kaiju-look-test, local_c9f2ad5f-c2d8-444e-be1e-bc4d838f23cc): voxel vs smooth skinned vs voxel-snap shader; director picks from a clip.

## Speed-up (director "can you work faster", 01:26)
- Split: kaiju-motion = reptile only; species-motion (local_87c25bd4-a526-4731-b18e-7c728966a2df) = mantis + octopus (from PR #11). Short loops; lead checks clips quickly, full critic only before the director.
- Reptile shoulders FIXED; arms lowered to the belly (49a23c9, stills docs/captures/2026-10-17-motion/reptile_arms_low.png); FINAL critic on PR #10 running, then merge #10 (match head SHA) and #11 after species-motion.
- D-041: director picked look test C (voxel cubes on skinned lattice); kaiju-look-test productionises it (all 9 kaiju, shoulder bake, bone array, PR).
- Director: reptile arms "outstretched like a zombie": bent elbows, hands near chest (sent to kaiju-motion).

## Gameplay helpers started 02:00
- city-growth (local_abf1bce5-336a-4fc8-942a-ff8f84538b7a): D-039 city grows per evolution + 3-5 h economy re-tune.
- game-flow (local_9e7bf3f2-b85d-489b-987f-b9e45b8bfb55): run summary, evolution reveal, tree polish, menus/pause/settings (4K UI scale), save/continue.

## CI captures live (02:20)
- PR #13 merged to main (capture.yml dispatch-only + tools/capture/ci_capture.sh); workflow also on look-options (dispatch reads the file from the ref; branches cut before 02:20 need it merged in). Helpers already dispatching.
- Held notes SENT (02:30): reptile baby chest hole + jaw seam + round6 reverse proof -> kaiju-motion (then merge #10); helpers told to merge look-options for capture.yml and dispatch on their OWN branch.

- Balance finding (city-growth): insectoid clears ~2x faster than the other species in grown cities (Climber/glide); costs paced on median; species-balance follow-up to raise with the director after its PR (target +-20% tree time)

- PR #10 reptile locomotion MERGED (aaa60f7): planted feet, locked shoulders, arms at belly, sealed baby chin, snarl rest mouth "B" (director, via kaiju-motion), chest blemish clean-up in rig_voxel.
- Blender MCP installed (user scope, telemetry off, safe mode); agents may open Blender UI; director says pause -> touch ~/.claude/focus-pause (blocks it again).

## Helpers
- kaiju-motion (local_fd14d508-6453-459d-b05c-fb22af37d14f): PR #10 reptile round 4 = FIX (jaw interior
  shows when closed + orphan voxels; double plants; roar marching; baby holes/scurry; per-frame slide trace;
  rear shoulder proof). PR #11: hydra rig BROKEN (mantle voxels on tentacle chains -> floating balloons,
  director "bizarre"); asked for a static bone-colour sheet before more clips. Mantis gait = FIX (frozen idle,
  rigid scythes, smooth not skittering, pole legs, colour pop on turns). Species round 2: mantis REJECT (still idle, no freeze bursts), octopus FIX (floaters, no surge), baby octo REJECT at game cam. Run a FRESH motion-critic per round.
- species-powers (local_136df838-e381-4671-b237-5402935f837b): PR #12 MERGED (858c2dc) after fixes (unscaled block radius, heli clock, tuning numbers, step counter). Next: D-039 city growth + cost re-tune task.


- ci-captures (local_1171d586-b2d9-464b-8a9e-e55028717b5d): capture.yml works on CI (lavapipe); PR soon.
- ability-vfx (local_24621710-3f9c-4f67-ae39-8fa4b6192106): PAUSED until locomotion lands; PR #8 on hold.
- city-layout done; real-city TABLED (D-029, branch claude/real-city-92596b).

## Next (mine)
1. DONE: all 3 mantis skins exported (mantis_{baby,adolescent,adult}_tex.glb) and sent.
2. Cephalopod skins (3 stages).
3. Follow-up task after #12: city growth per evolution (D-039) + cost re-tune (~5x from Colossus, pacing.gd).
4. Helicopter + military Tripo models (D-020/D-037); landmarks.
5. 4K TV text size check (perf deferred, D-032).

## Rules learnt the hard way
- Tripo: default export name; `find` refs, never pixel coords across loads; stay in the signed-in tab;
  check Remove Lighting per page; texture prompts drift per model: inspect every result.
- Merge only the reviewed SHA (`--match-head-commit`).
- Windowed Godot: separate command writes override.cfg (mode=0, no_focus, -20000) first; focus-guard also
  blocks while a fullscreen app is in front; prefer CI captures. Never set fullscreen in project.godot.
- `rm` with variables: use "${VAR:?}". After merges that add classes, run `godot --headless --import`.
- Subagents without a shell can't read private PRs: stage the diff/checkout for them.

## Running jobs
Tripo: cephalopod adult texture (8bf2f668) generating. Sessions above. Scratch worktree pr12/tree (detached,
removed). No override.cfg left.
