# Lead handoff, 2026-10-17 00:30
## State: working (cephalopod adult texture generating on 8bf2f668: check, show director, then baby + adolescent; critic on species round 2 running)

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

## Helpers
- kaiju-motion (local_fd14d508-6453-459d-b05c-fb22af37d14f): PR #10 reptile round 4 = FIX (jaw interior
  shows when closed + orphan voxels; double plants; roar marching; baby holes/scurry; per-frame slide trace;
  rear shoulder proof). PR #11: hydra rig BROKEN (mantle voxels on tentacle chains -> floating balloons,
  director "bizarre"); asked for a static bone-colour sheet before more clips. Mantis gait = FIX (frozen idle,
  rigid scythes, smooth not skittering, pole legs, colour pop on turns). Run a FRESH motion-critic per round.
- species-powers (local_136df838-e381-4671-b237-5402935f837b): PR #12 sim review = FIX (size-scaled building slow, heli respawn farm, magic numbers, flaky autoplay, lost heli event); was
  doing the sim review (diff + checkout staged in scratchpad pr12/). Captures in side-session-notes
  species-powers/. Then merge (match head SHA) after #10/#11 or rebase as needed.
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
