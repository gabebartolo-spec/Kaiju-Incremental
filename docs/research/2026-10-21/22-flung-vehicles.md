# Flung vehicles: deterministic, sim-owned throws and shoves that look physical (roadmap b2-9)

Researched 2026-10-21 for b2-9, "tanks shoved and flung into buildings, people and vehicles (uses C's physics)" (docs/ROADMAP.md, section D). Repo read only. This builds on 10-destruction.md (Jolt only decorates, tanks stay sim-kinematic, its rec. 6) and 13-body-collision.md (the sim's voxel grids are the real geometry, and contact carves rather than blocks).

**What the repo does today (read in full: sim/army.gd, sim/convoy.gd, sim/tentacles.gd; call sites in sim/species_powers.gd, sim/rampage_sim.gd, sim/collapse.gd, scenes/powers_view.gd, scenes/rampage.gd, scenes/street_life.gd):**
- **Throw** (`Tentacles._grab`/`_thrown`, cephalopod only). The grabbed tank or heli gets `hp = 0` and is cleared at grab time, so its rubble is paid at the grab. A `Thrown` record with `{kind, from, to, t, duration}` then runs a timer: `throw_seconds` 0.7, `to` = facing x `throw_range` 14 x body scale, clamped to the arena. On landing it fires one 2D `hit_area` falloff blast (`throw_blast` tank 3.5 / heli 3.0 / car 2.0; `throw_mult`). Nothing checks the flight path, so a thrown tank passes through towers. The "car" kind is made from nothing: cars are not sim entities.
- **Throw view** (`PowersView._thrown`). It spawns a fresh TankModel and tweens `position` from the tentacle tip to `to` in a straight line, with a fixed `rotation` tween to `(TAU, 0, PI)`. There is no arc, no gravity, no bounce and no skid. This is the main reason throws do not look physical today.
- **Shove** (`SpeciesPowers._ram`, reptilian momentum). `tank.pos += ahead * knockback * momentum`: a teleport in one tick, with no building or road check. Convoy re-plans from wherever the tank lands. *Possible bug (not verified):* a shove can leave a hull inside a building footprint or off the road graph.
- **Tanks are 2D** (`RampageSim.Tank`: `pos: Vector2`, hp, cooldown, coat). There is no height and no airborne state. `Convoy.step` drives every entry in `sim.tanks` and `Army.step` fires from every one.
- **People and cars are presentation only.** StreetLife says "the sim and the economy never know any of them exist". `_city.crush(pos, r)` already kills them under tank tracks and stomps.
- **Building geometry the sim can query.** Per-building `VoxelFrame`/`CellGrid` (`alive(c)`, `top_below`, `column_top`, `carve_sphere(centre, radius, force)`) at `destruction.res` = 8 cells per unit, and a coarse chunk Structure mirror. `hit_area(force, damage, y_lo, y_hi)` already routes a blow into `Carving.hit` (wear, materials, settle, topple).
- **Tick.** `sim.step(delta)` is called from `Rampage._physics_process`. project.godot sets no tick rate, so the default 60 Hz applies (dt = 1/60). The existing flights (`Thrown`, `Fall` in collapse.gd) are closed-form timers that end in a landing event, which sets the house idiom.

## Key findings

1. **Within one build, plain float maths in GDScript is deterministic enough. Fixed-point is not needed.** Gaffer on Games collects practitioner statements, for example "As long as you stick to a single compiler, and a single CPU instruction set, it is possible to make floating point fully deterministic" (Jon Watte). The breakage is across "CPU architectures, compilers, or optimization settings" (Shawn Hargreaves) ([Gaffer, Floating Point Determinism](https://gafferongames.com/post/floating_point_determinism/)). The repo's rule is replayable and seeded within one build, not cross-platform lockstep. One exported binary running fixed-order GDScript over Vector2/Vector3 (C++ maths in the same binary) meets it. The real risks are iteration order (Dictionary keys, `erase` while iterating) and a varying dt. Rounding is not one of them. *Inference.*

2. **Fix the dt and draw between ticks; never let render time reach the sim.** Fiedler: "a fixed delta time value for the simulation plus the ability to render at different framerates", with leftover time carried in an accumulator ([Fix Your Timestep!](https://gafferongames.com/post/fix_your_timestep/)). Godot's physics tick is fixed (default 60 TPS), and its interpolation guide recommends fixed-rate tick logic with interpolated rendering ([Godot docs: physics interpolation](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/physics_interpolation_introduction.html); [Godot docs: Engine](https://docs.godotengine.org/en/stable/classes/class_engine.html)). For ballistics there is a neat consequence. Under constant gravity with no drag, the exact per-tick update `p += v*dt + 0.5*g*dt²; v += g*dt` lands on the closed-form parabola `p0 + v0*t + 0.5*g*t²` (up to rounding). The sim can integrate per tick, which allows mid-flight hits, and emit `(p0, v0, tick0)` at launch and after every bounce. Presentation then evaluates the same parabola at any render time: smooth at 4K/144 Hz with no interpolation buffer, and exactly on the sim's path. *Inference from the maths.*

3. **Fast small bodies against a fine voxel grid need a swept test, not a point sample.** Rocket League ticks physics at a fixed 120 Hz because smaller steps reduce penetration variance and give more consistent impact normals and trajectories ([GDC 2018 "It IS Rocket Science", summary](https://glasp.co/youtube/ueEmiDM94IE); [UC Irvine thesis citing the 120 Hz tick](https://escholarship.org/content/qt9z4511gj/qt9z4511gj.pdf?v=lg)). The summary is secondary; the GDC video itself was not watched. Here a tank flung at 15-25 m/s moves 0.25-0.4 units per 60 Hz tick, which is 2-3 fine cells at res 8. A facade one cell thick would tunnel under per-tick point sampling. The textbook fix is Amanatides and Woo's incremental grid walk (3D DDA), which visits every cell a segment crosses in order, with one compare and one add per step ([Amanatides & Woo 1987, PDF](http://www.cse.yorku.ca/~amana/research/grid.pdf); [overview with pseudocode](https://github.com/cgyurgyik/fast-voxel-traversal-algorithm/blob/master/overview/FastVoxelTraversalOverview.md)). Sweeping the unit's *leading point* (centre + dir x radius) through the grid each tick costs a few cells per unit and cannot tunnel. *Inference/estimate.*

4. **The reference brawlers make throws arcade-simple: object class sets the trajectory, and impact rules are flat.** In GigaBash, light objects such as vehicles are "thrown straight", heavy objects "always follow a lobbed trajectory", and thrown Titans are lobbed. Some props ricochet ("ricocheting UFOs") or explode on impact (tank trucks, "guard breaks"). A thrown Titan is hurt only when it hits "a vertical surface, arena object, hazard, or a Titan" ([Wikizilla: GigaBash mechanics](https://wikizilla.org/wiki/GigaBash/Mechanics); fan wiki, medium reliability). Godzilla: Destroy All Monsters Melee lets monsters pick up buildings, train cars and military units and throw them ([Gojipedia](https://godzilla.fandom.com/wiki/Godzilla:_Destroy_All_Monsters_Melee); [Toho Kingdom specifics](https://www.tohokingdom.com/vg/gdamm/specifics.htm)), and its remaster markets "toss military tanks across the map" ([IGN trailer post](https://www.facebook.com/ign/videos/godzilla-destroy-all-monsters-melee-remastered-roster-demo-reveal-trailer-gamesc/1621761849562750/)). Lesson: per-kind data (mass, arc, restitution, special on-hit) carries the variety. A general rigid-body solver does not.

5. **Hulk: Ultimate Destruction's key idea is that vehicles are weapons with modes, not just projectiles.** Its feature list includes throwing "cars and tanks", wearing "two halves of a car as steel gloves", "a flattened car as a shield", and "a lamppost as a club" ([Wikipedia: Hulk UD](https://en.wikipedia.org/wiki/The_Incredible_Hulk:_Ultimate_Destruction)). Reviewers praised "the visceral satisfaction of wielding the Hulk's powers in an open and destructible environment" (same page). No primary Radical/GDC design write-up was retrieved, only a documentary video with Eric Holmes ([YouTube](https://www.youtube.com/watch?v=cMLDbpzd4v0), not watched). For an incremental, each Hulk "mode" maps naturally to an upgrade node (see recommendations), not to more physics.

6. **Hit-stop sells impact; scale it with damage and cap it.** Sakurai: on a hit "both parties momentarily freeze"; "the more damage an attack inflicts, the longer the hitstop"; Smash caps "the maximum amount of time characters can be in freeze frames"; vibration amplitude starts large and decays over the freeze ([Sakurai, Famitsu column via Source Gaming](https://sourcegaming.info/2015/11/11/thoughts-on-hitstop-sakurais-famitsu-column-vol-490-1/)). A secondary game-feel guide puts typical hit-stop at 40-80 ms and says to scale screen shake to the event; it credits Vlambeer's "The Art of Screenshake" for hit-stop and camera kick ([egmatic game-feel guide](https://egmatic.com/blog/how-to-make-your-game-feel-good); [r/gamedev on the talk](https://www.reddit.com/r/gamedev/comments/1t0jlc/vlambeers_jan_willem_nijman_the_art_of_screenshake/)). With 50 airborne tanks, freezing on every impact would stall the game, which is the frequency cost Sakurai warns about. Freeze only on the biggest impact in a window.

7. **The industry split is: authoritative state stays simple, ragdolls are local cosmetics.** Networked games commonly run ragdolls only on the client and do not sync limbs. A Unity netcode write-up describes the ragdoll as "purely a local physics object running only on the client", and players report each client seeing different results ([Unity Discussions](https://discussions.unity.com/t/implementing-network-ragdolls-with-unity-netcode-for-entities-rukhanka-animation-system/1699527); [r/askscience](https://www.reddit.com/r/askscience/comments/3k5f56/in_video_games_ragdolls_and_other_physics_are/)). This matches 10-destruction finding 2: Godot's Jolt integration does not guarantee determinism ([godot-jolt README](https://github.com/godot-jolt/godot-jolt); [Jolt determinism docs](https://jrouwe.github.io/JoltPhysics/index.html)). Jolt may throw the turret, the tracks and the people. It never decides where the hull lands or what it hit.

8. **Cost: 50 airborne units are cheap in GDScript only with a broadphase. Without one, the building loop dominates.** *My estimate, unmeasured.* Integration is about 10 float ops per unit per tick, which is negligible. The trap is building lookup. `SpeciesPowers.column_top` and `Tentacles._chunks_within` loop over every building, so 50 units x N buildings x 60 Hz grows fast. A static 2D bucket grid of building indices, built once (buildings never move; carving only empties cells), cuts each unit to 1-2 candidates. Next comes a coarse chunk check (`b.frame.alive`), then fine-cell DDA only inside a live chunk. Estimate: 50 units x about 4 DDA cells x 2 lookups is about 400 cell reads per tick, well under 1 ms. Measure with the existing `_note_cost("sim.step")` benchmark.

## Sim vs decoration

| Aspect | Owner | Why |
|---|---|---|
| Launch velocity (direction, speed, loft), seeded spread | Sim (army stream or `Seeds.derive`) | Decides where it lands and what it hits |
| Position and velocity per tick, gravity, bounce count, rest point | Sim | Outcome; must replay |
| Ground height under the unit (street 0, rubble or roof top via `top_below`) | Sim | Decides landing tick and whether it lands on a roof |
| Swept hit against building cells; crater carve (`hit_area`/`Carving.hit`) | Sim | Changes the city, the pay and the topple |
| Hit against tanks and helis; chain launches; depth cap | Sim | Kills, credit, chain outcome |
| Damage, kill credit, rubble pay, "flung kill" stat | Sim | Economy |
| Collision shape (one sphere per kind) | Sim | Simple, cheap, deterministic |
| Spin axis and rate, tumble, final resting orientation | Presentation (seeded from event id) | Looks only; a sphere has no orientation outcome |
| Smooth arc between ticks (closed-form from the launch/bounce event) | Presentation | Exact match to the sim path at any fps |
| Squash and stretch on bounce, hang-time ease, motion trail, dust puffs | Presentation | Readability |
| Hit-stop (skip N `sim.step` calls, or freeze only the view) and camera kick | Presentation | Feel; the sim stays a function of its step inputs |
| People and parked or moving cars crushed along the skid path | Presentation (`_city.crush`) | They are not sim entities today |
| Turret, tracks, wheels and panels flying off; sparks | Jolt (capped pool like CarveDebris) | Decoration; never read back |
| Main hull's flight or landing | **Never Jolt** | Godot Jolt is not replayable (finding 7) |

## Pseudocode: the sim flung-unit update (fixed dt, GDScript-shaped)

```
class Flung:                       # lives in sim.flung, NOT sim.tanks (so Convoy/Army skip it)
    id; kind                       # "tank" | "heli" | "car"
    unit_id; hp; mass; radius      # radius / mass / restitution / friction from tuning.fling[kind]
    p: Vector3; v: Vector3         # sim units, y up
    bounces := 0; gen := 0         # gen = chain depth
    state := AIR                   # AIR | SLIDE | REST

func launch(kind, from2d, dir2d, speed, loft, gen):     # from a throw, a ram or a chain hit
    var spread := (rng.randf() * 2.0 - 1.0) * cfg.spread_rad
    var d := dir2d.rotated(spread)
    f.v = Vector3(d.x, 0, d.y) * speed * cos(loft) + UP * speed * sin(loft)
    events.append({type:"flung", id, kind, p0:f.p, v0:f.v, tick, gen})   # view draws the arc from this

func step_flung(dt):
    for f in flung (in id order):
        if f.state == AIR:
            var p1 := f.p + f.v*dt + 0.5*G*dt*dt          # exact for constant g -> matches the view's parabola
            f.v += G*dt
            var hit := sweep_cells(f.p, p1, f.radius)      # bucket -> chunk -> DDA of the leading point
            if hit.building >= 0:
                var impulse := f.mass * f.v.length()
                sim.hit_area(falloff_at(hit.point, crater_r(impulse)), impulse * cfg.carve_k,
                             floor(hit.point.y) - 1, floor(hit.point.y) + 2)  # carves via Carving.hit
                f.hp -= impulse * cfg.self_k
                if impulse > cfg.punch_through * sim.stat("fling_punch"):   # upgrade: wrecking ball
                    f.v *= cfg.punch_keep
                else:
                    f.v = reflect_horizontal(f.v, hit.normal) * restitution  # ricochet off the wall
                events.append({type:"flung_hit", id, at:hit.point, normal:hit.normal, impulse})
                p1 = hit.point - hit.normal * 0.01
            hit_units(f, f.p, p1)                          # tanks/helis: circle + height band; chain if gen < cap
            var ground := ground_height(p1.x, p1.z)        # 0 street, or top_below() of a roof/rubble cell
            if p1.y - f.radius <= ground:
                p1.y = ground + f.radius
                landing_blast(f)                           # hit_area falloff scaled by impulse (today's throw_blast)
                if f.bounces < cfg.max_bounces and -f.v.y > cfg.min_bounce_speed:
                    f.v.y = -f.v.y * restitution;  f.v.x *= 1 - mu;  f.v.z *= 1 - mu
                    f.bounces += 1
                    events.append({type:"flung_bounce", id, p0:p1, v0:f.v, tick})
                else:
                    f.v.y = 0;  f.state = SLIDE
            f.p = p1
        elif f.state == SLIDE:
            var h := Vector2(f.v.x, f.v.z)
            var dv := cfg.slide_decel * dt
            h = Vector2.ZERO if h.length() <= dv else h - h.normalized() * dv
            ... same sweep against buildings at ground level (a skid into a wall carves too) ...
            if h == Vector2.ZERO: f.state = REST
        if f.state == REST or f.hp <= 0:
            settle(f)   # hp <= 0: wreck + pay rubble + credit; else back into sim.tanks (re-route via Convoy)
            events.append({type:"flung_rest", id, at:f.p, alive: f.hp > 0})
```

## Sources

- Gaffer on Games, Floating Point Determinism: https://gafferongames.com/post/floating_point_determinism/
- Gaffer on Games, Fix Your Timestep!: https://gafferongames.com/post/fix_your_timestep/
- Godot docs, physics interpolation introduction: https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/physics_interpolation_introduction.html
- Godot docs, Engine (physics_ticks_per_second, max_physics_steps_per_frame): https://docs.godotengine.org/en/stable/classes/class_engine.html
- Rocket League GDC 2018 talk summary (secondary): https://glasp.co/youtube/ueEmiDM94IE
- UC Irvine thesis citing Rocket League's 120 Hz tick: https://escholarship.org/content/qt9z4511gj/qt9z4511gj.pdf?v=lg
- Amanatides & Woo, A Fast Voxel Traversal Algorithm (1987): http://www.cse.yorku.ca/~amana/research/grid.pdf
- Fast voxel traversal overview (pseudocode): https://github.com/cgyurgyik/fast-voxel-traversal-algorithm/blob/master/overview/FastVoxelTraversalOverview.md
- Wikizilla, GigaBash mechanics: https://wikizilla.org/wiki/GigaBash/Mechanics
- Gojipedia, Godzilla: Destroy All Monsters Melee: https://godzilla.fandom.com/wiki/Godzilla:_Destroy_All_Monsters_Melee
- Toho Kingdom, GDAMM specifics: https://www.tohokingdom.com/vg/gdamm/specifics.htm
- IGN, GDAMM Remastered trailer post: https://www.facebook.com/ign/videos/godzilla-destroy-all-monsters-melee-remastered-roster-demo-reveal-trailer-gamesc/1621761849562750/
- Wikipedia, The Incredible Hulk: Ultimate Destruction: https://en.wikipedia.org/wiki/The_Incredible_Hulk:_Ultimate_Destruction
- Eric Holmes on Hulk UD (video, not watched): https://www.youtube.com/watch?v=cMLDbpzd4v0
- Sakurai, "Thinking About Hitstop" (Source Gaming translation): https://sourcegaming.info/2015/11/11/thoughts-on-hitstop-sakurais-famitsu-column-vol-490-1/
- egmatic, game feel and juice (secondary): https://egmatic.com/blog/how-to-make-your-game-feel-good
- r/gamedev, Vlambeer "The Art of Screenshake": https://www.reddit.com/r/gamedev/comments/1t0jlc/vlambeers_jan_willem_nijman_the_art_of_screenshake/
- Unity Discussions, client-only network ragdolls: https://discussions.unity.com/t/implementing-network-ragdolls-with-unity-netcode-for-entities-rukhanka-animation-system/1699527
- r/askscience, ragdolls differ per client: https://www.reddit.com/r/askscience/comments/3k5f56/in_video_games_ragdolls_and_other_physics_are/
- godot-jolt README (no determinism guarantee): https://github.com/godot-jolt/godot-jolt
- Jolt docs, deterministic simulation: https://jrouwe.github.io/JoltPhysics/index.html

## For Kaiju Incremental

Ranked, simplest viable first. All numbers go in a new `fling` block in data/tuning.json: per-kind mass, radius, restitution, friction, loft, spread, max bounces, crater k, chain cap, airborne cap.

1. **Arc the existing throw in the view (presentation only).** Swap `PowersView._thrown`'s linear position tween for a parabola from the tip to `event.to` over the same flight time: `y = lerp + 4*h*t*(1-t)`, apex height set by distance. Add spin about `cross(UP, dir)` with a seeded wobble, one squash and a dust puff on landing, and a short skid. The sim is unchanged, so the sim tests stay green; prove it with a clip through the motion critic. *Cost: about 0.5 day, about 40 lines.* It makes today's throws read as physical at once, but tanks still pass through towers.
2. **Make the throw a sim ballistic (`Flung`, per the sketch), and land it with the existing tools.** Replace the `Thrown` timer with per-tick exact kinematics. Add a static building bucket grid plus the chunk-then-cell DDA sweep. On a building hit, call `sim.hit_area` with a falloff at the impact point on the floors around impact height, which carves through `Carving.hit` (wear, materials, topple: "into buildings" for free). The landing blast stays today's `throw_blast`/`throw_mult`. Emit `flung`/`flung_hit`/`flung_bounce`/`flung_rest`, and draw the arc from them (rec. 1's code, now driven by `p0, v0`). Move kill credit from the grab to the landing. *Cost: about 2-3 days.* It needs a pinned-seed suite: the same input gives a bit-identical rest point twice; a throw at a known tower gives `cells_carved > 0`; no unit rests inside a solid cell. It touches shared sim rules, so it needs a kaiju-sim-review.
3. **Turn the reptilian ram's teleport into a launch.** In `_ram`, call `flung.launch("tank", tank.pos, ahead, knockback * momentum, low_loft)` and take the tank out of `sim.tanks` while airborne (Convoy and Army skip it). On rest, a surviving tank re-enters `sim.tanks` and Convoy re-plans from its nearest road (`_start`/`road_under`). This removes the possible "shoved into a building or off the road" state. Shoved tanks skid into walls and carve them. *Cost: about 1 day on top of rec. 2.*
4. **Chain hits on units, capped.** In the sweep, test other tanks and helis: 2D circle (`TANK_RADIUS`) plus a height band, and heli altitude for helis. Damage scales with mass x speed, and above a threshold the struck unit is launched with `gen + 1`. Cap the depth (1 by default, upgradeable) and the airborne count (for example 24). Count `flung_kills` in the run stats. *Cost: about 1 day.* This is the "flung into vehicles" moment and the hook for upgrades. Candidate nodes, the director's to choose: "throw distance" (speed), "ricochet" (+1 bounce, wall restitution up), "wrecking ball" (punch through a facade), "domino" (chain depth +1), "scrap bounty" (rubble bonus for flung kills). Hulk-style "car gloves/shield" modes are a later, bigger idea.
5. **People and cars: presentation crush along the path, no sim entities.** On `flung_bounce`/`flung_rest` and every skid tick event, the view calls the existing `_city.crush(pos, r)` and tumbles the nearest few pedestrians on short seeded parabolas (no Jolt ragdolls). Parked cars on the path are thrown as cosmetic boxes. *Cost: about 0.5 day.* This fills "flung into people" without touching the economy. If the director wants civilian kills to pay, that is a design decision (a new sim entity), not part of b2-9.
6. **Jolt decoration on impact.** On `flung_hit` and on a lethal `flung_rest`, spawn 3-6 bare Jolt bodies for the turret, the track halves and a few panels, through the CarveDebris pattern (PhysicsServer3D bodies, MultiMesh, freeze to rubble, fade). Add sparks and dust. Never read them back. *Cost: about 1 day; needs a frame-time check under heavy carving (b2-3).*
7. **Hit-stop and camera kick for the biggest impact only.** Presentation skips calling `sim.step` for 2-5 ticks (about 33-83 ms), scaled by impulse and capped, at most once per about 0.5 s. Add a camera kick along the impact normal. The sim remains a pure function of its step inputs. Do not use `Engine.time_scale`, because it would change the dt the sim receives. *Cost: about 0.5 day.*

## Evidence gaps

- The Rocket League claims rest on a talk summary, not the GDC video.
- No primary Radical/Hulk UD design source was found, and no primary source for Rampage or War of the Monsters throws.
- Godot's exact `Engine.time_scale` effect on the `_physics_process` delta was not confirmed: the docs query failed on a rate limit. It is my understanding, so verify it before rec. 7.
- The GDScript cost figures (finding 8) are my estimates, unmeasured.
- The possible ram "shoved into a building" bug is inferred from code, not reproduced.
- The parabola/integrator equivalence and the leading-point sweep are my inferences.
