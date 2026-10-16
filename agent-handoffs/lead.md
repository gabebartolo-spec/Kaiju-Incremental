# Lead handoff, 2026-10-16 23:32
## State: working (cephalopod adolescent 724612fd + mantis adult texture generating; helpers: kaiju-motion, species-powers, ci-captures)

## Task
Lead for Kaiju Incremental: kaiju sculpts and skins (Tripo -> rig_voxel), art QA of every helper,
director decisions. Today's decisions: D-022..D-034 in docs/DECISIONS.md. Key ones now:
D-031 locomotion (reptile = Godzilla/T-rex medium lean, T-rex *grace*), D-032 looks first / perf
later, D-033 stages picked, D-034 Tripo skins (reptile = dark olive crocodile), credits unlimited.

## Branch and commit
claude/look-options (PR #3 to main on HOLD until the director has seen the work).
Merged into it today: #5 street life, #6 ability VFX, #7/#9 city (RES 8 buildings, edges).

## Done this stretch
- Reptile adolescent B (Tripo f9cf6ba7) rigged at 130 vox; adult re-rigged at 160 from the olive
  texture (rig_voxel.py now samples the base-colour texture when the GLB has one).
- Mantis stages approved: baby 06ed8a12, adolescent 0161ad14, adult 9668b815 -> kaiju-motion rigs
  them with its hexapod skeleton (it has already produced insectoid_adult, uncommitted on its branch).
- Boards: docs/captures/2026-10-16-stages/ (stages_board, reptile_skin_options, reptile_olive_ingame).

## Next (mine)
1. DONE: all three reptile stages rigged from olive textures (docs/captures/2026-10-16-stages/reptile_stages_ingame.png).

2. Cephalopod: adult = 8bf2f668 (octo_2.glb, D-036), baby = 6176590f (octo_baby.glb, director "i love him"), adolescent generating (724612fd). Then a skin for all three.
   ~/Downloads/kaiju_tripo; export the other two, six-view, pick, then baby + adolescent (Lion King
   logic), then a skin. Radial rig comes from kaiju-motion.
3. Mantis skins (3 stages, one prompt), after the director sees the rigs.
4. Military vehicles + landmarks via Tripo (D-020); cars are chunkier than RES 8 buildings.
5. 4K TV text size check (perf deferred, D-032).
6. Species gameplay (D-035, docs/SPECIES.md): build after PR #10; 3 open questions for the director there.

## Helpers
- kaiju-motion (local_fd14d508-6453-459d-b05c-fb22af37d14f), PR #10: round 2 = FIX (posture, no skate, head, mass PASS; jaw open, tail lag, hold beat, game-camera read, baby stumble, pale legs, true side cam to fix). Round 1 was REJECTED (fix
  list sent: posture lean 20-30 deg, tail sweep, head stable/mouth closed, weight, arms, blends, baby
  clumsier, game-camera readability, washed-out legs, stuttering capture). Round 2 clips exist
  (rex2_*); run a FRESH motion-critic when it reports. Adds KaijuModel.foot_planted(side,strength,at).
- ability-vfx (local_24621710-3f9c-4f67-ae39-8fa4b6192106): PAUSED by the director until locomotion
  lands. PR #8 SFX on hold (stomps reworked low-end, not yet synced to foot_planted).
- city-layout: done; RES 12 / facade proposal in its handoff (branch claude/city-layout-56adda).
- real-city: TABLED (D-029), WIP on claude/real-city-92596b.

## Rules learnt the hard way
- Tripo: export with the default name; use `find` refs (coordinates shift with the page height);
  a new browser tab may show Tripo logged out: use the original tab; check Remove Lighting per page.
- Merge only the SHA you reviewed (`--match-head-commit`).
- Windowed Godot: write override.cfg (mode=0, no_focus, -20000) in a SEPARATE command before the run
  (focus-guard hook checks first); delete after. Never set fullscreen in project.godot.
- After a merge that adds classes, run `godot --headless --import` once or scripts fail to parse.
- Running Python with APPDATA overridden loses user site-packages: set APPDATA only on the Godot call.

7. Helpers started 23:20: species-powers (local_136df838-e381-4671-b237-5402935f837b, per-species upgrade branches + helicopters), ci-captures (local_1171d586-b2d9-464b-8a9e-e55028717b5d, xvfb capture workflow). Cephalopod baby generating; adolescent next.

## Running jobs
None in Tripo. Sessions above. No override.cfg left.
