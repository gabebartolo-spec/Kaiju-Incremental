# Lead handoff, 2026-10-17 16:00
## State: working (croc titan rig + motion with blender-reptile; #14/#16 reviews pending)

## Task
Lead for Kaiju Incremental: kaiju sculpts/skins, art and motion QA of every helper before the director,
director decisions (D-022..D-042 in docs/DECISIONS.md), helper coordination. Credits unlimited for Tripo
(D-023); log every task in docs/provenance/tripo.md.

## Branch and commit
claude/look-options (integration; PR #3 to main on HOLD until the director signs off). Latest: 30682ae
#18 heli MERGED ee18f50 (16:00, head 3a4e83c, 8/8 green); blender-tank told to remove worktree.

## D-044 LOCOMOTION PAUSED (director 12:46) until models are decided
species-motion, kaiju-motion told to stop (PR #11 open, unmerged); kaiju-look-test skips octopus captures.
Director saw octopus local capture: "head detached, limbs a static, awkward mesh" (I had not caught it).
D-043/D-044 logged (efa6756). Blender motion test (blender-reptile) decides the model pipeline first.

## CI billing RESOLVED 12:47: director made the repo public; main protection confirmed (test, doc-caps,
gitleaks; squash only). Reran failed checks on #14 #16 #17 #18; helpers told to dispatch captures.
Director: "tank and heli models look great".
- QA 12:55: heli board PASS (Apache-like, tandem cockpit, stub wings, chin gun, rotors as parts; 2x real);
  tank in-game crop reads well. Merge #17 then #18 once their in-game captures + CI are green.
- #15 round 2 (5f807cb): cause = GL Compatibility fallback scrambled packed instance data (web renderer too!),
  fixed + captures forced Forward+; mantis intact, thigh cubes square; lead look PASS; fresh re-critic running.
  Then merge at reviewed SHA. Told it: keep bake.py weight input swappable for Blender weights.

## Open PRs into look-options
- 15:52 director: pause agents working on models we won't use (usage). #15 MERGED (7ff1f03). #19 (Blender
  weights reader, proven on OLD reptile) parked until croc titan export; voxel-skin paused. kaiju-motion told to
  turn off #11 auto-fix. #18 MERGED. Auto-fix OFF: #11, #19 (confirmed); #8 asked again 16:00 (it synced a conflict at 68342d5).
  #16 city: all stills in; Apex 3-min load (follow-up); director Qs pending: balance D, Apex height.
- #15 voxel skin ACCEPTED r3 (4be3650; scythe clean, thigh seam at full flex accepted until Blender weights):
  CONFLICTING after #17, helper syncing, merge new head when green. Next: Blender-weights input PR (voxel-skin)
  + rig/weights export from motion_test.py (blender-reptile), tested on Tripo B until the D-045 mesh exists.
- #17 tank MERGED 14:45 (9cbe34b). #18 heli FIX: heli hides the baby kaiju at game cam (21 s) -> orbit beside,
  not over, the camera-kaiju line + fade vehicles between camera and kaiju (D-025 rule). Size stays 2x.
- #16 city-growth: stage 3 stills in; stage 4 (350k chunks) kills CI runners -> local GPU render approved,
  waiting for the director's game to close (perf red flag). Balance proposal D (3.3-4.4 h, +-17%) to put to director.
- #11 species locomotion (mantis + octopus). species-motion r3d: holds fixed (contrast 4.6x), big rest moves
  00284f3 not yet rendered. Needs: game + side mantis clips, octopus adult side, then FRESH motion-critic, then
  merge at reviewed SHA.
- #14 game-flow: screenshots FAILED review (blank buttons/values) -> cause LFS pointer font, fixed 7777974, flow
  67. Needs new stills (1080p + 4K at 125%) + clip, then review, mark ready, merge.
- #15 voxel skin (D-041): reptile + mantis before/after clips and 2x joint crops ready in
  side-session-notes/<lead>/kaiju-voxel-skin/ -> REVIEW THEM NEXT. Octopus captures local, after species-motion.
- #16 city-growth (D-039): 4 nested cities, pacing ceph 2.94 h / rep 3.94 h / insect 1.93 h. Stage 3-4 stills
  pending CI. Told it: target all species 3.5-4 h within +-20%, keep insectoid fastest in-run; prepare a
  proposal only. Balance is a director question after #16 review.
- #17 Blender tank (D-042, 2x, desert tan) in game; #18 helicopter (stacked on #17). Board
  blender-heli/heli_board.png to QA. Decided: helis fixed 2x scale, no growth multiplier.
- #8 SFX paused; #3 to main on hold.


## D-045 (director 14:22): reptile = NEW original Tripo design, rigged in Blender (hand rig, welded weights)
- Blender test critic: deformation + feet PASS both; animation FIX (no roar wind-up, frozen hold, tail not
  counterbalancing, arms out at peak, static walk upper body, B mouth open at rest). blender-reptile on HOLD.
- 15:45 D-046 croc titan built: refs (free) -> A-pose edit -> Smart Mesh 351ad916 v1 (100) -> texture (30), balance
  19575. ~/Downloads/kaiju_tripo/rep_croctitan_adult.glb; six-view PASS (croctitan_six_view.png). Sent to
  blender-reptile: weld, hand rig, weights export, walk/turn/roar with critic fixes -> fresh critic -> director.
  Next Tripo: baby + adolescent from the same design.
- #15 round 3 FIX sent (sheared slat cubes at scythe/thigh, forearm speckle); keep it small (Blender weights next).

## FOCUS (director 13:06): "how using blender might improve motion"
- Early test read (blender-reptile walk clips): same hand rig on A and B walks cleanly on both; foot slide
  A 8/11/1 cm, B 5.5/19/4 cm (walk/turn/roar, of 100 m); girth A shoulder 96%, B 91%. B right foot 69 cm off
  ground in the Tripo sculpt (mesh fault). So the RIG matters more than the mesh. Weak: A arms barely move;
  walk in place. Turn/roar renders + crops still running; then my QA + fresh motion-critic.
- Two routes explained to the director: (1) Blender skeleton+weights replace rig_voxel's guessed bone
  ownership (fixes detached parts, stiff limbs; D-041 skin takes weights); (2) authored clips (roar, tail
  swipe, beam) layered over procedural foot planting.
- 13:19 MOTION TEST DONE (blender-reptile 4ab6781; clips in notes blender-reptile/motion-test/): B (Tripo) moves
  cleanly on the hand rig -> bad in-game motion = OUR auto rig/weights, not the Tripo mesh. Final slide A 8/10.9/1.1,
  B 6.1/22/4.8 cm. Lead QA: turn + roar deform cleanly on both, jaw opens well; FIX for A: roar-peak arms reach
  forward (zombie), dark square blotches on thigh. Fresh motion-critic running (background). Seam-weld finding
  (glTF splits verts at UV seams) sent to kaiju-look-test as a suspect for the shattered mantis.
- ASKED director: start a helper now on getting the Blender skeleton into the game, or wait for clips.

## Blender direction (director 12:39)
- Board: Tripo adult looks better; Blender adult "promising", "more original, less a blatant Godzilla copy"
  (memory: original-not-godzilla). Blender wins only if it ANIMATES better than Tripo.
- blender-reptile (local_bce75838-34da-4991-a74e-b37ed5781547) briefed: one hand-weighted armature (deform vs
  control bones, spline-IK tail, 3-5 loops per joint) fitted to BOTH meshes (A Blender, B Tripo olive copy in
  scratch, never committed), walk + 90 deg turn + roar, headless Blender renders side by side, foot slide cm,
  2x joint crops, volume loss per joint. Answers: mesh or rig at fault. Clips come to me first.
- Research on animatable Blender models given to the director and to blender-reptile (sources: Blender wiki,
  Blender Studio, Rigify docs, MCP reviews: MCP is good for ~80% of a rig, weak on weights, timing, sculpt).

## Helpers (ids)
- species-motion local_87c25bd4-a526-4731-b18e-7c728966a2df (mantis/octopus, PR #11)
- kaiju-look-test local_c9f2ad5f-c2d8-444e-be1e-bc4d838f23cc (PR #15)
- game-flow local_9e7bf3f2-b85d-489b-987f-b9e45b8bfb55 (PR #14)
- city-growth local_abf1bce5-336a-4fc8-942a-ff8f84538b7a (PR #16)
- blender-tank local_5c21d3fa-ab76-4f0b-98ae-360caff8c60d (PR #17/#18, available)
- blender-reptile local_bce75838-34da-4991-a74e-b37ed5781547 (motion test)
- kaiju-motion local_fd14d508-6453-459d-b05c-fb22af37d14f (keeps #11 in sync)
- ability-vfx paused (PR #8); real-city tabled (D-029).

## Next (mine)
1. Review #15 reptile/mantis clips + joint crops (art-qa-critic; fresh motion-critic before the director).
2. QA heli board and #17/#18.
3. After the flip: protect main, D-043, rerun CI.
4. Fresh motion-critic on mantis r3d + octopus when clips land; merge #11.
5. Cephalopod skins (3 stages); 4K TV UI check.

## Rules learnt the hard way
- Tripo: default export name; `find` refs; stay in the signed-in tab; Remove Lighting per page; inspect every texture.
- Merge only the reviewed SHA (`--match-head-commit`).
- Windowed Godot: separate command writes override.cfg (mode=0, no_focus, -20000) first; guard blocks while a
  fullscreen app is in front. Never set fullscreen in project.godot.
- CI checkout needs `lfs: true` (fonts are LFS). Heavy software-rendered captures burn minutes: render locally.
- `rm` with variables: "${VAR:?}". After merges that add classes: `godot --headless --import`.
- Subagents without a shell can't read private PRs: stage the diff for them.

## Running jobs
None of mine. No override.cfg left. Helpers: blender-reptile working; others blocked on CI.
