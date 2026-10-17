# Species-motion handoff, 2026-10-17 12:55
## State: paused (director: pause locomotion until the models are decided)

Director, via the lead: "theyre doing work they might have to replace if we change our models".
Do not start new locomotion work until the lead lifts the pause.

## Open items (first = most important)
1. OCTOPUS (director watched r3e cephalopod_adult_*.mp4): "head detached, limbs a static, awkward
   mesh". So the mantle floats free of the tentacle base, and the limbs read as a rigid static mesh.
   Likely causes to check first:
   - the mantle0 pose offset in RadialGait._pose_mantle (stretch/slam/low offsets plus _lag) moves
     the mantle away from the chain roots, which stay on the rig (chain.pos[0]);
   - tentacle chains are stiff Verlet chains of 6 rigid voxel bones: no bending inside a bone, so
     they read as rigid sticks. D-041 (voxel cubes on a smooth skinned lattice, PR #15
     kaiju-look-test) should fix the in-bone rigidity; the mantle offset is ours.
2. Mantis r3e: the lead's fresh critic verdict is still pending (packet in notes species-motion/r3e/).
   At the game camera, screen_motion.py's centre box (280x540) is narrower than the adult mantis,
   so the meter under-reads the limbs; widen the box per stage before using it as a gate.
3. PR #11 (claude/kaiju-motion-species) is the head for this work, but pushing to it was refused by
   the permission classifier on 2026-10-17. The lead or kaiju-motion must fast-forward it to
   claude/species-motion.

## Task (when resumed)
Mantis (insectoid) and octopus (cephalopod) locomotion, QA round 3 findings 1-11. Evidence goes to
the lead, never the director. Director: the insect must "disturb and disgust" (skitter, twitch);
the octopus must slide, push and pull, grab edges, never tip-toe; never wind-up-toy.

## Branch and commit
- claude/species-motion (pushed). Merged with PR #11 (99a9385 era) and claude/look-options
  (30682ae, LFS fix). Merge, never rebase.
- Key commits: 4f98a07 rigs + bone_sheet.py; 6aa486f mantis gait + motion_report.py; 324d14a
  octopus gait; 7b7759b mandibles; 1d7d436 camera follows the drawn body (KaijuModel.focus,
  rampage camera) + screen_motion.py; 0a36ec4/00284f3 big rest moves; 8f650f4 no holds while
  slowing, faster octopus breathing.

## Unfinished changes
- None. Tree clean; override.cfg deleted; no Godot of mine running.

## Measured (latest)
- Mantis holds dead still (bone trace 0.0000; rendered 99% of hold frames under 0.01 at 80x150);
  darts 4x the hold motion; body turn 0.25 s, legs lead.
- Octopus adult grips every 0.6-0.9 s with 3 front arms in turn; body ~1 u/s dragging, 8.5 u/s
  after a grip. Rigs: no fragments or slate islands (the lead passed the bone sheet).

## Attempts (fix-loop record)
- Octopus ownership: a thickness test left slate mid-tentacle -> a region grow from seeds fixed it ->
  then the head was overgrown -> a tapered bound, a low core and dropping high ridges fixed that.
- Mantis holds drifted on the smoothed velocity -> anchoring to the world point fixed it; a one-frame
  nudge -> anchor = origin - lag.
- The mantis turn was 1.7 s -> a constant-rate swing gated on a leg being in the air gave 0.25 s.
- Holds invisible on screen (camera panned through them) -> the camera follows the drawn body.

## Open decisions
- Models (director): locomotion paused until they are decided.

## Running jobs
- None. GitHub Actions is blocked by billing (the director may make the repo public). Local captures
  need the focus guard to allow them: override.cfg in its own step, fixed-fps 60, delete after.

## Rules learnt
- capture_motion steps 1/60 s per frame: record at --fixed-fps 60. A local movie writes 1920x1080.
- Software-rendered CI clips of the adult octopus take >1 h; render them locally.
- Static typing: float(Variant) is an error; never name a helper _set; gdlint caps a file at 400 lines.
- Running Python with APPDATA overridden hides site-packages (cv2): set APPDATA only for Godot.
