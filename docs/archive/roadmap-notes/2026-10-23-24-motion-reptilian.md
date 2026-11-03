# Roadmap sections moved out of ROADMAP.md (2026-10-29, stale-info refresh)

The 2026-10-23 Motion first section and the 2026-10-24 Reptilian models and skins section, unchanged. Open rows still count; grep here (b2-N, p1-N and R n.m references resolve in this file).

## Motion first (D-177, 2026-10-23)
- Gait fix: per-stage step length in the sim (lead's builder) + the Behemoth's foot lift in the bake (VFX lead).
  Cause measured: the Behemoth's knee pops twice a step (leg snaps straight in early swing, knee flips at heel strike;
  shin jerk p99 32 vs the Colossus's 4) from IK at full stretch, fed by one step length for every stage; a held pad
  curve turns 38 deg with no foot down (the swivel). Sim (lead): per-stage step length, held-curve turns stepped.
  View (VFX lead): soft IK, Behemoth foot lift 0.15 -> 0.07. Owner: both. Status: sim PR #173 (841f93e2, two sim
  reviews SHIP: hand-over lurch and dash slide fixed) merging on green; view claude/gait-fix c661d731 passes the whole
  motion gate locally (motion 30/0: walking shin jerk young 6.0 -> 2.7, Behemoth 6.8 -> 4.3; catch steps 2.2 -> 0.2/s;
  reach 0.93); clips and a fresh motion critic next, then its PR after #173.
- Motion gate: the gait probe becomes a CI suite (planted-foot speed, steps/s vs clip speed, turn pivot vs planted
  foot, foot lift) at all three growth steps; every body or movement change passes it. Owner: VFX lead's gait builder
  writes it, the lead reviews and merges. Status: not started.
- Motion pass on every growth step (walk, turn, stop, dash, stomp, standing still), measured bars + a fresh motion
  critic at game speed, then the living predator (D-165), ahead of the one-look work. Owner: VFX lead. Status: queued.
- Balance run on GitHub (D-179): a manual workflow runs tools/pacing.gd. Owner: lead's builder. Status: not started.
- "helicopters are hovering way too close to our kaiju ... twitchy ... like an orbiting fly, they should move logically,
  strategically, gracefully": stand-off gunships (D-183). Owner: lead's builder (sim/air_wing.gd), VFX lead for banking
  and rotor look. Status: core MERGED #210 (2026-10-25 14:47Z: ring, strafe passes, night lights). Phase 3 ("helicopters
  never block your view", D-189: a pass never runs between camera and kaiju, hull tint, rotor disc, lamps; commit 353434c7 on
  claude/heli-standoff-2, untested) is not on main. Owner: lead (sim), VFX lead (lamps, tint). Date: 2026-10-27. Next: the
  heli-phase3 builder starts now: the Tripo vehicle swap is MERGED (#325, 2026-10-28): sync, heliflight and smoke
  suites, 4K night capture, PR.
- "these songs are too staccato, too endlessly building with very little relief or payoff": theme takes now ask for a
  legato melody with tension and release (D-182). Owner: lead. Status: done; D-184 ships the Godzilla set: his
  remaster of G2 (song 798f3c13) on the menu over the city sound and as the source of the three city Covers.
- "the claw swipe animation for our kaiju looks really really odd, the way his arms dart out is reminiscent of a wind
  up toy or somebody doing the chicken dance, its laughable, not dangerous"; "his arms dart out upward diagonally very
  suddenly, defying his anatomy, it looks terrible". D-185: a heavy raking arc. Owner: VFX lead (diagnose, exact
  fix, motion bars at all three growth steps, motion critic, one clip after SHIP). Cause (code): the upper arm is
  scaled 1.25x (adult) to 1.6x (young) so the arm telescopes out; only the arm moves; 0.62 s at every size; the hand
  lifts high; linear poses. Fix: no bone scaling, torso twist to load and whip, low wide arc, a strike of 0.1 s or
  less on the sim's hit, follow-through longer with size. Bars: arm scale 1.0, chest yaw >= 15/25 deg, hand at or
  below the shoulder, arc >= 120 deg, strike peak >= 3x the load's speed, hit within 1 frame, feet slide 0. Status:
  next free VFX engine slot after the gait work. Risk: if the 0.3 s sim wind-up reads rushed at Colossus size, a
  per-stage wind-up is a design question for him.
- "the kaiju breathing animation is way too much, too much movement and too fast, should be deep and slow like a
  behemoth" (D-165 living predator). Fix: slower, deeper breaths with less visible movement, still slower and
  heavier as he grows; bars per growth step (breath period, back and flank movement), motion critic, one idle clip
  after SHIP. Owner: VFX lead. Status: in progress (D-165 phase A builder, claude/living-predator). Seen on base,
  where the breath is baked into the idle clip; it is damped at runtime. Bars: one breath every 4 / 6 / 8 s (young
  croc / Behemoth / Colossus), inhale 40%, exhale 60% with a pause; back and flanks move 0.25-0.8 / 0.6 / 0.5% of
  body height at most, no faster than 0.6% of body height a second; the belly barely moves. D-190 "Slow
  chest-and-neck heave": neck, shoulders and flanks rise clearly every 6-8 s, deep and slow, the default idle
  (replaces the movement caps above).

## Reptilian models and skins (D-209, director 2026-10-24)
- "i want to see all models soon: croc baby, croc teen, croc adult, dragon baby, dragon teen, dragon adult, serpent
  baby, serpent teen, serpent adult / and i want to see skin mockups for all of them". Concepts that pass their critic
  go straight to 3D; two Tripo sessions in parallel. Owners: tripo-komodo (Komodo baby, three croc stages),
  tripo-serpent (three serpent stages, D-206), lead (skins: Blender recolours, about six palettes per titan, same
  palette baby to adult, D-205; he picks three). Status: Komodo adult done, adolescent textured, baby texturing;
  croc adult concept in its third round; serpent baby concept SHIP. Tracked on the "Reptilian models" page.
- Also today (D-208): turning and steering must feel exceptional; carving keeps working with the new models; any
  contact damages a building except the serpent's held climb. Owner: lead (komodo-test builder adds carve and turn
  checks; serpent round 4). Status: in progress.
- Reptilian sounds (director 2026-10-24): "croc: low clicking crocodile growl, clapping hollow sound of jaws
  clunking together / dragon: cavernous nostril snorts, wet tongue flicks, short and brutal barking roars / serpent:
  hissing noise obviously, faint slithering sounds as it climbs, deep menacing rattle". Owner: lead. Status: croc
  takes made first ("Croc now, others later"); Komodo and serpent when their models are in the game.
- Reptilian idle states (D-210, director 2026-10-24): "snake curls up into a defensive position, tongue flicking
  dangerously / croc hunches guardedly, prepared to leap at anything nearby / the dragon breathes heavily and steadily,
  tongue darting, drool dripping, snorting steamy gusts from its nostrils". Owners: serpent slither builder (coil on
  stop), lead (Komodo idle in Cascadeur, steam and drool effects), croc with its new model. Status: not started.
- Final boss, the mecha chimera (D-211, director 2026-10-24): "a strange chimera hybrid of all three, in a mecha form
  as the final boss ... snake head, croc body and athleticism, dragon massive size and power and it shoots a tribeam of
  corrosive acid, lightning and poison out of its mouth". A full machine built from your DNA; last city after 100% of
  every reptilian's upgrades. Owner: tripo-komodo (free concepts now), lead. Status: concepts started.
  Stretch goal: "after you unlock 100% of the achievements you unlock a secret: you can play as the mecha kaiju"
  (no achievement list exists yet; designed with him later).
- Scope (D-212, director 2026-10-24): "demo: full croc gameplay minus the mecha boss fight / full game: all 3
  reptilians and mecha boss / ... an expansion with a mammal, an avian, an aquatic" (plus build-your-own kaiju);
  mantis and octopus stay stretch goals. Owner: lead (milestones follow this). Status: recorded.
- Komodo in the game (D-251 "walk is good. ship it", lands OFF by default while dragon work is paused, D-252): claude/komodo-land (tip 06c88b38, 38 commits, 80 files; includes claude/komodo-clips), not on main. Owner: lead (+ casc-anim). Date: parked 2026-10-27 (D-310). Next: the lead rules on the motion, gait and clip reds in the komodo-land handoff, then PR. Komodo mouth tooling (D-245): claude/komodo-mouth-49564a, Blender tooling only, no game asset, same parking; next: a watertight mouth shell, bake and import, or land only the croc mouth script.
