# Set-pieces: the run intro and the evolution reveal (research notes, 2026-10-21)

Scope: shot grammar for a monster reveal, beat sheets for a <=3 s run intro and a longer evolution reveal, skips and
repetition, when control returns, letterbox, sound sync, and how to build both in Godot 4.7.2 without breaking the
deterministic sim. Read first (read-only): `scenes/evolution_reveal.gd` (full), `sim/emergence.gd` (full, PR #113),
`scenes/river_view.gd`, `scenes/rampage.gd` (setup, `_physics_process`, `_place_camera`), `sim/rampage_sim.gd` `step`,
`data/tuning.json` "emerge" and "camera", `scenes/main.gd` `_reveal`, `scenes/reveal_stage.gd`, ROADMAP Phase D,
`docs/roadmap/2026-10-20-director-comments.md` #11, DECISIONS D-105, research 02 (finding 6, rec 4) and 08 (bus plan).
"Estimate" or "inference" marks my own reasoning where no source states it.

## Key findings

1. **The rise is already a sim phase, and it is longer than 3 s.** `Emergence` holds the rest of the sim back:
   `RampageSim.step` returns early while `emerge.step` is true, so `time_left`, stomps and the army do not start until
   `kaiju_emerged` (`sim/rampage_sim.gd` lines 199-201). Tuning: `rise_seconds` 2.5, then a wade to the bank at
   `speed x wade_speed 2.0` (7.6-14 m/s by species), capped by `max_seconds` 8.0 (`data/tuning.json` line 251).
   *Estimate:* rise plus wade is about 3.5-5.5 s, against the director's "no longer than 3 seconds" (comments #11,
   `docs/roadmap/2026-10-20-director-comments.md` line 19). The intro's length is set by the sim, so it has to be fixed
   there (in data), not only in the camera. Source: code read in this repo.
2. **Hold the creature back, but in a game that replays, the tease must be tiny.** Gareth Edwards timed *Jaws* with a
   stopwatch: the shark is on screen about 4 minutes, and his *Godzilla* (2014) less than 8. He also says audiences
   "got angry" that Godzilla took too long to appear (Crank-in! interview, via
   [ResetEra](https://www.resetera.com/threads/gareth-edwards-compares-his-godzilla-2014-monster-screen-time-with-jaws-in-interview-about-jurassic-world-rebirth.1266831/);
   original [crank-in.net](https://www.crank-in.net/interview/171669/1)). Research 02 finding 6 adds the camera side:
   a low, human-eye-level camera and holding back sell scale
   ([Now Toronto](https://nowtoronto.com/movies/gareth-edwards/);
   [Birth.Movies.Death](https://birthmoviesdeath.com/2014/05/11/godzilla-2014-movie-review-using-cgi-to-make-man-in-suit.html)).
   *Inference:* in a 3 s shot played 100+ times, the "hold back" is the ripple and the fount (under 1 s). The kaiju
   is fully visible by about 1.3 s. A longer tease is what angered Edwards's audience, and it would anger them sooner
   on repeat.
3. **Boss intros play once; repeats get nothing or a skip.** In *Monster Hunter Rise* the intro cutscene plays "upon
   entering a quest in which the target is a large monster that the player has not yet encountered" and ends on a
   title card for one of the monster's traits ([Monster Hunter Wiki](https://monsterhunter.fandom.com/wiki/MHRise:_Monster_Intros)).
   Players argue loudly about unskippable cutscenes and ask for pause and skip
   ([ResetEra thread](https://www.resetera.com/threads/every-game-should-have-a-speed-up-function-and-be-able-to-skip-all-cutscenes.1121940/page-3)).
   The Game Accessibility Guidelines ask for a skip mechanism or a pause wherever timing matters
   ([GAG: precise timing](https://gameaccessibilityguidelines.com/do-not-make-precise-timing-essential-to-gameplay-offer-alternatives-actions-that-can-be-carried-out-while-paused-or-a-skip-mechanism/)).
   I found no GAG page that names cutscene skipping itself (gap). *Inference:* scale the intro to novelty. Play it in
   full when there is something new to show (first run, new stage or body plan, new species). Otherwise play a short
   cut, and let any press skip.
4. **The evolution reveal is a light-hidden swap with the roar on the reveal frame, as in Pokémon, and ours already
   has that shape.** In Pokémon, pressing B stops a level-up evolution; an item or trade evolution cannot be stopped
   ([Bulbapedia: Evolution](https://bulbapedia.bulbagarden.net/wiki/Evolution)). Our `EvolutionReveal` plays the old
   body shaking (frames 0-54), then a 0.9-alpha white flash that hides the swap, grows the body over 24 frames, roars
   at the swap (`Sfx.roar`), titles it by the node bought (D-051) and gives a play-fact size line ("Towers up to N
   floors now fall to you"). A skip works from frame 8 (`scenes/evolution_reveal.gd`). It is paced by **frames**:
   `END_FRAME` 230 counts `_process` calls. *Estimate:* that is 3.8 s at 60 Hz but 1.9 s at 120 Hz and 1.6 s at
   144 Hz (vsync_mode 2 in `project.godot`), so its length depends on the display.
5. **Drive the intro camera from sim progress, not a wall-clock tween.** A Godot 4.7 Tween runs on idle or physics
   frames (`TWEEN_PROCESS_IDLE` by default, or `TWEEN_PROCESS_PHYSICS`). It has `set_trans`/`set_ease` (SINE, EXPO,
   BACK, SPRING and others), `custom_step()` to advance it by hand, and `kill()`. It is bound to its node and dies with
   it ([Godot Tween](https://docs.godotengine.org/en/stable/classes/class_tween.html)). Our camera is placed every
   `_process` from `_focus + _cam_offset`, with the offset eased toward `camera_rest` at rate 5/s
   (`scenes/rampage.gd` `_place_camera`). *Inference:* the simplest robust intro adds one override to that function.
   While `sim.emerge.active`, take the offset from a curve of the emergence's own progress (`emerge.risen()` plus the
   wade share), blending from a close, low water shot to `camera_rest`. It cannot run out of step with the body (a
   wall-clock tween would during the b2-30 "run start freezes 2-3 s" hitch). Captures replay it exactly. It ends on
   the gameplay camera with no switch and no pop, which matches D-105 ("the run intro (Phase D) ends on this angle").
6. **A camera addon is not needed for one shot.** Phantom Camera is MIT-licensed. It needs Godot 4.4+, is inspired by
   Cinemachine, and has 3D follow modes Glued, Simple, Group, Path, Framed and Third Person
   ([GitHub ramokz/phantom-camera](https://github.com/ramokz/phantom-camera);
   [Godot Asset Store](https://store.godotengine.org/asset/ramokz/phantom-camera/)). I could not read its tween/blend
   page (404, gap). Godot's own advice for smooth cameras: move the camera in `_process`, follow the interpolated
   target with `get_global_transform_interpolated()`, and turn physics interpolation off on the camera
   ([Godot advanced physics interpolation](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/advanced_physics_interpolation.html)).
   That is what `rampage.gd` already does in spirit. *Inference:* the addon would need a LICENSING_REGISTER entry and
   a second camera system to buy a blend we already have in about 10 lines.
7. **Control returns on the sim's handover event, and the first press must not be eaten.** Today
   `_physics_process` reads `Input.is_action_just_pressed` for signature, dash and ultimate every tick and passes them
   to `sim.step`, which drops them while the kaiju emerges. A tap made just before `kaiju_emerged` is lost. Held
   movement (`Input.get_vector`) carries over, because it is read again every tick. Players notice missed buffered
   inputs; Hollow Knight players ask whether it buffers at all
   ([Steam discussion](https://steamcommunity.com/app/367520/discussions/0/2261312148318397578/);
   [r/gamedesign on input buffering](https://www.reddit.com/r/gamedesign/comments/1fqv2ow/input_buffering/)). Both
   sources are weak (community posts); the principle is standard but I found no primary design source this session.
   *Inference:* keep a short presentation-side latch (about 0.2 s, in data) of just-pressed buttons during the last
   part of the wade, and feed it to the first live `sim.step`. Because it reaches the sim as ordinary input on a
   known tick, a replay stays identical.
8. **Ducking and the roar sync are cheap with the bus plan in research 08.** A compressor sidechained from a "Hero"
   bus (roar, stomp) ducks the bed with no code; Godot names ducking as the compressor sidechain's purpose
   ([Godot AudioEffectCompressor](https://docs.godotengine.org/en/stable/classes/class_audioeffectcompressor.html), via
   08 finding 2). Our sounds all route to an "SFX" bus (`scenes/sfx.gd`), and the repo root has no
   `default_bus_layout.tres` (checked with ls), so no duck exists yet. `RiverView` already has the sync point: a big
   splash when `emerge.risen() >= SURFACE_AT` (0.45), which is when the head breaks the surface. *Inference:* the roar
   should play there or a few frames after (head clear, mouth open), not at the handover.
9. **Letterbox: little evidence, and a cost in a 3 s shot.** Players say bars that "slowly slide in" ahead of a
   cutscene read as smooth, and that bars blur cinematic with gameplay when they are done well
   ([ResetEra on letterbox cutscenes](https://www.resetera.com/threads/do-you-like-the-aaa-trend-of-letterbox-cutscenes.380133/);
   [r/GTA6](https://www.reddit.com/r/GTA6/comments/1e09b9t/cinematic_black_bars_for_cutscenes/)). Both are opinion
   threads. *Estimate:* 2.39:1 on a 16:9 4K TV means two bars of about 277 px each (12.8% of 2160). Sliding them in
   and out eats about 0.3 s each way, a fifth of a 3 s intro. Keep them for the evolution reveal and the first-ever
   run, or start the run with the bars already on (the screen comes from a load) and slide them out during the
   pull-out.

## Beat sheet A: run intro (proposal, <=3.0 s full, about 1.5 s short)

Times are seconds from the first stable frame after load. The intro must start after the b2-30 freeze, or the freeze
eats it. The sim's Emergence data must be retuned so rise plus wade fits (for example `rise_seconds` 1.6 and a capped
wade, `max_seconds` 3.0; values to set from a probe, estimate).

| Time | Camera | Kaiju (sim state read) | Sound | Input |
|---|---|---|---|---|
| 0.0-0.5 | Close and low on the water at `river_spawn`, almost at water level, slight push-in (ease out SINE). Bars on (first run only). | Submerged, `risen()` 0-0.2. Water ripples: RiverView's first ring, plus spray. | City bed low, a sub rumble swell. Music silent. | Locked. Presses latch for skip. |
| 0.5-1.0 | Hold, slight tilt up. The fount (water column) fills the upper frame. | `risen()` 0.2-0.45: back, spines and crown break the surface (the tease). | Rumble peaks; water roar. | Locked. Any press: skip (see below). |
| 1.0-1.6 | Low-angle hero frame, kaiju fills about 70% of the height (Edwards/Tsuburaya low camera). | `risen()` 0.45-1: head clears; RiverView's big splash at 0.45. | **Roar** on the head-clear frame; Hero bus ducks the bed 6-10 dB (08). | Locked. |
| 1.6-2.7 | Pull-out and rise to `camera_rest` x zoom, eased (ease in-out CUBIC). Bars slide out; HUD fades in over the last 0.4 s. | Wading to the bank (sim). | Roar tail; gameplay music enters on a downbeat at about 2.4. | Last 0.2 s: just-pressed buttons latched for the first live tick. |
| 2.7-3.0 | At rest: the gameplay camera. | `kaiju_emerged`: clock starts. | Bed back to level. | **Live.** Held stick applies; latched press fires on tick 1. |

Short cut (every run with nothing new): start at the 1.0 s frame (the head breaking the surface, roar), then pull
out. About 1.5 s. Skip on any press (both cuts): jump the camera curve to the pull-out's last 0.3 s, and
fast-forward the sim's emergence (see the next section). The press that skipped is latched, not eaten.

Variation across 100+ runs (presentation only, its own seeded stream, for example `Seeds.make("intro", run_index)`):
the camera side (left or right of the channel), a small yaw offset, and one of 2-3 roar samples. Variety that is
already free: the time of day rotates every run (`Content.time_for_run`), and the body changes with every stage.

## Beat sheet B: evolution reveal (proposal, about 4.5 s, rarer so it can be longer)

Paced by fixed ticks (`_physics_process`, 60 Hz), not `_process` frames, so it lasts the same on a 60 Hz TV and a
144 Hz monitor. It keeps the existing structure; the additions are marked "new".

| Time | Camera | Kaiju | Sound | Input |
|---|---|---|---|---|
| 0.0-0.9 (today: frames 0-54) | New: start low and slow push-in (today the frame is fixed). Bars in over 0.3 s. | Old body beside the tower; shake builds (exists). New: crouch/hunch pose. | New: music and bed duck; low riser. | Skip from 0.13 s (exists: `SKIP_AFTER` 8). |
| 0.9-1.5 | Hold. | New: transformation hidden by light. A glowing silhouette pulses between the old and new outline, faster each pulse (the Pokémon beat). Keep the pulses at 3 per second or fewer (a photosensitivity estimate; check against WCAG three-flashes, gap). | Riser climbs. | Skip. |
| 1.5 | **Flash** (exists, 0.9 alpha) + swap. | New body appears (exists). | **Roar on this frame** (exists) + new: one stinger hit. | Skip. |
| 1.5-2.3 | New: pull back and tilt up, so the tower's top and the head share the frame (scale read). | Grows over 24 ticks (exists); roar pose. | Roar tail. | Skip. |
| 2.3-3.0 | Hold. | Idle. | — | Skip. |
| 3.0-4.5 | Hold. Title slams in ("BEHEMOTH", D-051), then the two size lines one after the other (exists, today all at once). Bars out at the end. | Idle. | Small UI tick per line. | Skip; any press after 3.0 also continues. |

It differs from the intro in three ways. It is rarer (a few times per 3-5 h), so it may run 4-5 s. It is
self-contained (its own world, over the upgrade tree), so no sim runs under it. And it ends on text the player reads
(the size lines are a play fact), so it auto-ends rather than handing over a camera. A strong option: also give the
**first run after an evolution** the full-length intro, so the new body plan rises from the water. That one
"novelty" rule serves both moments.

## Sim during set-pieces

**Recommendation: keep the rise in the sim exactly as #113 built it (the sim "holds"), and make every set-piece
read sim state. The intro only changes what the camera shows. A skip only changes how many fixed sim ticks run per
rendered frame.**

- **Intro.** The sim is ticked during the intro, but `Emergence.step` holds everything else back: no clock, no army,
  no stomps, input ignored (`sim/rampage_sim.gd` line 199). The emergence uses no RNG and advances by the fixed physics
  `dt`, so a replay from tick 0 includes it and matches tick for tick. The camera curve reads `emerge.risen()` and the
  kaiju's position, never the clock (a test that uses the clock is a bug). The handover is the sim's own
  `kaiju_emerged` event, which `rampage.gd` does not handle yet; it is the natural "control live" hook.
- **Skip is replay-safe.** The sim ignores input during the emergence, so the outcome does not depend on when or
  whether the player skipped. A skip can run the remaining emergence ticks in one or two frames: call
  `sim.step(fixed_dt, ...)` in a loop until `emerge.active` is false. Same ticks, same state, so a replay that never
  skipped matches. *Estimate:* at most about 180 cheap early-return steps, well under a frame. Do not "teleport"
  through `_land`. The `max_seconds` cap path already does that, and it leaves the kaiju at a slightly different place
  and tick than the natural rise. A second, skip-only path is a divergence risk.
- **The alternative, the sim not ticked until a presentation-only intro ends, is worse here.** It would remove the
  sim's Emergence (and #113's new city check that the body starts inside the water). The army's alert ramp, which keys
  off `kaiju_emerged`, would then be driven by presentation timing. Replays would begin "after the intro", so captures
  of the rise could no longer be pinned to sim ticks.
- **Evolution reveal.** Nothing to decide: the purchase is applied and saved before the reveal starts
  (`scenes/main.gd` `_reveal`). The reveal is pure presentation in its own `World3D`. Its only flaw against the
  determinism rule is the frame (not tick) pacing in finding 4: tests see the same frame count, but players see a
  length that depends on the display.
- **Latched input** (finding 7) enters the sim as ordinary input on a known tick, so it is recorded and replayed like
  any other press.

## Sources

- https://www.resetera.com/threads/gareth-edwards-compares-his-godzilla-2014-monster-screen-time-with-jaws-in-interview-about-jurassic-world-rebirth.1266831/
- https://www.crank-in.net/interview/171669/1 (original of the above; not fetched directly)
- https://nowtoronto.com/movies/gareth-edwards/ (via research 02)
- https://birthmoviesdeath.com/2014/05/11/godzilla-2014-movie-review-using-cgi-to-make-man-in-suit.html (via research 02)
- https://monsterhunter.fandom.com/wiki/MHRise:_Monster_Intros
- https://bulbapedia.bulbagarden.net/wiki/Evolution
- https://gameaccessibilityguidelines.com/do-not-make-precise-timing-essential-to-gameplay-offer-alternatives-actions-that-can-be-carried-out-while-paused-or-a-skip-mechanism/
- https://www.resetera.com/threads/every-game-should-have-a-speed-up-function-and-be-able-to-skip-all-cutscenes.1121940/page-3
- https://docs.godotengine.org/en/stable/classes/class_tween.html (shows Godot 4.7)
- https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/advanced_physics_interpolation.html
- https://docs.godotengine.org/en/stable/classes/class_audioeffectcompressor.html (via research 08)
- https://github.com/ramokz/phantom-camera
- https://store.godotengine.org/asset/ramokz/phantom-camera/
- https://steamcommunity.com/app/367520/discussions/0/2261312148318397578/
- https://www.reddit.com/r/gamedesign/comments/1fqv2ow/input_buffering/
- https://www.resetera.com/threads/do-you-like-the-aaa-trend-of-letterbox-cutscenes.380133/
- https://www.reddit.com/r/GTA6/comments/1e09b9t/cinematic_black_bars_for_cutscenes/
- Repo files (read-only): sim/emergence.gd, sim/rampage_sim.gd, scenes/rampage.gd, scenes/river_view.gd,
  scenes/evolution_reveal.gd, scenes/reveal_stage.gd, scenes/main.gd, data/tuning.json, docs/DECISIONS.md (D-105),
  docs/ROADMAP.md (Phase D), docs/roadmap/2026-10-20-director-comments.md (#11)

## For Kaiju Incremental (ranked, simplest viable first)

1. **Make the sim's emergence fit 3 s (data only).** Retune `emerge` (`rise_seconds` about 1.6, a short wade or a
   bank point closer to the spawn, `max_seconds` 3.0). Add a probe that measures rise-to-`kaiju_emerged` in ticks
   per species and stage, and a test that fails above 180 ticks. Cost: about 1-2 h; no new system. This is the fix
   without which no camera can meet #11 (finding 1).
2. **Intro camera as an override in `_place_camera`, driven by emergence progress.** A close/low water offset and FOV
   blend to `camera_rest` along an eased curve of `risen()` and the wade share, with the shot numbers in
   `data/tuning.json` "intro". The handover happens on `kaiju_emerged`. Cost: about half a day plus one clip through the
   motion critic. Then he judges the clip (taste). No new nodes, no addon, no Tween (findings 5, 6).
3. **Roar on the surface-break beat; latch the first press.** Move or add `Sfx.roar` at RiverView's
   `SURFACE_AT` splash. Latch just-pressed signature, dash and ultimate during the last 0.2 s and feed them to the
   first live tick. Cost: about 2 h plus a scripted-input test that a dash pressed 0.1 s before the handover fires on
   tick 1 (findings 7, 8).
4. **Skip and the novelty rule.** Full intro on the first run, the first run after an evolution or a new species;
   the short 1.5 s cut otherwise. Any press skips by fast-forwarding the sim ticks, never by teleporting. Store the
   "seen" state in the save's presentation section. Cost: about half a day plus a replay test (skip vs no skip, same
   digest at `kaiju_emerged`) (finding 3, Sim section).
5. **Evolution reveal on fixed ticks.** Count `_physics_process` ticks instead of `_process` frames. Cost: about
   30 min; the flow suite's frame constants stay valid at 60 Hz. Removes the length that depends on the display
   (finding 4).
6. **Evolution reveal polish:** low start and a pull-back that tilts up to the tower top, a pulsing light
   silhouette before the flash (3 pulses per second or fewer), a stinger, the size lines one after the other, and
   bars. Cost: about 1 day plus a clip for the motion and screen critics. The director's taste call.
7. **Hero-to-bed sidechain duck** from research 08's bus layout, with the roar on the Hero bus. Cost: about 1 h, no
   code (one `default_bus_layout.tres`). It helps both set-pieces and every stomp.
8. **Letterbox** CanvasLayer (two ColorRects, about 277 px each at 4K for 2.39:1), only on the evolution reveal and the
   first-ever intro. Cost: about 1 h. Lowest value per hour; skip it if the clip reads without it.
9. Not recommended: Phantom Camera (MIT, fine licence, but a second camera system for one shot), or an AnimationPlayer
   plus Path3D camera path (the spawn point moves with city and stage, so the path would need to be in kaiju-local
   space; more authoring for no gain over the curve in item 2).

**Evidence gaps:** no primary designer source found for Hades, Dead Cells, Slay the Spire fast mode, Rocket League
kickoff, Hollow Knight or Metal Gear boss intros, Shadow of the Colossus reveal camera, Spore stage transitions or
Pacific Rim/Cloverfield reveal craft (searches gave tutorials and forums only). There is no GAG page that names
cutscene skipping, no source for letterbox timing, and Phantom Camera's blend docs gave a 404. The photosensitivity
limit (3 flashes per second) is from my knowledge of WCAG and was not fetched. The wade time, the 1.5 s short cut, the
0.2 s latch and the 4.5 s reveal are my estimates for a probe and the director's clip review.
