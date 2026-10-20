# Camera for a giant player: angle, distance, look-ahead, occlusion and shake (research notes, 2026-10-21, b2-7)

Context read first (read-only): `scenes/rampage.gd` (`_place_camera`, shake, footfall dip), `scenes/breath_camera.gd`,
`scenes/building_fade.gd`, `scenes/vehicle_fade.gd`, `scenes/building_baked.gdshader` and `scenes/voxel.gdshader`
(Bayer screen-door `discard`), `data/tuning.json` "camera" `{"offset": [0, 16, 30], "fov": 60.0}`, `sim/growth.gd`
(`body_scale = young_scale 0.5 x (1 + 0.8 x (size-1)) x (1 + 0.02 x growth)`), `docs/DECISIONS.md` D-105, and
`docs/roadmap/2026-10-20-build2-playtest.md` row 7. **b2-7 is already decided for the rest angle:** the director
said "the camera doesnt let us see much of the city, reconsider its angle and distance" (build2 #7) and picked
framing C, "low and cinematic", offset (0, 16, 30), FOV 60 (D-105). These notes therefore cover what D-105 did not:
the per-stage schedule, look-ahead, occlusion and shake.

How the camera works today: a fixed world bearing (it never turns with the kaiju), offset scaled by
`zoom = 0.75 + 0.4 x body_scale` (hard-coded in `_place_camera`, not in data), eased follow of the drawn body
(`FOCUS_FOLLOW` 12/s, offset lerp 5/s), aim 3.5 x body_scale above the feet. Shake is one scalar (0.08 to 0.6 per
event, decaying 3/s) applied as a new uniform random offset of the look-at point every frame (x 0.6 units), not
scaled by stage. Each footfall dips the camera (0.35 x max(1, scale) x strength x zoom). Breath swings the camera
25 degrees and lifts it 3 units. Buildings and vehicles in the sight line fade to a 0.35 screen door in 0.25 s.

## Key findings

1. **The craft rule for giants: a camera that rides too high or too far shrinks the monster.** A GamesRadar review of
   *Godzilla Unleashed* praised *Destroy All Monsters Melee*'s smarter camera for making the monsters look big, and
   faulted Unleashed's for sometimes "riding a blimp so high up that a skyscraper-sized monster looks like a small
   child" ([GamesRadar](https://gamesradar.com/godzilla-unleashed-review)). PC Gamer found GigaBash's zoomed-out
   top-down camera did not convey size ([PC Gamer](https://www.pcgamer.com/uk/gigabash-is-a-cute-and-chaotic-kaiju-brawler-that-makes-me-miss-arcades/), via 02-kaiju-lore finding 8).
   Destructoid credited Godzilla (PS4, 2015) with a camera "staged to give the kaiju a worthy sense of scale"
   ([Destructoid](https://www.destructoid.com/reviews/review-godzilla/)). This builds on 02-kaiju-lore finding 6
   (Tsuburaya's low camera, Edwards' human eye level: [National WWII Museum](https://www.nationalww2museum.org/war/articles/godzilla-and-world-war-ii-long-live-king-monsters),
   [Birth.Movies.Death](https://birthmoviesdeath.com/2014/05/11/godzilla-2014-movie-review-using-cgi-to-make-man-in-suit.html)).

2. **Too low fails the other way: depth and position become unreadable.** Nintendo World Report found *Rampage: Total
   Destruction*'s camera nearly parallel with the street, which made it hard to judge where the monster stood
   ([Nintendo World Report](https://www.nintendoworldreport.com/review/12499/rampage-total-destruction-wii)). Other
   reviews called its buildings 2D cutouts that could only be attacked from fixed sides
   ([Empire](https://www.empireonline.com/gaming/reviews/rampage-total-destruction-review/)). So there is a band: low
   enough that the kaiju towers, high enough that the ground plane (tanks, the next target) still reads.

3. **Katamari's designer used a stepped pull-back and later wished the camera had sold scale more.** The
   *Katamari Damacy* postmortem says the camera zooms out automatically once the ball grows so big it fills the
   screen. Under "what went wrong" it says the camera could have been used to add to the "gigantic" feeling, floats
   a view from the Prince's eye level, and admits the team was unsure of the best angle and wanted less 3D nausea
   ([Game Developer postmortem](https://gamedeveloper.com/design/postmortem-the-singular-design-of-namco-s-katamari-damacy-2004-)).
   Reviewers say the pull-back makes you remember how small you started
   ([GameSpot user review](https://www.gamespot.com/katamari-damacy/user-reviews/2200-12837820/), weak source). *For us:*
   the pull-back itself is a growth moment when the player sees it happen. Ours happens invisibly between runs.

4. **Our current schedule is already sub-linear, so the kaiju does grow on screen.** From the code and data (my
   arithmetic, labelled estimate): from size 1 to size 4 the body scale rises 3.4x (0.5 to 1.7) but the camera
   distance rises only 1.5x (zoom 0.95 to 1.43). The kaiju's share of screen height rises from about 12% to about
   30%, while the ground area in view grows about 2.3x. Pitch flattens a little (about 25 to 21.5 degrees), and the
   camera's height falls from about 3x the kaiju's height to about 1.35x. That is the low, cinematic direction of
   finding 1 and D-105. This avoids GigaBash's trap. The open question is the curve's steepness, not its shape.

5. **Look-ahead: lead in the direction of input, with a threshold and slow easing.** Itay Keren's survey of
   side-scroller cameras lists the patterns: static forward focus (Defender and Super Mario Bros. keep about 25% of
   the screen ahead), dual forward focus that switches only past a threshold (Super Mario World, to avoid flipping on
   small back-and-forth moves), target-focus that shifts the view toward the pushed direction and recentres on
   release (Jazz Jackrabbit 2), projected focus from velocity (works poorly when motion does not extrapolate), and
   lerp versus spring smoothing (Mushroom 11 varies smoothing with speed). He warns that a large, fast character with
   plain lerp can reach the screen edge before the camera catches up, hiding incoming enemies
   ([Game Developer, "Scroll Back"](https://www.gamedeveloper.com/design/scroll-back-the-theory-and-practice-of-cameras-in-side-scrollers)).
   Our kaiju is large, dashes and leaps, and is fought by things that come at it, which is the case he warns about.

6. **Occlusion: fade the occluder, not the camera, for a fixed-bearing camera in a dense city.** Mark
   Haigh-Hutchinson's *Real-Time Cameras* excerpt treats occlusion as navigation: rays from points around the camera
   to the target, swept volumes or render-based checks, then moving the camera with damped springs. It warns that
   hard constraints cause motion artefacts, opposing forces oscillate, and rays slip through thin gaps; it does not
   cover fading ([Game Developer excerpt](https://gamedeveloper.com/design/real-time-cameras---navigation-and-occlusion);
   [Routledge](https://www.routledge.com/Real-Time-Cameras-A-Guide-for-Game-Designers-and-Developers/Haigh-Hutchinson/p/book/9780429258190)).
   Unity's Cinemachine Collider offers the same three move-the-camera answers: pull forward, keep height, or keep
   distance, each with separate damping for occluded and clear states
   ([Unity docs](https://docs.unity3d.com/Packages/com.unity.cinemachine@2.9/manual/CinemachineCollider.html)).
   Moving the camera breaks D-105's chosen framing every time a tower passes, so the fade we already have
   (BuildingFade, D-025) is the right family. Godot's own distance fade has `PIXEL_DITHER` and `OBJECT_DITHER` modes
   that fade "without enabling transparency", and `ALPHA_HASH` stays opaque-pipeline and casts shadows
   ([Godot BaseMaterial3D](https://docs.godotengine.org/en/stable/classes/class_basematerial3d.html)). Our
   Bayer-matrix `discard` screen door is the same technique by hand: it needs no sorting and works in Forward+ and
   gl_compatibility alike.

7. **Shake: trauma, squared, on smooth noise, decaying over about 1-2 s (Eiserloh, GDC 2016).** Squirrel Eiserloh's
   talk "Math for Game Programmers: Juicing Your Cameras With Math" covers screen shake and other camera maths
   ([Game Developer](https://www.gamedeveloper.com/programming/video-sprucing-up-cameras-with-math)). Bevy's official
   example, which says it follows the talk, uses trauma 0 to 1, shake = trauma squared, trauma decaying 0.5/s, 1D
   Perlin noise at 20 Hz for each channel, at most 10 degrees of rotation and 20 px of translation, applied to the
   render transform only and restored each frame ([Bevy example](https://bevy.org/examples/camera/2d-screen-shake/)).
   Our shake differs on all three counts: it is linear rather than squared, it is white noise redrawn each frame
   (so it is harsher and changes with frame rate), and big and small hits stack by `max` without accumulating.

8. **Motion sickness: make every additive camera motion optional and adjustable; no repetitive bob.** Xbox
   Accessibility Guideline 117 says to avoid camera shake, bobbing and motion blur or provide an option to turn them
   off. It says to avoid repetitive up-down movement that is not core to play, to provide adjustable FOV, and to let
   players disable automatic camera movement. Its examples: Halo Infinite's 0-100% sliders for shake and screen
   effects, Cyberpunk 2077's "additive camera motions" setting, and Assassin's Creed Valhalla's camera-distance
   option ([XAG 117](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/117)). John
   Nesky's GDC 2014 "50 Game Camera Mistakes" (he was Journey's camera designer) names simulation sickness and broken
   line of sight among the failure modes ([GDC Vault](https://gdcvault.com/play/1021262/50-Camera);
   [Game Developer](https://gamedeveloper.com/design/video-50-common-game-camera-mistakes----and-how-to-fix-them)).
   Fan lists of the talk include excessive shake and a camera that bounces with the walk cycle (a third-party list,
   not verified against the recording). Our footfall dip is a walk-cycle bounce, and the breath orbit is an automatic
   angle change: both are in XAG 117's scope.

9. **Carving makes occlusion shrink as the run goes on, and the baby stage is the worst case.** From the data (my
   reading): stage-1 towers reach `max_height` 26 against a baby about 5 units tall and a camera about 15 units up,
   so early on whole towers stand between camera and kaiju. By size 4 the kaiju is about 17 tall and the camera
   about 23 up, and the towers it has carved are lower. BuildingFade tests the box `b.height`; if a carved
   building's box keeps its original height, a stump would still fade as if whole (not verified in the code).

## Per-stage camera table (ESTIMATES, compared with today)

Today's values come from the code (zoom = 0.75 + 0.4 x scale, offset (0, 16, 30), FOV 60 vertical, assuming Godot's
default `KEEP_HEIGHT`, about 92 degrees horizontal at 16:9). Kaiju height = `kaiju_height` 10 x scale, at growth
level 0. Screen share is a pinhole estimate (height x cos(pitch) / (2 x distance x tan 30 degrees)); real models
differ. "Proposed" is my estimate, not sourced.

| Stage (size, scale) | Today pitch / dist / FOV / share | Proposed pitch | Proposed distance (zoom) | Proposed FOV | Proposed look-ahead |
|---|---|---|---|---|---|
| 1 baby (1, 0.50) | 25.3 deg / 31.5 / 60 / ~12% | 25 deg (keep) | 0.95 (keep) | 60 | 3 units, 0.12 of visible ground width |
| 2 (2, 0.90) | 23.7 deg / 36.4 / 60 / ~20% | 23 deg | 1.08 | 60 | 4.5 units |
| 3 (3, 1.30) | 22.5 deg / 41.2 / 60 / ~25% | 21 deg | 1.20 | 62 | 6 units |
| 4 adult (4, 1.70) | 21.5 deg / 46.1 / 60 / ~30% | 19-20 deg | 1.31 (about 42 units) | 64 | 7.5 units |

Proposed reading: a slightly steeper growth on screen (adult about 33-35%), the pitch dropping a little more (it gets
"lower" as it grows, the Tsuburaya read), and a few degrees of FOV at the top end so the wider city and air threats
stay in frame. Keep the kaiju at or under about a third of screen height at any stage, so threats around it stay
visible. The 10-25% and one-third targets are my judgement, not a sourced standard (no source found).

## Sources

- https://gamesradar.com/godzilla-unleashed-review
- https://www.pcgamer.com/uk/gigabash-is-a-cute-and-chaotic-kaiju-brawler-that-makes-me-miss-arcades/
- https://www.destructoid.com/reviews/review-godzilla/
- https://www.nationalww2museum.org/war/articles/godzilla-and-world-war-ii-long-live-king-monsters
- https://birthmoviesdeath.com/2014/05/11/godzilla-2014-movie-review-using-cgi-to-make-man-in-suit.html
- https://www.nintendoworldreport.com/review/12499/rampage-total-destruction-wii
- https://www.empireonline.com/gaming/reviews/rampage-total-destruction-review/
- https://gamedeveloper.com/design/postmortem-the-singular-design-of-namco-s-katamari-damacy-2004-
- https://www.gamespot.com/katamari-damacy/user-reviews/2200-12837820/ (user review, weak)
- https://www.gamedeveloper.com/design/scroll-back-the-theory-and-practice-of-cameras-in-side-scrollers
- https://gamedeveloper.com/design/real-time-cameras---navigation-and-occlusion
- https://www.routledge.com/Real-Time-Cameras-A-Guide-for-Game-Designers-and-Developers/Haigh-Hutchinson/p/book/9780429258190
- https://docs.unity3d.com/Packages/com.unity.cinemachine@2.9/manual/CinemachineCollider.html
- https://docs.godotengine.org/en/stable/classes/class_basematerial3d.html
- https://www.gamedeveloper.com/programming/video-sprucing-up-cameras-with-math
- https://bevy.org/examples/camera/2d-screen-shake/
- https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/117
- https://gdcvault.com/play/1021262/50-Camera
- https://gamedeveloper.com/design/video-50-common-game-camera-mistakes----and-how-to-fix-them
- https://gamingpastime.com/war-of-the-monsters-review/ (retrospective: the camera "can sometimes work against you"; no detail)

## For Kaiju Incremental

Ranked, simplest viable first. All are presentation only, so sim determinism is untouched. Shake noise should keep
using the seeded `_fx_rng` (or a `FastNoiseLite` seeded from it) so captures repeat.

1. **Move the zoom curve into data and pin it with a test.** Replace the hard-coded `0.75 + 0.4 x body_scale` in
   `Rampage._place_camera` with `camera.zoom_base` and `camera.zoom_per_scale` in `data/tuning.json` (hard rule 4:
   no magic numbers). Add a small headless check that the kaiju's projected height share rises with every stage and
   stays at or under about 35%. Cost: about 2 hours. It turns the per-stage schedule into one data edit for any
   framing he picks.
2. **Rebuild shake as trauma-squared on smooth noise, rotational only, scaled by stage, under one slider.** Events
   add trauma instead of `max` (stomp 0.15, topple 0.6, ability 0.45, as now). Apply `trauma^2` to yaw and pitch
   from noise sampled by time (about 15-20 Hz), with no roll and no translation, so the D-105 framing never drifts.
   Cap it at about 2-3 degrees at full trauma (my estimate for a TV at couch distance; Bevy's 10 degrees is a 2D
   demo). Multiply the amplitude by about `sqrt(body_scale)` so an adult's topple feels heavier; the duration can grow
   too (02-kaiju-lore recommendation 1). Add one "Camera motion 0-100%" setting that scales shake, the footfall dip
   and the breath orbit together (XAG 117, Cyberpunk's single "additive camera motions" setting). Cost: about half a
   day plus a clip at stage 1 and stage 4, at game speed.
3. **Input-driven look-ahead with a threshold.** Offset `_focus` toward the move input by about 0.12 of the visible
   ground width (3 units at baby, 7.5 at adult). Ease it at about 1.5-2/s, slower than the 12/s body follow. Start
   only after input has been held about 0.3 s, and recentre on release (Jazz Jackrabbit target-focus, Super Mario
   World threshold). Use about 1.3x more lead when walking toward the camera (+z), where the street ahead lies in
   the cramped bottom of the frame. Do not lead during leaps or dashes; the eased follow already handles those. Cost:
   about half a day plus a clip.
4. **Keep the BuildingFade screen door; fix its edge cases before inventing a cutaway.** It is the cheapest answer
   that works in both renderers. Checks: (a) a carved building's box height should follow its carved top, so a stump
   never fades; (b) the fade should not pop when the camera eases. A second sight point at the kaiju's feet, so tanks
   at its feet show, is optional. Only if a fading tower still reads as a flicker at 4K, add a screen-space cutout:
   a radius around the kaiju's projected position, discarding only fragments nearer than the kaiju, in the same
   Bayer pattern. Cost: hours for the checks; about a day for the cutout.
5. **Make the pull-back visible once per run (the Katamari beat).** Zoom is fixed for a whole run, so growth between
   runs is never seen. Start the first 1-1.5 s of a run (the Phase D rise-from-the-water intro, comments 2026-10-20
   #11) at the previous run's zoom and ease out to this run's, so the player sees how much bigger it got. Cost: a
   few lines inside the Phase D intro work; no new system.
6. **An FOV slider (50-75) in settings** (XAG 117). Cost: about an hour, once a settings screen exists.
7. **Not recommended now:** moving the camera to dodge occluders (Cinemachine or Haigh-Hutchinson style) breaks the
   picked framing and adds oscillation risk. Rotating the camera with the kaiju's facing adds automatic angle
   changes (XAG 117) and motion-sickness risk. Keep the fixed bearing.

## Framings to capture for the director

Each is the D-105 rest angle at stage 1, so they differ only in how the camera grows. Capture the same seeded run at
size 1 and size 4, at game speed, in a 2x2 (two stages x the framing) per option, with debug overlays off and a 4K
check. All numbers are estimates.

- **A "Today, plus lead" (the control).** Pitch about 25 to 21.5 degrees from stage 1 to 4, zoom 0.75 + 0.4 x scale
  (distance 31.5 to 46), FOV 60, input lead 3 to 7.5 units. Kaiju about 12% to 30% of screen height. Trade-off: the
  most city and threats in view; growth reads, but modestly.
- **B "Grows on screen".** Zoom 0.85 + 0.25 x scale (distance about 32 to 41), pitch about 25 to 20.5 degrees, FOV 60
  to 64, same lead. Kaiju about 12% to 34% of the screen. Trade-off: each stage reads clearly bigger (the pillar),
  but an adult sees less of the city around it, and towers behind it are cut off sooner.
- **C "Low hero at adult".** Today's distance, but the offset's height share drops with stage, so the pitch falls
  from about 25 degrees (baby) to about 15 degrees (adult). The adult camera sits near its head height, and the
  skyline rises behind it (the Tsuburaya and Edwards read). FOV 60 to 64, lead as in A. Trade-off: the most "giant"
  look and skyline, with more tower occlusion and screen-door fades. The ground near its feet compresses
  (Rampage: Total Destruction's depth problem), so tanks are harder to read.

Evidence gaps: no primary source on Katamari's exact zoom steps, on Shadow of the Colossus's camera rules, on
GigaBash's, War of the Monsters' or Godzilla PS4's camera parameters, or on a published screen-share target for
player characters. Eiserloh's slides and Nesky's full list were not read first-hand: the trauma details come from
Bevy's implementation and the list from fan posts. Black & White, Spore, Monster Hunter, Teardown and the Roblox kaiju
games were not researched for lack of budget. Whether a carved building's `height` updates was not verified. All
per-stage numbers are my arithmetic or estimates.
