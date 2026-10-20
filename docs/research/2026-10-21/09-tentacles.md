# 09 - Procedural octopus tentacles for the cephalopod kaiju (reach, grab, wrap, slam)

Researched 2026-10-21. Scope: real arm biomechanics that read well, chain algorithms, Godot 4.x
tools, games that do it, and what it means for Kaiju Incremental's voxel cephalopod.

## Key findings

1. **A reach is one bend travelling base to tip, with a stereotyped speed curve; that is the
   readable signature.** Gutfreund et al. (J Neurosci 1996, 16(22):7297-7307) filmed Octopus
   vulgaris reaching: the arm extends by a wave-like bend that propagates from base to tip along a
   simple, slightly curved, roughly planar path from body to target; about 70% of reaches share one
   tangential velocity profile that stays the same when normalised for speed and distance, and the
   same pattern appears in spontaneous extensions with no target
   ([HUJI CRIS abstract](https://cris.huji.ac.il/en/publications/organization-of-octopus-arm-movements-a-model-system-for-studying/),
   [ELSC summary](https://elsc.huji.ac.il/?p=5182)). The 1998 follow-up ties the bend to a
   propagating muscle-activation wave peaking just ahead of the bend
   ([PMC6793066](https://pmc.ncbi.nlm.nih.gov/articles/PMC6793066), page blocked by reCAPTCHA;
   abstract text via search). Implication: animate ONE controlled variable (where the bend is, as a
   0..1 position along the arm over time), not every joint.

2. **Reaches also stretch, and fetching uses three pseudo-joints.** A 3D study found reaching
   combines bend propagation with elongation of the section behind the bend (strain from slight
   shortening up to about 1.8x), and some reaches form the bend further out and mostly elongate
   ([HUJI CRIS](https://cris.huji.ac.il/en/publications/stereotypical-reaching-movements-of-the-octopus-involve-both-bend/)).
   When bringing food to the mouth, octopuses form "quasi-joints" like shoulder, elbow and wrist,
   with two segments of similar, consistent length (Sumbre et al., Nature 433, 2005)
   ([Scientific American](https://www.scientificamerican.com/article/octopus-borrows-vertebrat/));
   the 2006 follow-up found fetching is controlled in joint-angle terms
   ([Phys.org](https://m.phys.org/news/2006-04-octopus-elbow.html)). Implication: two distinct
   motions read as "octopus": a whip-out reach (travelling bend) and a stiff, jointed haul-back
   (pull a building or tank in like a three-segment arm). That maps directly onto grab then drag.

3. **Four deformations cover everything; front arms do most of the work.** Bennice et al. (Sci
   Rep 15:31875, 2025) coded wild footage into 12 arm actions built from shortening, elongating,
   bending and torsion; every arm could do every action, anterior arms did more (about 64% from the
   front four) and rear arms led locomotion such as raising the body
   ([FAU news](https://www.fau.edu/newsdesk/articles/octopus-arms-in-action),
   [Popular Science](https://www.popsci.com/environment/octopus-arms-flexibility/); primary paper
   not read). Implication: front arms grab and smash, rear arms prop the body out of the water.
   Arms acting partly independently is also biologically right: the axial nerve cords hold about
   four times the neurons of the central brain
   ([UChicago](https://biosciences.uchicago.edu/news/articles/segmented-nervous-systems-allow-octopuses-control-each-arm-and-suckers));
   the oft-quoted "two-thirds of neurons in the arms" figure appears only in secondary sources
   ([Advanced Science News](https://advancedsciencenews.com/octopus-suckers-inspire-soft-robotic-arms)).
   Sucker attachment works without the brain; detachment needs it
   ([UW Psychology news](https://psych.uw.edu/news/2890) reporting the ASU study), which supports
   "suckers grab on contact, letting go is a decision".

4. **FABRIK is the cheap, smooth chain solver; it is already what the repo uses.** FABRIK
   (Aristidou and Lasenby, Graphical Models 73(5):243-260, 2011) places each joint by finding a point
   on a line, uses no rotation angles or matrices, converges in few iterations at low cost, and
   supports constraints and multiple end effectors
   ([paper PDF](https://perso.liris.cnrs.fr/alexandre.meyer/teaching/master_charanim/M2_3_video_IK_Procedurale/FABRIK.pdf),
   [bibtex](https://andreasaristidou.com/publications/bibtex/FABRIK.html)). Godot's own docs
   characterise the trade-off: CCD is rotation-based, suits chains with joint limits, but can flip
   and oscillate when the target is near the root; FABRIK tracks more smoothly
   ([CCDIK3D docs](https://docs.godotengine.org/en/latest/classes/class_ccdik3d.html)). Gradient
   descent IK can produce a spiral wrap by also scoring tip orientation, and joint limits send
   ripples down the chain ([Alan Zucconi, IK for tentacles](https://www.alanzucconi.com/2017/04/12/tentacles/)),
   but it is costlier and harder to tune than FABRIK plus target points.

5. **Verlet point chains with distance constraints are the proven cheap "physical" layer.**
   Jakobsen's GDC 2001 "Advanced Character Physics" (Hitman: Codename 47) models bones as points
   joined by simple constraints, much cheaper than rigid bodies, with believability and stability
   as the goals; with few iterations it can look "bouncy"
   ([Game Developer copy](https://gamedeveloper.com/programming/advanced-character-physics),
   [Wikipedia: Ragdoll physics](https://en.wikipedia.org/wiki/Ragdoll_physics),
   [gamedev.net thread](https://gamedev.net/forums/topic/296733-verlet-with-rigid-body/2881006/)).
   Rain World builds creatures from points held at set distances with cosmetic parts layered on top
   ([Unity blog](https://unity.com/en/blog/exploring-procedural-design-rain-world),
   [Game Developer](https://gamedeveloper.com/design/crafting-the-complex-chaotic-ecosystem-of-i-rain-world-i-));
   its GDC 2016 Animation Bootcamp talk is listed but I found no transcript
   ([gameanim.com](https://www.gameanim.com/category/learn/presentations/page/7/)).

6. **Godot now ships a full IK family, but only for Skeleton3D bones (verified versions).**
   Per the developer's own article: SkeletonModifier3D base and LookAtModifier3D in 4.4;
   SpringBoneSimulator3D and BoneConstraint3D (Aim/Copy/ConvertTransform) in 4.5; IKModifier3D with
   TwoBoneIK3D, ChainIK3D, SplineIK3D, IterateIK3D, FABRIK3D, CCDIK3D, JacobianIK3D,
   BoneTwistDisperser3D and LimitAngularVelocityModifier3D in 4.6
   ([godotengine.org, IK returns in 4.6](https://godotengine.org/article/inverse-kinematics-returns-to-godot-4-6/)).
   This corrects GameFromScratch's "4.4 gets jiggle physics"
   ([gamefromscratch](https://gamefromscratch.com/godot-4-4-gets-jiggle-physics/)): SpringBoneSimulator3D
   is 4.5. IterateIK3D defaults: max_iterations 4, angular_delta_limit about 2 deg per bone per
   iteration, `deterministic` false (true = solve from the un-IK'd pose each frame, same input same
   output, but may never reach the goal with few iterations); per-joint rotation axis and
   JointLimitation3D ([IterateIK3D docs](https://docs.godotengine.org/en/latest/classes/class_iterateik3d.html)).
   SplineIK3D aligns bones along a Path3D, twist from Curve3D tilt
   ([SplineIK3D docs](https://docs.godotengine.org/en/latest/classes/class_splineik3d.html)).
   SpringBoneSimulator3D has stiffness, drag, gravity (a velocity), radius, its own sphere/capsule
   collisions not tied to the physics server, per-joint config, and warns against scaled skeletons
   ([docs](https://docs.godotengine.org/en/latest/classes/class_springbonesimulator3d.html)).
   I found no 4.7 changes to this family.

7. **The repo's rig is node-per-bone voxels, not Skeleton3D, so none of item 6 plugs in without a
   rig rewrite; the custom chain is already the simpler path.** `scenes/kaiju_rig.gd` draws each
   bone as a Node3D with its own MultiMesh voxels and already runs tentacles as Verlet
   `SpringChain`s with stiffness-to-pose, damping 0.9, gravity, a ground clamp, tip `pins` solved
   by a FABRIK backward pass, and a whole-chain `contract` for hauling; `sim/tentacles.gd` decides
   strikes and grab-and-throw in the sim (seeded) (repo files, read 2026-10-21). Two gaps against
   the brief: `simulate_chains` uses a variable `dt = min(delta, 1/30)` (feel changes with frame
   rate; Verlet with varying dt is inaccurate), and the reach has no travelling bend, so a strike
   reads as a spring snapping to a pin rather than an octopus unrolling.

8. **Heavy, not noodly, comes from a clamped angular speed, slow wavefront and few segments.**
   Godot itself pairs deterministic IK with LimitAngularVelocityModifier3D to stop large per-frame
   swings ([Godot IK article](https://godotengine.org/article/inverse-kinematics-returns-to-godot-4-6/)),
   and IterateIK3D's per-iteration angle cap does the same inside the solver
   ([IterateIK3D docs](https://docs.godotengine.org/en/latest/classes/class_iterateik3d.html)).
   David Rosen's GDC 2014 talk argues for a handful of key poses blended by code with springs
   (Overgrowth used about 13 keyframes in total)
   ([Game Developer video](https://gamedeveloper.com/design/video-an-indie-approach-to-procedural-animation),
   [Unity forum note](https://discussions.unity.com/t/an-indie-approach-to-procedural-animation-gdc-video-talk/538228)).
   Inference (no source measured kaiju-scale tentacle timing): heaviness = a peak bend speed scaled
   so a 100 m arm takes a second or more to unroll, low gravity sag on the base, tip lag, a clamped
   per-bone turn rate, and a hit-stop on contact.

9. **Games: few documented tentacle systems; most famous ones are hand-keyed or shader/Houdini.**
   Sea of Thieves' Kraken tentacles were covered in Rare's GDC 2019 tech-art talk on shaders and
   Houdini ([Vimeo, Valentine Kozin](https://vimeo.com/326413164)), and players criticised the fight
   as "just random tentacles" ([Windows Central](https://www.windowscentral.com/sea-of-thieves-kraken)),
   a warning that tentacles without a readable grab-and-pull beat do not land. Carrion (MonoGame) has
   tentacles latching onto any surface, but I found no technical write-up
   ([Game Informer](https://www.gameinformer.com/review/carrion/carrion-review-all-tentacles-and-repetition),
   [wnhub](https://wnhub.io/news/engines/item-17845)). The paid Unreal "Octopus Backpack" plugin
   advertises tentacles that bend around obstacles, entangle and grab by IK, and needs physics
   substeps below about 40 FPS ([Fab listing](https://www.fab.com/listings/bb5b2bbb-ae6e-4be8-81d7-22bdb566082e?lang=en)),
   which matches the fixed-substep advice. Open-source Godot rope: Verlet Rope 4 (.NET, MIT, Godot
   4.4+) ([asset library](https://godotengine.org/asset-library/asset/edit/19446)); C# only, so not a
   fit for a GDScript project, and not needed given item 7.

## Sources
- https://cris.huji.ac.il/en/publications/organization-of-octopus-arm-movements-a-model-system-for-studying/
- https://elsc.huji.ac.il/?p=5182
- https://pmc.ncbi.nlm.nih.gov/articles/PMC6793066
- https://cris.huji.ac.il/en/publications/stereotypical-reaching-movements-of-the-octopus-involve-both-bend/
- https://arxiv.org/pdf/2304.08413 (muscular-hydrostat model reproducing the bend wave, about 30 cm/s peak bend speed)
- https://www.scientificamerican.com/article/octopus-borrows-vertebrat/
- https://m.phys.org/news/2006-04-octopus-elbow.html
- https://www.fau.edu/newsdesk/articles/octopus-arms-in-action
- https://www.popsci.com/environment/octopus-arms-flexibility/
- https://biosciences.uchicago.edu/news/articles/segmented-nervous-systems-allow-octopuses-control-each-arm-and-suckers
- https://advancedsciencenews.com/octopus-suckers-inspire-soft-robotic-arms
- https://psych.uw.edu/news/2890
- https://perso.liris.cnrs.fr/alexandre.meyer/teaching/master_charanim/M2_3_video_IK_Procedurale/FABRIK.pdf
- https://andreasaristidou.com/publications/bibtex/FABRIK.html
- https://www.alanzucconi.com/2017/04/12/tentacles/
- https://gamedeveloper.com/programming/advanced-character-physics
- https://en.wikipedia.org/wiki/Ragdoll_physics
- https://gamedev.net/forums/topic/296733-verlet-with-rigid-body/2881006/
- https://unity.com/en/blog/exploring-procedural-design-rain-world
- https://gamedeveloper.com/design/crafting-the-complex-chaotic-ecosystem-of-i-rain-world-i-
- https://www.gameanim.com/category/learn/presentations/page/7/
- https://godotengine.org/article/inverse-kinematics-returns-to-godot-4-6/
- https://gamefromscratch.com/godot-4-4-gets-jiggle-physics/
- https://docs.godotengine.org/en/latest/classes/class_ccdik3d.html
- https://docs.godotengine.org/en/latest/classes/class_iterateik3d.html
- https://docs.godotengine.org/en/latest/classes/class_splineik3d.html
- https://docs.godotengine.org/en/latest/classes/class_springbonesimulator3d.html
- https://gamedeveloper.com/design/video-an-indie-approach-to-procedural-animation
- https://discussions.unity.com/t/an-indie-approach-to-procedural-animation-gdc-video-talk/538228
- https://vimeo.com/326413164
- https://www.windowscentral.com/sea-of-thieves-kraken
- https://www.gameinformer.com/review/carrion/carrion-review-all-tentacles-and-repetition
- https://wnhub.io/news/engines/item-17845
- https://www.fab.com/listings/bb5b2bbb-ae6e-4be8-81d7-22bdb566082e?lang=en
- https://godotengine.org/asset-library/asset/edit/19446
- Repo: scenes/kaiju_rig.gd (SpringChain, simulate_chains), sim/tentacles.gd, scenes/kaiju_model.gd

## For Kaiju Incremental

Frame: tentacle motion stays presentation. The sim (`sim/tentacles.gd`) already decides which arm
strikes what and when, seeded; the rig only has to make that decision read. Nothing below changes
outcomes, so none of it needs the sim review. Ranked simplest first.

1. **Fixed substep for the existing Verlet chains (keep everything else).** Replace
   `dt = min(delta, 1/30)` with an accumulator stepping at a fixed 1/60 s (cap 4 substeps a frame).
   Same feel at 30, 60 or 144 FPS, and captures become repeatable for review. Cost: about 15 lines
   in `kaiju_rig.gd`, no new nodes; 8 arms x about 8 joints x 3 passes is a few thousand vector ops
   per substep, trivial in GDScript. Also move STIFFNESS/DAMPING/GRAVITY/passes into `data/` per hard
   rule 4.
2. **Reach as a travelling bend, using the `drive` bases the chain already has.** On a strike or
   grab event, run a "wavefront" s(t) from 0 to 1 along the arm with an ease-in-out (bell-shaped
   speed, item 1): segments behind the front straighten toward the target, the segment at the front
   carries the bend, segments ahead stay curled. Optional 10-20% stretch of the section behind the
   front (item 2) via `contract` > 1. Pin the tip only when s reaches 1. This is the single biggest
   "reads as octopus" change. Cost: one small function per chain (about 40-60 lines), one tunable
   block (reach time per growth stage, curl angle); zero runtime cost of note.
3. **Haul-back as a three-segment jointed fetch.** While dragging a grabbed tank or chunk, drive the
   chain as two or three stiff runs with sharp pseudo-joints (item 2), contracting, instead of a
   soft curve. Gives the "heavy pull" beat that the Sea of Thieves Kraken lacked (item 9). Cost:
   a second drive profile on the same chain, about 30 lines.
4. **Heavy feel controls.** Clamp per-bone turn rate per substep (the LimitAngularVelocity idea,
   item 8), tip-lag via lower stiffness toward the tip, hit-stop plus the existing `foot_planted`
   ("t0".."t7") on contact for dust, shake and sound, and scale reach time by growth stage (baby
   whippy, adult slow). Cost: a few lines and tunables; the hit-stop must be visual-only.
5. **Wrap a tower with helix target points, pinned tip-first.** At grab time, sample K points on a
   helix around the building's footprint (radius = half-width + arm thickness, pitch about 1-1.5
   arm thicknesses, 1.5-2 turns, starting at grab height and winding down toward the base).
   Over about 0.5-1 s, pin joints from the tip inward to successive helix points (the existing
   `pins` dictionary supports several pins; the FABRIK pass needs to iterate between pins rather
   than only from the highest one). No collision needed, because the helix already clears the
   walls. Cost: a helix sampler plus a multi-pin FABRIK pass, about 60-80 lines; needs the building
   bounds from the sim event. When the sim topples or carves the tower, release pins (sim event
   drives it). Inference, not sourced: wrapping tip-first then tightening is my design reading of
   the sucker findings (item 3), not a measured octopus behaviour.
6. **Suckers and segments, voxel style.** Keep one Node3D per segment with its own voxels (the
   current rig). Suckers as a row of lighter, slightly recessed voxels on the underside of each
   segment's voxel block, baked into the .kvox per stage, shrinking toward the tip; no runtime
   cost. Rotate segments so the sucker row faces the target when gripping (a twist along the chain,
   the job BoneTwistDisperser3D does in Godot; here a per-segment roll). Joint filler cubes
   (`JOINT_INSET`) already hide gaps on bends. Cost: art only plus a roll term in `aim`.
7. **Idle sway.** Low-frequency seeded noise added to `drive` per arm, phase offset per arm, larger
   toward the tip, rear arms calmer (they prop the body). Use a hash of (arm index, time) rather
   than the sim RNG so presentation never consumes sim randomness. Cost: about 10 lines.
8. **Not recommended now:** switching to Skeleton3D to use FABRIK3D/CCDIK3D/SplineIK3D/
   SpringBoneSimulator3D. It would replace a working voxel rig, MultiMesh skins and the gait code
   for nodes that do what the custom chain already does; revisit only if the rig moves to a skinned
   mesh for other reasons. C++ GDExtension for chains is also unnecessary at this size; profile first.

Pseudocode for 2 + 5 inside the existing loop (per fixed substep h):

```
# reach: front s in [0,1] eases over reach_time; bend lives at the front
s = smoothstep(0, 1, t / reach_time)
for i in segments:
    u = i / (n - 1)
    if u < s:  drive[i] = aim_toward(target, i) * stretch(1 + 0.15 * (s - u))
    elif u - s < band: drive[i] = curl(curl_angle * (u - s) / band)   # the travelling bend
    else: drive[i] = curl(curl_angle)                                  # still coiled
verlet_step(chain, h)                      # existing: pull to driven pose, damping, gravity
clamp_turn_rate(chain, max_deg_per_step)   # heavy
# wrap: pins grow tip-first over wrap_time, each pin a helix point
for k in pinned_count(t):  chain.pins[n - k] = helix(base, radius, pitch, start_angle, k)
for pass in passes:
    fabrik_between_pins(chain)   # backward from each pin to the previous pin, then forward from root
    keep_lengths_from_root(chain)
```

## Evidence gaps
No source measures how fast a kaiju-scale tentacle should move to read as heavy (item 8 is
inference); I found no technical write-up of Carrion's, Sea of Thieves' or Rain World's tentacle
code, no tested helix-wrap method (recommendation 5 is my design), the primary Bennice 2025 and
Gutfreund 1998 papers were not read in full (press releases and abstracts only), the two-thirds
neuron figure lacks a primary source, the "Godot Renik" / "Twisted IK" addons were not checked,
and I found no Godot 4.7 notes on the IK family.
