# Walking giant kaiju: what sells weight, and what to change in Kaiju Incremental

Research notes, 2026-10-21. Read only: no repo edits. Code read: `scenes/kaiju_rig.gd`, `scenes/kaiju_gait.gd`,
`scenes/gait_biped.gd`, `scenes/biped_body.gd`, `scenes/gait_clip.gd`, the top of `scenes/gait_hexapod.gd`,
`scenes/rampage.gd` (`_on_footfall`), `tools/blender/motion_test.py` (walk bake parameters), `data/species.json`.

## Key findings

1. **Slowness is the strongest single scale cue, and the physics gives a number for it.** Film miniatures are
   shot at 24 fps x sqrt(scale factor) so that gravity-driven motion reads full size (1/48 scale -> about 166 fps)
   ([CML miniature formula](https://cinematography.net/edited-pages/MiniatureFormula.htm)); the 1998 *Godzilla*
   shot its 1/24 suit work at about 200-360 fps ([American Cinematographer](https://theasc.com/magazine/jun98/godzilla/art2/pg2.htm)),
   and Godzilla action has been slowed up to 3x "to add a sense of scale" ([Inverse](https://www.inverse.com/entertainment/22234-special-effects-in-godzilla-movies-history)).
   Biology says the same through dynamic similarity: animals at equal Froude number (v^2 / g x hip height) move
   alike, with equal relative stride length and duty factor ([Bullimore & Burn review, PMC3798186](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3798186/)).
   Alexander's trackway fit, relative stride = 2.3 x Froude^0.3 (stride / hip height), is the standard tool
   ([Ruiz & Torices 2013](https://www.originalwisdom.com/wp-content/uploads/bsk-pdf-manager/2019/03/Ruiz-and-Torices_2013_Humans-running-at-stadiums-and-beaches-and-the-accuracy-of-speed-estimation-from-fossil-trackways.pdf);
   [Watkins summary](https://www.sjsu.edu/faculty/watkins/alexander.htm)). Worked for a 100 m kaiju with a 46 m hip
   walking at Froude 0.25: v = 10.6 m/s, stride = 1.52 x 46 = 70 m, so about 6.6 s per stride (3.3 s per step).
   Quick short steps read as a small animal however big the model is.

2. **Tanaka's five rules for giants (Shadow of the Colossus / The Last Guardian, CEDEC 2021)** are the best
   shipped-game evidence ([Game Anim summary](https://www.gameanim.com/?p=76076)): (1) mass: a giant cannot start or
   change motion suddenly and follows smooth curves, but it can stop suddenly; (2) gravity is the same at any size,
   so judge a giant's weight against real animals of similar size (dinosaurs); (3) muscle: heavy head and arms tend
   to fall, muscles stiffen under load, so do not overuse overlapping action; (4) "animation resolution": just
   slowing an animation down removes detail, so high-frequency detail must be added back, especially on impacts,
   and the vibrations must not be too fast; (5) giants cannot be faked: glitches (foot slide, pops) are seen at
   once, and additive layers should blend motion rather than quick transitions.

3. **Duty factor (share of the stride a foot is down) separates walk from run, and heavy walkers sit high.**
   Above 0.5 is a walk, below is a run ([Gait overview](https://wikimili.com/en/Gait)); the classic lateral-sequence
   walk is duty factor 0.75 with a 0.25 lateral phase lag, one leg in the air at a time
   ([arXiv 2112.00662](https://arxiv.org/pdf/2112.00662)). Elephants never get a whole-body aerial phase even
   above Froude 3; duty factor falls to about 0.37 only at top speed, forelimbs stay down longer than hindlimbs
   ([Hutchinson et al., SICB "Do elephants run?"](https://sicb.org/?p=36424);
   [JEB 2006 elephant kinematics](https://cob.silverchair.com/jeb/article/209/19/3812/16362/The-locomotor-kinematics-of-Asian-and-African)).
   A long stance (0.65-0.75) with the body visibly travelling over a planted foot is what "heavy" looks like.

4. **Quadruped walk footfall: lateral sequence, LH -> LF -> RH -> RF, each a quarter cycle apart.** In a
   lateral-sequence gait the same-side forefoot lands after the hind foot, within 0-50% of the cycle
   ([Cartmill et al. 2002, support polygons](https://www.originalwisdom.com/wp-content/uploads/bsk-pdf-manager/2019/10/Cartmill-et-al_2002_Support-polygons-and-symmetrical-gaits-in-mammals.pdf));
   most mammals use it because its tripods of support are larger than the diagonal sequence's
   ([Hildebrand 1980](https://www.originalwisdom.com/wp-content/uploads/bsk-pdf-manager/2019/03/Hildebrand_1980_The-Adaptive-Significance-of-Tetrapod-Gait-Selection.pdf)).
   Elephants keep the lateral sequence at all speeds, moving towards a 25% offset (singlefoot) as they speed up
   ([JEB 2006](https://cob.silverchair.com/jeb/article/209/19/3812/16362/The-locomotor-kinematics-of-Asian-and-African)).
   Diagonal pairs stepping together (front-left with hind-right) is a trot, not a walk: fine for a skittering
   insect, wrong for a heavy quadruped.

5. **Foot sliding is solved by locking a planted foot in world space and deriving the walk's phase from distance
   travelled (speed = stride length x cadence), then IK the leg to the lock.** This is how procedural walkers work:
   a foot steps only when its predicted landing spot strays past a threshold from where it stands, moving in an arc,
   in alternating diagonal pairs ([80.lv Godot 4.5 spider](https://80.lv/articles/ik-driven-procedural-spider-locomotion-in-godot-4-5)).
   Rain World builds creatures from physics points and defines limbs plus rules for using them instead of clips
   ([Steam discussion](https://steamcommunity.com/app/312520/discussions/0/3761103414979115659);
   [Unity blog, Jakobsson](https://unity.com/en/blog/exploring-procedural-design-rain-world)); David Rosen's GDC 2014
   talk shows interactive, fluid motion from very few keyframes with code doing the repetitive work
   ([Game Developer video](https://gamedeveloper.com/design/video-an-indie-approach-to-procedural-animation)).
   Tanaka defines procedural animation the same way and used it on SotC's horse spine and on Trico
   ([Game Anim, Tanaka](https://www.gameanim.com/tag/masanobu-tanaka/)).

6. **The cost of fitting a clip to speed: scaling playback rate alone is what makes a giant look frantic.** If a
   walk's stride is fixed, cadence must rise linearly with speed. Craft advice for very large creatures is the
   reverse: double the length, halve the speed, while avoiding dead holds
   ([Polycount thread](https://polycount.com/discussion/comment/1423704), practitioner opinion), and heavy things have
   longer anticipations and settles but move fast in between ([itch.io game-anim critique](https://itch.io/jam/sfasx-game-animation/rate/553420)).
   The standard engine answer is several walks at different stride lengths blended by speed and synced by phase
   (a 1D blend space), so stride grows with speed and cadence rises only a little.

7. **Godot's root motion and IK nodes need a Skeleton3D bone; this rig has none.** `AnimationMixer.root_motion_track`
   takes position/rotation/scale 3D tracks and "a bone must be specified"
   ([Godot docs, AnimationMixer](https://docs.godotengine.org/en/stable/classes/class_animationmixer.html)).
   The MIT IK add-ons (Godot IK, OSIK) also target skeletons
   ([Godot IK asset](https://godotengine.org/asset-library/asset/edit/15579)). For a node-per-bone rig the useful
   ideas (phase-synced blending, distance-driven phase) are a few lines of script, which this repo already has.

8. **Weight-shift craft that applies at any size:** the centre of gravity drops before effort (anticipation), a wide
   base reads as load, poses and weight shifts must read in silhouette, and secondary motion (sway, trunk or torso
   drag) goes on last ([Animation Mentor, heavy lift](https://www.animationmentor.com/?p=89314); Udemy elephant-walk
   course outline on footfall order, weight transfer and upper-body sway
   ([Udemy](https://www.udemy.com/course/how-to-animate-an-elephant-walk-cycle-in-maya/))).

## Sources

- CML miniature frame-rate formula: https://cinematography.net/edited-pages/MiniatureFormula.htm
- American Cinematographer, Godzilla 1998: https://theasc.com/magazine/jun98/godzilla/art2/pg2.htm
- Inverse, Godzilla effects history: https://www.inverse.com/entertainment/22234-special-effects-in-godzilla-movies-history
- Dynamic similarity and swing phase (PMC): https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3798186/
- Ruiz & Torices 2013 (Alexander formula): https://www.originalwisdom.com/wp-content/uploads/bsk-pdf-manager/2019/03/Ruiz-and-Torices_2013_Humans-running-at-stadiums-and-beaches-and-the-accuracy-of-speed-estimation-from-fossil-trackways.pdf
- Watkins, Alexander's formula: https://www.sjsu.edu/faculty/watkins/alexander.htm
- Tanaka, 5 rules for animating colossi: https://www.gameanim.com/?p=76076
- Tanaka tag (procedural, Trico): https://www.gameanim.com/tag/masanobu-tanaka/
- Hutchinson et al., Do elephants run?: https://sicb.org/?p=36424
- JEB 2006 elephant kinematics: https://cob.silverchair.com/jeb/article/209/19/3812/16362/The-locomotor-kinematics-of-Asian-and-African
- arXiv 2112.00662 (LS walk D 0.75): https://arxiv.org/pdf/2112.00662
- Gait overview: https://wikimili.com/en/Gait
- Cartmill et al. 2002: https://www.originalwisdom.com/wp-content/uploads/bsk-pdf-manager/2019/10/Cartmill-et-al_2002_Support-polygons-and-symmetrical-gaits-in-mammals.pdf
- Hildebrand 1980: https://www.originalwisdom.com/wp-content/uploads/bsk-pdf-manager/2019/03/Hildebrand_1980_The-Adaptive-Significance-of-Tetrapod-Gait-Selection.pdf
- 80.lv Godot 4.5 procedural spider: https://80.lv/articles/ik-driven-procedural-spider-locomotion-in-godot-4-5
- Rain World Steam discussion: https://steamcommunity.com/app/312520/discussions/0/3761103414979115659
- Unity blog, Rain World: https://unity.com/en/blog/exploring-procedural-design-rain-world
- Rosen GDC 2014: https://gamedeveloper.com/design/video-an-indie-approach-to-procedural-animation
- Polycount: https://polycount.com/discussion/comment/1423704
- itch.io critique: https://itch.io/jam/sfasx-game-animation/rate/553420
- Animation Mentor: https://www.animationmentor.com/?p=89314
- Udemy elephant walk: https://www.udemy.com/course/how-to-animate-an-elephant-walk-cycle-in-maya/
- Godot AnimationMixer: https://docs.godotengine.org/en/stable/classes/class_animationmixer.html
- Godot IK asset (MIT): https://godotengine.org/asset-library/asset/edit/15579

## For Kaiju Incremental

**What the code does now (grounding).** `kaiju_rig.gd` builds one Node3D per bone and hands motion to a gait per
body plan: `ClipGait.or_biped` for "biped", `HexapodGait`, `RadialGait`. All three reptilian stages ship a `.kclip`,
so **the reptilian walks on ClipGait** (baked Blender clips), not on `BipedGait` (that is the fallback). ClipGait
already does the hard parts right: walk phase advances by distance / stride (`clip_time += speed*dt/stride()`),
planted feet are locked in world (`_lock`) with two-bone IK re-solved (`_reach`), a catch step when a lock is
overreached, and every plant emits `foot_planted`, which `rampage.gd` turns into footstep sound, dust, a shockwave
ring and a camera dip. So foot sliding is solved in method; the problem is **timing**. Facts from the bake
(`tools/blender/motion_test.py`): models normalised to 100 m tall, hip at about 46% height; adult walk stride
46.7 m per cycle, 48 frames at 24 fps = **2.0 s per cycle**, `DUTY = 0.62`, so the authored speed is 23.3 m/s.

- *Estimate, needs measuring:* that authored walk is already at Froude about 1.2 for a 46 m hip, a run speed in real
  gravity, with a relative stride of only 1.0 (Alexander predicts about 2.4 at that Froude). And in game the clip is
  stretched further: playback rate = sim speed / world stride. If 10 game units = 100 m (KaijuModel.MODEL_HEIGHT 10)
  and the Reptilian's base speed 5.5 is units/s, the sim moves it at about 55 m/s at body scale 1, so the 2.0 s
  cycle plays in about 0.85 s (about 2.4x authored, about 2.4 footfalls/s), more with speed upgrades. That is faster
  than a human walking cadence and is the most likely cause of "not great".
- `BipedGait` (fallback) has the same shape: duty 0.6 (`SWING_WALK 0.4`), a stance excursion cap of 0.48 hip heights
  (`STANCE_REACH`) that forces short strides, so cadence climbs with speed.
- ClipGait's footfall strength is `0.2 + speed_k()` with no life-stage factor (BipedGait scales by stage), and the
  idle -> walk cross-fade is 0.25 s (`BLEND_SECONDS`).
- `HexapodGait` (mantis) skitters in diagonal pairs by design; that is a trot-like insect read and fine.
  No quadruped body plan exists yet.

**Ranked recommendations (simplest viable first):**

1. **Measure cadence before changing anything** (about 2 h, no art). In an existing capture probe, log per stage at
   base speed and max-upgrade speed: footfalls/s, clip playback rate vs authored (`speed / stride()` x 2.0 s), duty
   factor, and speed in hip heights/s. Pass bar to propose: adult playback rate within 0.8-1.2x authored (about
   1 footfall/s or slower), `max_drift` unchanged. This turns "not great" into a number.
2. **Lengthen the stride, not the cadence: re-bake the walk to match the game's speed** (about half a day: data in
   `motion_test.py` landmark sets `stride`, `cycle`, `DUTY`, re-bake, capture). Set each stage's `stride` so
   sim speed / stride gives the cycle the director likes (for the adult, roughly 1.5-2.5 hip heights per cycle and
   2-3 s per cycle), and raise `DUTY` 0.62 -> about 0.70 for adolescent and adult (long stance, body travelling over
   the planted foot; finding 3). Cost risk: longer strides need more leg reach, so check the catch-step rate
   (`RESTEP_REACH`) in the capture. If a long-enough stride is not reachable at the sim's speed, that is a
   **director decision**: a slower walk speed in the sim, or accept a faster cadence (Tanaka rule 1: giants are
   generally slow). Put it to him with two clips.
3. **Every footfall gets an impact, not only stomps** (about 2-3 h). On each ClipGait plant: a 2-4 frame pelvis
   compression and recovery (as `BipedBody.plant` already does procedurally), a small `SpringChain.kick` to tail and
   belly/jaw scaled by strength (today only `stomp()` kicks the tail), and the BipedGait life-stage factor on
   strength so an adult's step shakes the camera more than a cub's. This is Tanaka rule 4: put high-frequency detail
   back on contact, keeping vibration slow, not buzzy.
4. **Ease in on starts, stop hard** (about 1-2 h). Lengthen idle -> walk to about 0.5-0.8 s for adults with a small
   forward lean as anticipation, and keep walk -> idle short (Tanaka rule 1). Feet stay locked, so the sim's
   instant start does not cause sliding.
5. **Speed range without frantic legs: two walks blended by speed** (about 1 day after #2). Bake a slow-long and a
   fast-long walk with the same number of cycles and planted flags, mix them with the existing `KaijuClips.mix` at a
   weight from speed and a shared normalised phase (what Godot's BlendSpace1D with sync does). Only needed if
   upgrades push speed well past the base walk; #1 shows whether they do.
6. **Keep the hybrid; do not migrate to AnimationTree** (cost: none). Keyed clips plus distance-driven phase plus
   foot lock plus IK is the shipped-game pattern; AnimationTree root motion needs a Skeleton3D bone and would mean
   rebuilding the rig. Procedural stepping (as Hexapod and Radial already do) scales best across many body plans;
   keyed clips give the director's approved look (D-047) for the hero species. Both stay.
7. **If a quadruped stage is ever added** (about 1 day on BipedGait's per-leg phase `offset` scheme): lateral
   sequence offsets LH 0, LF 0.25, RH 0.5, RF 0.75, duty about 0.70-0.75, forelimbs slightly longer stance, never
   diagonal pairs at a walk (finding 4).
8. **Do not add more tail or head overlap** (cost: none). Tanaka rule 3 warns against overused overlap on giants;
   ClipGait's `TAIL_MAX 0.008` cap is consistent with that.

**Evidence gaps:** the in-game cadence numbers above are estimates (units-to-metres mapping and whether sim speed
scales with body scale were not verified; recommendation 1 measures them); no primary Capcom, Toho-game or Gigabash
source on walk timing was found; the Rain World and Rosen talks were seen only through summaries, not the
recordings; the JEB elephant paper returned 403, so its exact walk duty factors are not quoted; Alexander's 2.3 x
Fr^0.3 constants come from secondary sources.
