# Claw swipe arm: plan and pass bars (2026-10-25)

Director, 2026-10-25: "the arm movement during the claw swipe animation is really bad ... Especially the baby's arm
looks really bad, it moves too fast and stretches the limb beyond anatomic belief"; "it shouldnt be complex, dont
improvise, plan, research then implement, then iterate". Rulings kept: D-190 (the swipe stays straight ahead, on the
snout line), D-095/D-096 (the rake every 2 s). Owner: claw-anim session; effects (trail, flash, sparks) stay the VFX
lead's.

## 1. Measured today (origin/main cee43552, `tools/claw_probe.gd`, 60 Hz, headless, the croc at each stage)

| | baby | Behemoth | Colossus |
|---|---|---|---|
| arm bone length vs rest | +60% in game (body 0.5), +38% at body 1.0 | +38% (0.9) | +25% (1.3) |
| peak angular speed upper / fore / hand (deg/s) | 6692 / 8042 / 8458 | same | same |
| claw tip peak speed (hip heights/s) | 221 | 81 | 71 |
| elbow range (deg) | 2-142 (locks straight, then folds 142 in one frame) | 2-82 | 2-73 |
| arm away from its held pose | 0.58 s | 0.58 s | 0.58 s |

Why:
1. **The stretch is coded in.** `BipedSwing._reach_arm` scales the upper-arm bone (and so the whole arm) by
   `claw_fx.arm_reach_young` 1.6 on a young body and `arm_reach_adult` 1.25 on an adult, to make the arm "reach".
2. **The strike is 2 frames.** The strike is 0.12 s, and 70% of it is spent going up and out (`arc_at`), so the arm
   crosses about 140 deg in the last 0.036 s, then snaps back out wide in 0.057 s (`arm_settle`) before going home.
3. **Directions are lerped, not rotated.** Each bone's direction is a straight-line lerp between two vectors that
   point almost opposite ways; mid-way the vector passes near zero and the bone flips (a 120 deg one-frame jump at
   f19-f20, elbow 142 -> 80 deg at f5-f6).
4. **Nothing scales with size**: the same seconds at every stage. The baby's arm is long for its hip, so the same
   seconds make its claw tip fastest (221 hip heights/s).

## 2. Research (sources)
- Attacks read in three phases: anticipation (long, slow, big arc), a short strike, then recovery and
  follow-through; heavier means longer anticipation and recovery ([Slynyrd Pixelblog 9](https://slynyrd.com/blog/2018/9/8/pixelblog-9-melee-attacks),
  [Dark Souls 3 attack anatomy](https://www.gamedeveloper.com/game-platforms/anatomy-of-an-enemy-attack-in-dark-souls-3)).
- Successive breaking of joints: shoulder leads, elbow then wrist follow a beat later; motion runs on arcs
  ([Brian Lemay, successive breaking](https://www.brianlemay.com/Pages/animationschool/animation/1stsemesteranimation/successivebreaking.html)).
- Size: a limb swings like a pendulum, so its swing time grows with the square root of its length (dynamic
  similarity; swing duration ~ mass^0.16-0.18, i.e. ~ length^0.5) ([Raichlen et al. 2013](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3798186/),
  [Sci. Rep. 2016](https://www.nature.com/articles/srep28825)).
- Joints: theropod and crocodylian forelimbs have limited shoulder and elbow ranges (Dilophosaurus elbow cannot fold
  past a right angle; alligator ROM studies) ([Senter/Sullivan via PE](https://palaeo-electronica.org/content/pdfs/900.pdf),
  [alligator ROM, JEB 216:275](https://cob.silverchair.com/jeb/article/216/2/275/11664/Using-the-American-alligator-and-a-repeated)).
  No peer-reviewed bear swipe timing exists; the phase shape above is the reference.

## 3. The fix (the simplest that meets the bars; procedural, no new system)
1. Delete the reach scaling: bones keep their length (reach comes from the elbow opening, not a longer bone).
2. Rotate, don't lerp: each bone's direction slerps along its arc between key poses.
3. Four key poses, plausible joints: held (the clip's own arm) -> **cocked** (up, out and back, elbow ~75 deg, the
   anticipation, eased in and out) -> **contact** (forward on the snout line, elbow opening, at the sim's hit) ->
   **follow-through** (past the midline, no further across than the held pose) -> back to held (eased). No snap
   back out wide.
4. Successive joints: the upper arm leads, the forearm and hand trail by a short lag.
5. Size-scaled timing: every phase times sqrt(body scale / the baby's); the baby's strike is 0.18 s (about 5 frames
   at 30 fps, the 3-6 frame range), the Colossus's 0.29 s. The sim's windup cue (`powers.swipe_windup`, a
   presentation cue only) moves to 0.7 s so even the Colossus has a full anticipation before the hit; the hit time
   and damage are unchanged.
A Cascadeur clip was weighed (D-216) and not chosen now: the swipe is laid over every stage's walk, idle and turn
clips, so a clip per stage still needs this same layer; when the new croc's Cascadeur set gains a swipe, it
replaces the poses here.

## 4. Pass bars (per stage; `tools/claw_probe.gd`, kept as data in `data/motion_gate.json` "claw_arm")
- Bone length within 1% of rest every frame.
- Elbow 15-130 deg (never locked straight, never folded flat); wrist at most 60 deg.
- Upper arm never further across the chest than its held pose.
- Peak angular speed of any arm bone at most 1500 deg/s on the baby, falling as 1/sqrt(size) (Behemoth ~1120,
  Colossus ~930): no one-frame jumps.
- The claw crosses the snout line within 1 frame of the sim's hit.
- The arm is home before the next swipe's windup cue (2.0 s after this one).
Then ONE ~6 s side-on clip, baby then Colossus, game speed, local GPU, off-screen; the lead runs the critic.
