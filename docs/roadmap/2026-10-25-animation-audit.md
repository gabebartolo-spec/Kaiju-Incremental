# Animation audit, 2026-10-25

The director (2026-10-25): "for the millionth time. I want 100% of our animation done with Casc, everything else is
dogshit, dont make me ask you again / audit all our existing animations and mark any procedural animations for
replacement". The rule is in the rulebook (Kaiju: 100% keyed in Cascadeur; tail, jaw and tongue may be keyed in
Blender per D-228). Procedural animation is a defect to replace, never an option to offer.

Audited on origin/main 083964eb. The lead checked the headline claims against main: the only clip files are
`assets/kaiju/reptilian_{baby,adolescent,adult}.kclip`, which were keyed by a script in Blender (D-047). No file under
scenes/, sim/, autoload/ or assets/ mentions Cascadeur. The stomp is code (`scenes/clip_stomp.gd:56`).

**Headline: no Cascadeur clip is in the game yet.** Every move the player sees is either a Blender clip or code.

## Kaiju (what the player sees: the croc, three stages)

| Move | Now | Where | Mark |
|---|---|---|---|
| Idle | Blender clip | kclip "idle" | REPLACE with Cascadeur |
| Walk | Blender clip, with code foot IK, catch-steps and curve-bent footprints | `ClipGait._plant_feet`, `ClipStomp.restep`, `ClipSteps.curved` | REPLACE |
| Run / charge | none: the walk plays faster | `ClipSteps` clock | REPLACE (a Cascadeur run and charge exist for the Komodo, D-245) |
| Turn on the spot | Blender clip, with code yaw steering | `ClipGait._steer_turn` | REPLACE |
| Turn while walking | code | `ClipGait._stepped`, `ClipTail.step`, `KaijuGait.track` | REPLACE (keyed walk-turns, v4 method approved) |
| Head look into turns | code | `ClipGait._look_ahead` | REPLACE |
| **Standing stomp** (his complaint: "his foot moves in completely unnatural way") | code | `ClipStomp.stomp/rise/landing/dip` | **REPLACE, first** |
| Claw swipe / rake | code over the clip | `BipedSwing.strike/tick_rake/pose_rake`; open PR 194 adds more of it | REPLACE; PR 194 is held |
| Tail sweep / whip | Blender clip, with code whip | `BipedSwing.tick_whip` | REPLACE (tail may be keyed in Blender, D-228) |
| Tail lag on turns | code spring | `ClipTail.step/bend` | REPLACE |
| Roar | Blender clip | kclip "roar" | REPLACE (Komodo roar v20 is in work) |
| Breath-beam jaw | code blend to the roar's jaw | `ClipGait._jaw_peak` | REPLACE (jaw may be keyed in Blender) |
| Emerge from the river | code rise plus the walk | `sim/emergence.gd`, `Rampage._update_kaiju` | REPLACE |
| Evolve | code shake and scale, then the roar | `EvolutionReveal._physics_process` | REPLACE |
| Species-select turntable | idle clip, model spun | `SpeciesSelect` | the clip follows the idle; the spin is a camera move |
| Title screen colossus | baked pose images | `TitleColossus`, `bake_colossus.gd` | REPLACE (render from the Cascadeur walk) |
| Fallback gait (tools and tests only) | code | `BipedGait`, `BipedBody`, `BipedHead` | delete when the clips cover every move |
| Insectoid, cephalopod (not in the demo) | code | `HexapodGait`, `RadialGait` | REPLACE before either ships |
| Far skyline insectoid (unmerged branch) | code | `scenes/far_beast.gd` | REPLACE |
| Insectoid brood young | code | `Brood`, `PowersView.update` | REPLACE before the insectoid ships |

## People (everyone in the street)

| Who | Now | Where | Mark |
|---|---|---|---|
| Civilians: walk, run, startle | two baked poses swapped on a clock | `StreetLife._pose` | REPLACE |
| Police: walk, run, aim | the same pose swap | `Police.update_cop` | REPLACE |
| Rooftop defenders | static poses | `RooftopView` | REPLACE |
| Stadium players | the pose swap with a sine drift | `StadiumMatch` | REPLACE |
| Stadium crowd | shader bob | `crowd.gdshader` | REPLACE |
| Taskforce agents | boxes moved, no animation | `TaskforceView` | REPLACE (no model yet) |
| Heli crew on parachutes | sine sway | `HeliWreck` | REPLACE |

## Machines (cars, tanks, helicopters, trains)

Driving, turret aim, rotor spin, recoil and crashes are all code. The director has been asked whether mechanical motion
counts under the rule. Until he answers, they are marked QUESTION, not REPLACE.

## Cascadeur clips made but not in the game

All of these are in `C:/Users/DANTE/cascadeur_bridge/`, and none is on main:
- Komodo walk w28. He shipped it; it is only on the unmerged branch `claude/komodo-clips`.
- Komodo run r1 (D-245), charge v6-v12, idle v43 (D-225), turns and walk-turns, roar v1-v2 (v20 is in work).
- New croc adult3 rig (r4, r8c), with no clips yet. Komodo baby rig only.

## Replacement queue

Owner casc-anim. Each move is one side-on clip: plan, research, implement. The method is the approved walk-turn v4.

| # | Item | Next step | Status |
|---|---|---|---|
| 1 | Land the shipped Komodo clips in the game (w28 walk, v43 idle, walk-turns) | `claude/komodo-clips` to a PR (BUILT MEANS IN THE GAME) | open |
| 2 | Standing stomp, keyed in Cascadeur | reference research and pass bars, then one side-on clip | open |
| 3 | Claw swipe, keyed (replaces PR 194's code swipe) | the same steps | open |
| 4 | Run and charge (r1 and charge v12) | wire them to the sim's dash | open |
| 5 | Tail whip and sweep, emerge, evolve, beam jaw | one clip each | open |
| 6 | People: walk, run, flee, aim | one human rig in Cascadeur | open |
| 7 | Remove the code layers and the fallback gait | after 1 to 5 land | open |
