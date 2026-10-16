# Kaiju-motion handoff, 2026-10-17 07:30
## State: available (#10 MERGED as aaa60f7 into look-options; #11 retargeted + synced 99a9385)

## Task
D-031: species-true kaiju locomotion. Reptile = Godzilla-to-T-rex lean (20-30 deg) with T-rex
grace; insectoid = skittering, disturbing mantis; cephalopod = sliding/gripping octopus/hydra
(D-036). Presentation only. Evidence -> lead -> motion critic -> director. D-032: cost recorded,
not a limit. D-035 (docs/SPECIES.md): powers; hooks on KaijuModel for species-powers session.

## Branch and commit
- claude/kaiju-motion -> PR #10 (reptile): MERGED (squash aaa60f7). Branch can be deleted by the lead. Round 5 at 5e3427f: mouth inside split (dark seam shut,
  pink open), even cadence (adult 0.45 s +-2-6%, baby 0.32 s), no double plants, still roar,
  footfall ring + camera dip, front34/rear evidence cams, per-frame feet CSV.
  Force-push is denied: merge, never rebase a pushed branch.
- claude/kaiju-motion-species -> PR #11, base claude/look-options (synced 99a9385; the squash
  conflicts resolved to ours since #11 already held all of #10). Mantis adult textured (86ac43d, UV-seam weld), cephalopod rigs rebuilt
  (9c0094d: voxels only on their own tentacle, true counts 13/8/13), hooks incl. climbing(on).
  Lead asked: NO more octopus motion clips until it OKs species3/octo_bone_sheet.png.

## Unfinished changes
- none uncommitted. Round 6b answers the lead's round-5 REJECT (arms aimed in chest space,
  plates/inboard shoulder on spine, no chest band on arm roots, decisive stop, roar waits for
  feet, baby dip floor). Open: baby roar still has a plant at 10.017 (in-flight stomp; roar
  starts on that frame); baby trip makes reverse cadence +21%; no automated sealed-chest check.
- Split (lead, 2026-10-17): this session = REPTILE only (gait_biped, biped_*, kaiju_rig/gait/model
  core). species-motion (local_87c25bd4) owns hexapod/radial gaits, mantis/octopus assets and
  their rig_voxel parts, on its own PR into claude/kaiju-motion-species. Shared files: small edits.
- Shoulder lock: spine1 = exact inverse of the pelvis yaw/roll/sway (keeps lean/drop/surge);
  SWAY 0.03, HIP_YAW 0.06. capture_motion prints SHOULDERS drift/tilt/yaw + rear plumb line.
  Adult yaw reads a constant -3.95 deg: sculpt asymmetry (swing 0.02).
- Arms: aimed in the heading frame: hang, ~60 deg elbow, hands resting in front of the belly
  (director's pick, lead-approved). It is also the KaijuRig rest pose for bipeds
  (_relax_arms <- BipedSwing.rest_arm_bases), so the D-041 skin binds to it; kaiju-look-test
  told to rebake. Director gaming: headless + CI captures only (focus-guard).
- capture_motion: --cam=front34w (whole body), side camera pulled back (cephalopod keeps its own).
  Short loops: one clip per fix to the lead (notes kaiju-motion/round6c_*, round6d_*).
- Final reptile critic (lead): adult PASS. Baby fixes done: jaw baked shut at rest
  (rig_voxel.close_jaw; no throat gap, hairline mouth). Director picked adult mouth "B": a
  tight snarl, true colours (rig arg jaw_shut 0.35 -> rig.json "snarl": true -> BipedHead skips
  the dark seam). Director REJECTED skin-coloured mouth insides. Rig commands:
  blender -b --python tools/blender/rig_voxel.py -- <rep_<stage>_tex_olive.glb copy>     assets/kaiju/reptilian_<stage> reptilian <100|130|160> [0.35 adult only]
- #10 has look-options merged (45b2be6) for capture.yml. Baby CI clip (run 38925005160) sent:
  notes kaiju-motion/round6f_baby_ci/. Torso blemish pass (rig_voxel.clean_blemishes, the
  adult "nips": 4 voxels) at 734257e. kaiju-look-test told to rebake.
- #11: grip finder moved to scenes/kaiju_grip.gd (rampage.gd line cap); told species-motion.
- CI flow fix: ability_fx looks up body parts per toggle (freed after a growth stage).
- capture_motion --tint colours each bone (arm0 red, arm1 yellow, hand magenta) for rig QA.
- Mantis all three stages textured (D-038) at 862d318.
- Queue: hydra bone fixes (every long tentacle chained, majority smoothing, orphans to nearest
  bone, pale mantle patch; resend bone sheet), then species round 2 QA (mantis freezes/darts,
  idle twitch, roar flare, leg-led 0.3 s turn; octopus surges, adolescent pull, baby 2-3 arms).
- Adult hydra: two raised arches have no chain (ride the mantle); max_arms 16 is the cap.
- D-035 locomotion anticipation (insect jump/climb, octopus squeeze through gaps) not started.

## Evidence so far
- capture_motion.gd: --cam=game|side|fixed, event labels, --trace CSV (+ _plants.csv).
- Slide 0.0 cm everywhere; reptile plants every ~0.44 s +-5%, speed dip at plants.
- Clips: side-session-notes/local_9fac90d2.../kaiju-motion/{round2,round3,round4,species1,species2}/.

## Attempts (fix-loop record)
- Reversal foot slide -> step/hop rules + eased sink -> 0. Z-fight stripes -> inset filler.
- Uneven steps after the hold: stride outran reach + pelvis resonance -> stance 0.48 hip,
  landing clamp anticipates hold, rescue steps counted as slot steps, stiffer pelvis.
- Jaw: red mouth-interior voxels give the cut and the close angle (cap 0.7 rad).
- Radial: tips by furthest-surface claiming; baby head fixed by mantle-centre, thin-tip and
  on-bone rules.

## Open decisions
- none (licensing rows added by lead, 7cae54e).

## Running jobs
- none. Remove override.cfg after any capture.

## Findings for the lead
- Plot pelvis height + forward speed per frame (--trace) to prove rhythm; it exposed uneven steps.
- Log plant/lift events with reasons: two "rescue" rules were silently driving the gait.
- Bone-ownership plots (front/side, coloured per bone) catch rig faults before any capture.

## Rules learnt the hard way (under 10 lines)
- Windowed Godot steals focus from the director's fullscreen games: focus-guard blocks it then.
  Work headless, retry captures minutes apart, batch all clips into one short windowed run.
- Never edit .gd while a local suite/capture runs; after switching branches run --import.
- gdlint: 400 lines/file, <=4 args, 20 public methods, signals first, public vars before private.
- Kill only Godot PIDs you started (check CreationDate/CommandLine).
