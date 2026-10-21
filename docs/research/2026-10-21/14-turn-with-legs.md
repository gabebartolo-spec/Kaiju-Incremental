# Turning a giant body by stepping, not swivelling (research 14, 2026-10-21)

Scope: the leg/animation side of a kaiju turn and how it meets the sim heading that the separate
turn-weight builder is tuning. Repo read-only facts are marked "repo:" with the file.

## Key findings

1. **The shipped standard is "counter-rotate the body, then pay the offset back with a turn clip".**
   In Lyra the actor faces the controller yaw, but a Rotate Root Bone node counter-rotates the mesh
   by a Root Yaw Offset so the feet do not slide; while idle the offset "Accumulate"s (fully
   cancels the actor's rotation), and a turn-in-place animation is picked when the offset passes a
   per-anim-set angle after a wait time; the turn clip's own root rotation (baked to curves by the
   Turn Yaw Anim Modifier, root motion on) is what eats the offset. Modes: Accumulate (idle), Hold
   (starts), Blend Out (entering jog: return to orient-to-controller).
   [Epic: Animation in Lyra](https://dev.epicgames.com/documentation/en-us/unreal-engine/animation-in-lyra-sample-game-in-unreal-engine);
   [Epic tech blog: Adapting Lyra animation](https://www.unrealengine.com/tech-blog/adapting-lyra-animation-to-your-ue5-game)
   (raising the allowed Root Yaw Offset angle for forward-facing characters). Known pitfall: the
   offset sign flips on repeated alternating turns past +-180 deg; one user clamps it
   ([UE forum, anecdotal](https://forums.unrealengine.com/t/turn-in-place-almost-perfect/1259957)).
   The core idea: **gameplay heading and visible body yaw are two variables; the gap between them
   is closed only by a step, never by spinning planted feet.**

2. **While moving, the legs follow the travel direction and the spine twists the rest.**
   Unreal's Orientation Warping bends the leg IK toward the locomotion direction and "maintain[s]
   the facing angle by twisting the spine bones" about Z; the twist is distributed over listed
   spine bones (Distributed Bone Orientation Alpha), smoothed by Rotation Interp Speed, and guarded
   by a Locomotion Angle Delta Threshold (default 90 deg) "to prevent erroneous over-rotation".
   Stride Warping scales stride by LocomotionSpeed / RootMotionSpeed.
   [Epic: Pose Warping](https://dev.epicgames.com/documentation/en-us/unreal-engine/pose-warping-in-unreal-engine).
   Lyra uses orientation warping in starts because it only has four cardinal strafe clips
   ([Lyra doc](https://dev.epicgames.com/documentation/en-us/unreal-engine/animation-in-lyra-sample-game-in-unreal-engine)).
   For a kaiju this means a curving walk can keep feet planted with the spine soaking up the
   difference, instead of the whole rig yawing on the plant.

3. **Procedural turn-in-place = error-driven steps, hips partway, chest leads, shuffle for big turns.**
   A current Unreal Control Rig toolkit describes exactly the target behaviour: feet stay planted
   while the body turns and "step once the twist builds up" (error-driven, not timed, so
   "interrupted, reversed and partial turns just work"); weight transfers onto the stance foot;
   hips follow only partway, the spine unwinds the lag so the chest keeps facing; a "knee budget"
   caps how far the hips may follow; long fast turns switch to a shuffle of small quick steps; pelvis
   lags the feet; tails/antennae lag on springs.
   [ArtemSereda Procedural Animation Toolkit, UE forum](https://forums.unrealengine.com/t/artemsereda-procedural-animation-toolkit/2741124)
   (commercial plugin, a description of method only, no numbers published).

4. **The procedural-walker trigger is "foot too far from its target", plus ordering constraints.**
   Godot 4.5 spider write-up: each leg has a target (raycast), a step fires once the planted foot
   drifts past a threshold from its predicted target, the foot travels an arc, diagonal pairs are
   grouped so only one group moves at a time, the body aligns to the feet's plane
   ([80.lv: IK-driven spider locomotion in Godot 4.5](https://80.lv/articles/ik-driven-procedural-spider-locomotion-in-godot-4-5)).
   Same distance-threshold, one-leg-at-a-time logic in the free Blender Spider Walker
   ([80.lv](https://80.lv/articles/free-blender-tool-for-procedural-spider-walks);
   [Digital Production](https://digitalproduction.com/2026/08/28/spider-walker-automates-multi-leg-animation/)).
   A per-leg variant also matches the target's *rotation* on the step
   ([itch.io post](https://itch.io/post/8459308)). Inference: a pure distance trigger misses a turn
   in place (a foot under a rotating hip barely moves in distance), so a **twist trigger** (foot yaw
   vs. body yaw) is needed for turning; finding 3 confirms twist-triggered stepping is the method.

5. **Quadruped stepping order: lateral-sequence walk, three feet down, never lift a pair.**
   Slow quadruped walks use the lateral sequence hind-left, fore-left, hind-right, fore-right, with
   the centre of mass kept over a support triangle; most animals use it because its tripods are
   larger than the diagonal sequence's ([Hildebrand 1980](https://www.originalwisdom.com/wp-content/uploads/bsk-pdf-manager/2019/03/Hildebrand_1980_The-Adaptive-Significance-of-Tetrapod-Gait-Selection.pdf);
   [Cartmill et al. 2002, support polygons](https://www.originalwisdom.com/wp-content/uploads/bsk-pdf-manager/2019/10/Cartmill-et-al_2002_Support-polygons-and-symmetrical-gaits-in-mammals.pdf)).
   Caveat: real walkers keep >2 feet down only at the slowest speeds (same sources). For a slow,
   heavy turn (the slowest gait there is) one foot at a time in lateral order is the correct read;
   fast skittering (the mantis) may lift diagonal pairs, as finding 4 and the repo's hexapod do.

6. **Heaviness = time scaled by sqrt(size); big bodies step slower, not just shorter.**
   Alexander's dynamic-similarity hypothesis: animals of different size move alike at equal Froude
   number Fr = v^2/(g L_leg), which requires equal relative stride length (stride / hip height)
   ([Dynamic similarity, PMC3798186](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3798186/);
   [SFU locomotion lab 1997](https://www.sfu.ca/locomotionlab/assets/dynsimwalk1997.pdf)). Inference
   from those two: step time = stride / v is proportional to L / sqrt(L) = sqrt(L), so a kaiju
   with 4x the leg length takes each step 2x as long. Bigger animals also walk at lower relative
   speeds and stride frequencies ([same PMC paper](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3798186/)).
   Caveat: strict similarity fails (relative stride differed up to 67% under reduced gravity, same
   paper). repo: `kaiju_gait.gd` and `gait_biped.gd` already scale turn rate and cycle by sqrt(scale).

7. **Craft order for a turn: weight first, then lift; foot rolls heel -> ball -> toe.**
   Animation Mentor's turnaround guidance: film reference, block strong key poses, then make the
   weight transfer read before limbs lift ([Animation Mentor blog](https://www.animationmentor.com/?p=46272));
   foot pivots roll heel, then ball, then toes ([Autodesk 3ds Max: Animating Pivots](https://help.autodesk.com/cloudhelp/2017/ENU/3DSMax/files/GUID-6CAEE405-A264-47A0-AFE8-4E233ACC999A.htm)).
   Locomotion sets normally carry 90 and 180 deg turn-in-place left/right clips; a "pivot" (plant,
   rotate through, push off) is a different move from a slow idle turn
   ([MoCap Online locomotion guide](https://mocaponline.com/blogs/mocap-news/locomotion-system-design-guide)).
   Overgrowth (Rosen, GDC 2014 Animation Bootcamp) builds fluid motion from very few keyed poses plus
   code, which is the same "few poses + procedural" split the repo uses
   ([Game Developer: An Indie Approach to Procedural Animation](https://gamedeveloper.com/design/video-an-indie-approach-to-procedural-animation)).

8. **Creature games with unknown or odd bodies drive legs by goals, not clips.**
   Spore records motion morphology-independently and at runtime turns it into pose goals for an IK
   solver ([Hecker et al. 2008](https://chrishecker.com/Real-time_Motion_Retargeting_to_Highly_Varied_User-Created_Morphologies)).
   Rain World builds every creature from points at fixed distances with cosmetic limbs animated
   procedurally on top ([Game Developer](https://gamedeveloper.com/design/crafting-the-complex-chaotic-ecosystem-of-i-rain-world-i-);
   [Unity blog](https://unity.com/en/blog/exploring-procedural-design-rain-world)). Supports keeping
   the cephalopod's turn on grip/release logic (repo: `gait_radial.gd` already releases arms behind
   a new heading) rather than forcing a leg scheme on it.

9. **Godot 4.6+ has engine IK, but only on Skeleton3D; the repo's node rig keeps its own solver.**
   Godot 4.6 added IKModifier3D with TwoBoneIK3D (deterministic), ChainIK3D, SplineIK3D,
   FABRIK3D, CCDIK3D, JacobianIK3D, plus LimitAngularVelocityModifier3D; BoneConstraint3D can now
   reference Node3D targets ([Godot blog: IK returns in 4.6](https://godotengine.org/article/inverse-kinematics-returns-to-godot-4-6/)).
   These are SkeletonModifier3D children, so they act on Skeleton3D bones; repo: `scenes/kaiju_rig.gd`
   gives each bone its own voxel node, and `gait_biped.gd` already does its own two-bone IK, so no
   migration is needed for foot locking. Root-motion rotation from clips is available through
   AnimationMixer `root_motion_track` / `get_root_motion_rotation()`
   ([Godot AnimationMixer docs](https://docs.godotengine.org/en/stable/classes/class_animationmixer.html)),
   but in this game the sim owns heading, so clip yaw can only drive the *visual* body yaw (as
   repo `gait_clip.gd` `_steer_turn` already does), never the kaiju node.

## Sources

- Epic, Animation in Lyra: https://dev.epicgames.com/documentation/en-us/unreal-engine/animation-in-lyra-sample-game-in-unreal-engine
- Epic tech blog, Adapting Lyra animation: https://www.unrealengine.com/tech-blog/adapting-lyra-animation-to-your-ue5-game
- UE forum, Turn In Place Almost Perfect (anecdotal): https://forums.unrealengine.com/t/turn-in-place-almost-perfect/1259957
- Epic, Pose Warping (Orientation / Stride Warping): https://dev.epicgames.com/documentation/en-us/unreal-engine/pose-warping-in-unreal-engine
- ArtemSereda Procedural Animation Toolkit: https://forums.unrealengine.com/t/artemsereda-procedural-animation-toolkit/2741124
- 80.lv, IK spider locomotion in Godot 4.5: https://80.lv/articles/ik-driven-procedural-spider-locomotion-in-godot-4-5
- 80.lv, Blender Spider Walker: https://80.lv/articles/free-blender-tool-for-procedural-spider-walks
- Digital Production, Spider Walker: https://digitalproduction.com/2026/08/28/spider-walker-automates-multi-leg-animation/
- itch.io post on per-leg targets: https://itch.io/post/8459308
- Hildebrand 1980: https://www.originalwisdom.com/wp-content/uploads/bsk-pdf-manager/2019/03/Hildebrand_1980_The-Adaptive-Significance-of-Tetrapod-Gait-Selection.pdf
- Cartmill et al. 2002: https://www.originalwisdom.com/wp-content/uploads/bsk-pdf-manager/2019/10/Cartmill-et-al_2002_Support-polygons-and-symmetrical-gaits-in-mammals.pdf
- Dynamic similarity, swing phase (PMC3798186): https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3798186/
- SFU locomotion lab, dynamic similarity walking 1997: https://www.sfu.ca/locomotionlab/assets/dynsimwalk1997.pdf
- Animation Mentor turnaround: https://www.animationmentor.com/?p=46272
- Autodesk, Animating Pivots: https://help.autodesk.com/cloudhelp/2017/ENU/3DSMax/files/GUID-6CAEE405-A264-47A0-AFE8-4E233ACC999A.htm
- MoCap Online locomotion design: https://mocaponline.com/blogs/mocap-news/locomotion-system-design-guide
- Game Developer, Rosen GDC 2014: https://gamedeveloper.com/design/video-an-indie-approach-to-procedural-animation
- Hecker et al. 2008 (Spore): https://chrishecker.com/Real-time_Motion_Retargeting_to_Highly_Varied_User-Created_Morphologies
- Game Developer, Rain World: https://gamedeveloper.com/design/crafting-the-complex-chaotic-ecosystem-of-i-rain-world-i-
- Unity blog, Rain World: https://unity.com/en/blog/exploring-procedural-design-rain-world
- Godot blog, IK in 4.6: https://godotengine.org/article/inverse-kinematics-returns-to-godot-4-6/
- Godot AnimationMixer: https://docs.godotengine.org/en/stable/classes/class_animationmixer.html

## For Kaiju Incremental

Repo state (read-only): `scenes/kaiju_gait.gd` `track()` already splits the sim heading
(`model_yaw`, the node) from the drawn body (`body_yaw`, a critically damped spring at 7/s, capped
at 4.5/sqrt(scale) rad/s) and rotates the rig by the difference: this is Lyra's Root Yaw Offset in
all but name. The hexapod already lets legs lead and holds the body until a leg is airborne
(`gait_hexapod.gd` BIG_TURN). The swivel comes from the biped: in `gait_biped.gd` the body spring
turns continuously whatever the feet are doing, and a planted foot only re-steps when stretched to
REACH_STEP 0.99 of leg reach (or, standing, SETTLE_DISTANCE 0.16 hip heights). Both are
*distance* tests; turning on the spot with a narrow track (TRACK_NARROWING 0.82) moves the feet
very little in distance, so the hips twist over fixed feet until a late stretch step: the plastic
toy. (`gait_clip.gd` plays turn clips past TURN_TRIGGER 0.6 rad when baked clips exist; check which
path the reptilian runs in game before tuning.)

Ranked, simplest first:

1. **Twist trigger on the biped (and quadruped) feet.** Store each foot's yaw at plant; a planted
   foot steps when |body_yaw - foot_yaw| > ~25-30 deg OR its existing distance/stretch tests fire.
   The outside foot of the turn (the one the hip swings away from) goes first; the inside foot
   pivots in place (rotate its toe about the heel by the remaining twist on landing; no translation).
   Land the stepping foot at the target rotated by the *current* sim heading plus a small lead, so
   a 90 deg turn takes about 3-4 alternating steps and 180 deg about 6 (inference, see gaps).
   Cost: about 40-60 lines in `gait_biped.gd`, no data or sim changes; one capture clip.
2. **Gate body yaw on foot phase ("turn on the plant").** In the biped, let `body_yaw` advance at
   full rate only while a foot is in swing, and at a small share (say 0.15-0.25) while both feet are
   down; the spine/neck chain (BipedHead) takes the remaining error so the head still leads at once.
   This is the hexapod's BIG_TURN rule made continuous. Cost: about 20 lines, shares the existing
   spring; risk: body lag grows on fast turns, so pair with item 4's cap.
3. **Lead order through the chain.** Head/eyes turn to the full sim heading at once (clamped, e.g.
   45-60 deg), shoulders/chest follow at about half the error, hips get what the feet allow (finding
   3's "knee budget"), tail counter-swings on the existing tail spring (`gait_clip.gd` TAIL_SPRING
   already exists; reuse it in BipedSwing). Cost: about 30 lines, spread of a yaw over named bones.
4. **Heaviness numbers per stage, from data.** Step (swing) time and settle time already scale by
   sqrt(scale); keep that law (finding 6) and add the twist threshold and phase-gate share to
   `data/` per stage so a baby turns in 2 quick steps and an adult in 3-4 slow ones. Pelvis dips on
   each plant and a camera/footfall hit per plant (already emitted by `foot_planted`) sell the
   weight more than slower rotation. Cost: a data block plus reads; no new system.
5. **Quadruped order (when a quadruped body plan exists).** Twist trigger per foot, one foot at a
   time in lateral sequence HL, FL, HR, FR; forbid lifting a foot if its diagonal or same-side
   neighbour is in the air (keeps a support triangle). The insectoid keeps diagonal-pair skitter.
   Cephalopod: keep grip release behind the new heading (`gait_radial.gd`), no change.
   Cost: one leg-scheduler function per gait, about 60 lines.
6. **Clip route, only if hand-keyed turn clips are wanted.** 90 and 180 deg turn clips per stage,
   picked from the yaw error like Lyra, their root yaw driving `body_yaw` as `_steer_turn` already
   does. Cost: authoring 4 clips per biped stage plus the art QA cycle; more look control, more
   assets; not needed if items 1-3 pass.

**How this fits the turn-weight work.** The sim (the turn-weight builder) owns `sim.facing` and the
body heading in `sim/body_contact.gd` (turn_rate in `data/tuning.json`): that is where the kaiju
*is* facing for collisions, breath cone and gameplay feel. The gait owns only `body_yaw`, the drawn
facing, and must never write back. To avoid fighting: (a) the gait reads `model_yaw` as a target,
not a value to match each frame; (b) the visible lag (model_yaw - body_yaw) needs a hard cap
(about 30-40 deg) so a hit or breath never visibly misses the drawn head; the head/neck closes
whatever the body has not, so the cap is cheap to hold; (c) if the sim's heading becomes heavy
(inertia, slower turn), the gait's own spring should get *faster*, not add a second layer of lag,
or the turn will feel double-delayed; agree with that builder which layer carries the weight
(recommendation: sim carries the turn rate, gait carries only step timing and chain order).
Determinism holds because the gait stays presentation-only and its rng is already seeded.

Pseudocode sketch (biped, per frame, after `track()`):

```
err = wrap(model_yaw - body_yaw)
feet_down = all legs planted
rate_share = 1.0 if any leg swinging else PLANT_SHARE        # data, ~0.2
advance body_yaw toward model_yaw with spring, velocity *= rate_share
clamp |wrap(model_yaw - body_yaw)| <= MAX_LAG                 # data, ~35 deg
head/chest/hips take err * [1.0, 0.5, hips_from_feet] (head clamp ~50 deg)
for leg in legs (outside-of-turn leg first):
    twist = abs(wrap(body_yaw - leg.plant_yaw))
    if leg.planted and other leg planted and (twist > TWIST_STEP or stretch > REACH_STEP):
        target = home rotated by (model_yaw + sign(err) * LEAD)
        lift(leg, swing = STEP_TIME * sqrt(scale))
    if leg.planted and other leg swinging:
        pivot leg toe about heel toward body_yaw (no translation)
on plant: pelvis dip, foot_planted.emit (already exists)
```

Evidence gaps: no primary source gives a step count per 90 deg for heavy animals or a numeric twist
threshold (the 25-30 deg, 3-4 steps per 90 deg, 35 deg lag cap are my inferences to tune by clip);
no developer source found on how Monster Hunter, Shadow of the Colossus, The Last of Us/Uncharted or
For Honor do turn-on-the-plant (searches returned only fan hitbox threads); the Valve SIGGRAPH 2021
talk on Half-Life: Alyx footstep prediction (https://history.siggraph.org/wp-content/uploads/2022/06/2021-Talks-Heuvel_The-Right-Foot-in-the-Wrong-Place.pdf)
could not be read as text; the stride-time ~ sqrt(leg length) law is derived from the Froude
sources, not stated in them.
