# Final boss: a mecha kaiju built to fight you (research for Kaiju Incremental)

Researched 2026-10-21. The brief comes from the director (2026-10-19): "a final boss, a mecha kaiju built to fight you". The roadmap
places it in phase H, "Content after the slice", after rooftop mortars (`docs/ROADMAP.md` line 25 and phase H). `docs/VISION.md`
still lists "what ends the game (a final boss, a world map, the last city)" as open, so a boss would also settle that question.
This note builds on 01 finding 9 and recommendation 5 (weak endings, readability caps), 16 (tree cadence, the evolution
landmark), 19 (camera: do not shrink the monster, fixed bearing), 15 (minimal HUD, b2-10/12/13) and 22 (deterministic ballistics,
`Flung`, hit-stop outside the sim). It does not repeat them.

Repo state, read only. `sim/army.gd` in full. `sim/rampage_sim.gd`: `_init`, `step`, `end`, `hit_area`, `result`. The headers of
`sim/collapse.gd` and `sim/air_wing.gd`. `tools/pacing.gd` header. `data/tuning.json` base stats. What matters here:
- Every sub-system follows the same pattern: a `RefCounted` owned by `RampageSim` that takes `Seeds.derive(rng, 0x....)`, a
  `step(dt)` and a `cfg` dictionary from `tuning.json`. Results go out through `sim.events.append({"type": ...})`.
- The run ends through `end(reason)` with "city_fallen", "defeated", "time" or "ended".
- `hit_area(force: Callable, damage, y_lo, y_hi)` is the general area hit. It already reaches chunks, tanks, squads and helis.
- `Collapse` already topples a tower whose base was eaten toward the kaiju's side (`collapse.gd` lines 57-64, `_toward(centre -
  sim.kaiju_pos)`). A falling tower smashes the street, buildings and tanks, but nothing in `collapse.gd` touches `sim.hp`, so a
  topple cannot hurt the kaiju today.
- Base speeds are reptilian 5.5, insectoid 7.0 and cephalopod 3.8 units/s (`species.json`). Stomp radius is 2.5 x body scale.
  The pacing bot runs at DT 1/15 with a scripted player.

## Key findings

1. **The reference incrementals end weakly because they end without a fight. The one that has a real final boss is
   remembered for it.** In Nodebuster, deploying the godvirus ends the game straight away. One player wrote "i'm expecting a
   final boss battle against the godvirus" and found the game "directly proceeded to the ending" ([Steam thread](https://steamcommunity.com/app/3107330/discussions/0/594028416743941551/)).
   Late-game players say you "win by just staying in the center" ([r/incremental_games](https://www.reddit.com/r/incremental_games/comments/1g98y7n/nodebuster_is_a_really_fun_and_addicting/)).
   Chef Knight ends after floor 4 at a "final chest", and a player's main request is "a fifth floor with an added boss room at
   the end" ([Steam hub](https://steamcommunity.com/app/4304930)). Astro Prospector does have a multi-phase final boss. A meter
   fills mid-fight, then "the heart appears, so defeating it leads to the final phase" ([ebisen review](https://note.com/ebisen/n/n96a4a3d52f2c?hl=en)).
   Players report it "took me a few tries, but once i figured out the patterns ... it wasn't too difficult" ([Reddit launch thread](https://www.reddit.com/r/incremental_games/comments/1lzrmgb/astro_prospector_is_out_now_on_steam_and_were/)).
   Two warnings come from the same game. Strong builds end up "melting it before it can even finish it's entire loop of attacks",
   and one player calls the fight "stupidly RNG based" ([Steam thread](https://steamcommunity.com/app/3503440/discussions/0/596284732212325460/)).
   The stage before it drew complaints of "absurd" difficulty ([ebisen](https://note.com/ebisen/n/n96a4a3d52f2c?hl=en)).
   Godzilla PS4 ends with "To Be Continued..." and returns to the title screen ([Toho Kingdom review](https://www.tohokingdom.com/vg/godzilla_ps3_ps4/review_steve_johnson.html)).
   *Lesson:* an authored final fight is the cheapest way to avoid 01's weak-ending trap. It needs a guard so that a strong
   build cannot skip its phases, and its patterns should be learnable, not random.

2. **Run-based games put the boss at the run's end, as its win condition, with thresholds of health OR time.** Brotato's
   bosses appear only on wave 20. The run is won when they die or when the wave's clock runs out. The Invoker changes form
   "at 60% HP or after 30s" and again "at 40% HP or after 60s". Its first attack primes for about 1 s before it fires
   ([Brotato wiki, Invoker](https://brotato.wiki.spellsandguns.com/Invoker)). Vampire Survivors turns the clock itself into the
   ending. At 30:00 the Reaper "will quickly rush to the player's character and deal 65,535 damage", and one more spawns each
   minute after that ([VS wiki](https://vampire.survivors.wiki/w/The_Reaper)). Halls of Torment's Lich arrives only in the last
   8 minutes of a run, and optional altars weaken him beforehand ([PC Invasion guide](https://www.pcinvasion.com/?p=373695)).
   In Rampage: Total Destruction the vehicle boss is optional (you clear a stage by flattening its buildings), and reviewers
   found it "more annoying than difficult" because it takes "a long time" ([NWR review](https://nintendoworldreport.com/review/11593/rampage-total-destruction-gamecube)).
   *Lesson:* make "health or time" the phase trigger. Health lets a strong player push through, and time makes sure every phase
   is seen and the fight never drags. Keep the boss the point of the run, not a long optional sponge.

3. **Shape the fight like a story: build-up, a teaching phase, escalation, a midpoint transformation, an arena collapse, then
   an easier last stretch and time to enjoy the win.** Mike Stout splits a boss fight into beats. New mechanics are taught "with
   enough time, space, and safety". The midpoint is "a false victory, false defeat, or transformation". The arena collapses
   around the player (Ganon's castle). The boss gets defences (a force field, flight, a knockback) so it is never stuck unable
   to attack ([Game Developer, Stout](https://www.gamedeveloper.com/design/boss-battle-design-and-structure)). Itay Keren's GDC
   2018 talk, from a Chinese translation, sets out four rules. The boss should look unbeatable (David and Goliath). Each phase
   tests a different skill and never exists only to lengthen the fight. Tension peaks mid-fight and then falls toward a
   predictable win. The player should get a moment to enjoy the victory, with no new challenge straight after it
   ([gcores translation](https://www.gcores.com/articles/103804); [GDC Vault abstract](https://www.gdcvault.com/play/1024921/Boss-Up-Boss-Battle-Design)).
   Monster Hunter's sieges change arena with each phase. In Kulve Taroth's final phase the gold shell has fallen away and she is
   "smaller, but also significantly faster" ([MH wiki](https://monsterhunterwiki.org/wiki/Kulve_Taroth_(MHWorld))). Safi'jiiva
   drains each area and then moves on to the next ([Fextralife](https://monsterhunterworld.wiki.fextralife.com/Safi'jiiva+Siege)).
   *For us:* "you are the disaster" gets its one inversion here. For one fight the city has built something that dwarfs you.
   Beating it makes you the biggest thing in the game, so the pillar's last beat is earned.

4. **A telegraph is a fairness contract: a wind-up, the attack, then a recovery the player can punish. Each should be its own
   data step.** Stout writes that before an attack "we need a small delay"; then if the player is hit, "it becomes fair". The
   channels he lists are animation, sound, voice, VFX and force feedback ([Game Developer, Stout](https://www.gamedeveloper.com/design/enemy-attacks-and-telegraphing)).
   Double Fine built Psychonauts 2's bosses from modular "maneuvers". Each one runs telegraph, attack and recovery, chained in
   data that designers and animators tune "in a relatively simple interface", so that "we needed to be able to pivot very
   quickly" ([Game Developer, Vessal GDC 2023](https://www.gamedeveloper.com/marketing/using-a-modular-system-of-maneuvers-to-design-i-psychonauts-2-i-s-boss-fights-in-a-hurry)).
   Titanfall 2 gave the Legion's hitscan gun a warm-up so that "enemies who see it spin up can dodge to cover" ([Inven, Pineda](https://labs.invenglobal.com/articles/1230/redesigning-titan-combat-strategical-decisions-that-made-titanfall-great-again)).
   Keren: "predictability equals controllability" ([gcores](https://www.gcores.com/articles/103804)). The counter-example is
   Monster Hunter Rise: Sunbreak, where players attack "deceptive wind ups to throw off your timing" and "unreadable windups"
   ([r/monsterhunterrage, opinion](https://www.reddit.com/r/monsterhunterrage/comments/xb8oem/monster_telegraphs_are_kind_of_terrible_in/)).
   *Lesson:* no delayed or feinted swings. Each attack is one shape, one tell and one fixed timing.

5. **At kaiju scale the telegraph has to cover reaction time PLUS the time a slow giant needs to walk out of the zone, and the
   slow wind-up is what sells the size.** Simple visual reactions take about 250 ms and auditory ones about 170 ms. Display and
   input lag add more on top ([Coddy](https://coddy.tech/tools/es/reaction-time-test); [Duckware](https://duckware.com/tech/measure-human-visual-response-times.html)).
   Weta's animators on *Rampage* say big creatures "need some time to generate that speed, and ... to wash off that speed",
   with a slowly rippling follow-through that "gives you the cue that it's big" ([VFX Voice](https://www.vfxvoice.com/weta-digital-gives-weight-to-the-giant-monsters-of-rampage/)).
   MPC says a constant speed reads as robotic, and that debris slower than real life sells scale ([befores & afters](https://beforesandafters.com/2024/05/01/for-godzillas-walk-we-put-a-speedometer-on-his-feet-just-to-see-how-fast-they-go/)).
   *My estimate from our data:* telegraph = 0.35 s reaction + 1.25 x (escape distance / the slowest species' speed). The
   cephalopod moves at 3.8 u/s. To leave a 4-unit zone it needs 0.35 + 1.25 x 4/3.8 ≈ 1.7 s; the insectoid at 7.0 u/s needs
   about 1.1 s. This puts kaiju telegraphs at about **0.8-1.8 s**, against Brotato's 1 s. A machine can make the long tell feel
   right: servos spinning up, lights charging, the hull venting. There is a catch with the mecha. A robot "moving at a constant
   speed looks robotic" (MPC), which suits the theme, but the wind-up still needs ease-in for weight.

6. **The destructible city is the boss's best tool and the player's best weapon, and our sim already has half of it.**
   Stout's arena collapse and Keren's terrain changes and boss-reflected attacks (the Contra and Crash patterns) are the general
   forms ([Stout](https://www.gamedeveloper.com/design/boss-battle-design-and-structure); [gcores](https://www.gcores.com/articles/103804)).
   The kaiju-genre forms are throwing buildings and props at the other giant ([GigaBash reviews: "heave buildings at them, toss
   them into hazards"](https://virtualseasia.com/?p=12819)) and a jaeger using "a giant boat as a club" ([Showbiz Junkies](https://www.showbizjunkies.com/movies/pacific-rim-review/amp/); seen only as a search excerpt, and which review said it is unverified).
   Godzilla PS4 drew criticism for losing building throws, and its buildings "explode ... and crumble" with no interaction
   ([Toho Kingdom](https://www.tohokingdom.com/vg/godzilla_ps3_ps4/review_steve_johnson.html)). *For us (from the code):*
   `Collapse` already topples an undercut tower toward the kaiju. A mecha that cuts a tower's base therefore gets "the city falls
   on you" almost free. The only missing piece is a damage strip on `sim.hp`. A thrown tank or chunk landing on the mecha is
   22's `Flung` with one more target.

7. **Keep it one on one, and make it learnable rather than random. Chaos and luck are the two named failure modes.** In
   Titanfall 2, combat tuned 1v1 became "chaotic, hard to track" with several Titans at once ([Inven](https://labs.invenglobal.com/articles/1230/redesigning-titan-combat-strategical-decisions-that-made-titanfall-great-again)).
   Godzilla PS4's random appearance of a 100 m monster against a 50-70 m player "will basically be unwinnable" ([Toho Kingdom](https://www.tohokingdom.com/vg/godzilla_ps3_ps4/review_steve_johnson.html)).
   Astro Prospector's boss is called "RNG based" (finding 1). Del Toro designed each jaeger so that "every time you see a Jaeger
   go up against a Kaiju, it's a completely different fight", with a silhouette first and details after ([/Film featurette](https://slashfilm.com/526702/pacific-rim-featurette-explains-jaeger-design)).
   *Lesson:* stand the army down while the boss is on the field (or keep only a trickle of rooftop squads). Pick attacks from a
   seeded shuffle bag, so every attack appears before any repeats. Make the mecha's silhouette and attack set unlike anything
   the player has fought.

8. **Camera: frame both giants with a weighted centre and a capped pull-back, and keep the bearing fixed. Lock-on is optional.**
   Unity's Cinemachine group framing is the standard pattern. Several weighted targets are treated as one, and a framing size
   (1 fills the screen, 0.5 fills half) sets the zoom. A weighted average puts the centre between them, so keeping one target
   anchored needs custom code ([Cinemachine 3.1 Group Framing](https://docs.unity3d.com/Packages/com.unity.cinemachine@3.1/manual/CinemachineGroupFraming.html);
   [Unity forum](https://forum.unity.com/threads/keep-two-moving-targets-in-view-at-fixed-position-in-screen-space-for-orthographic-top-down-camera.711731/)).
   Shadow of the Colossus reviews name the camera as the fights' main problem, and its lock-on as the fix ([Game Developer essay](https://www.gamedeveloper.com/design/shadow-of-the-colossus-6-6-conclusion)).
   19 adds two rules: a camera that rides too far shrinks the monster, and the bearing should stay fixed. *For us (my
   estimate):* the centre is 0.65 player and 0.35 mecha. Zoom fits both, capped at about 1.3x the run's normal distance. When the
   mecha is farther than that, an edge marker points to it rather than the camera pulling out further.

9. **HUD: a boss bar is the accepted exception to a minimal HUD, and it is strongest when the body shows the damage too.**
   Boss bars are not a universal convention: Metroid and Symphony of the Night leave them out ([Steam thread](https://steamcommunity.com/app/368620/discussions/0/2788243698221782751)).
   Where games use one, it picks out the boss on a crowded field and appears when the boss engages ([Tenril devlog](https://heavensgates.itch.io/tenril/devlog/466716/send-for-the-apothecary-but-not-for-you)).
   Keren recommends an intro beat that builds anticipation (Arkham Knight, DMC) ([gcores](https://www.gcores.com/articles/103804)).
   Monster Hunter's shed shell is the diegetic version: the body shows the phase (finding 3). *For us:* b2-13 removed the
   player's health bar, so one thin boss bar along the top edge with phase notches is the single exception. The name card
   shows once at the intro. Armour plates fall off the voxel body at each threshold. Copy rule b2-15: the name only, with no
   mechanics explained.

## Proposed phase sheet (a PROPOSAL; every number is my estimate for the pacing bot to check)

Fight length target: 3-5 min, about two to three normal late runs. A phase changes at its HP threshold OR when its time cap
runs out, and never before its minimum time, so every phase's tell is seen at least twice even by a maxed build. Telegraph
times follow finding 5's formula from the cephalopod's speed.

| Phase | Trigger | Attacks (shape, telegraph, recovery) | Telegraph channels | City interaction |
|---|---|---|---|---|
| 0 Arrival (scripted, ~6-8 s, invulnerable) | The boss run starts | None. It assembles or lands, the army withdraws, the name card shows | Camera pulls back to two-target framing; a horn or siren sting | It lands in a district and flattens one block: the size read |
| 1 Assault (teach) | 100% to 70% HP; min 40 s, cap 75 s | **Charge**: a line strip of width 2 x body, 1.4 s tell, 2.5 s recovery if it rams a building (stuck, takes double damage). **Mortar salvo**: 3 circles of radius 3 on the player's position, 1.2 s, no recovery. **Stamp ring**: a ring around itself, 0.9 s (escape is short, it only hits up close) | Ground decal drawn from the sim shape; chest lights charge; a rising servo whine; ease-in wind-up | Its charge crashes through buildings (Carving), so the player learns that baiting it into towers opens a punish window |
| 2 Demolition (midpoint: the plates come off) | 70% to 35%; min 45 s, cap 90 s. At 70%: 3 s invulnerable "plates off" beat, armour voxels fall | Phase 1 set, plus **Undercut**: a cutting beam sweeps the base of the tower nearest the player, 1.6 s laser line on the facade plus creaking, then the tower topples via `Collapse` onto the player's side. **Hurl**: it rips a chunk or tank and lobs it, a landing decal for 1.3 s | Laser line on the building (the diegetic decal); cracking sound; the decal grows | The city becomes the weapon both ways: the player throws tanks or chunks (22's `Flung`) to stagger it (3 hits = 2 s stagger), and towers it topples can also hit it |
| 3 Overdrive (the arena collapses) | 35% to 0%; min 30 s, no cap (the run clock still applies) | It sheds its shell: smaller and faster (Kulve Taroth). Charge and Undercut only, tells shortened to the formula's floor, never under 0.8 s. At 15% HP it starts to fail: longer recoveries, sparks, a stumble (Keren: lead toward a win) | Red core light pulses before every attack; overload alarm | Overloaded reactor: fires and a chain of collapses across the district, so the arena shrinks |
| 4 Fall (scripted, ~5 s) | 0 HP | None | Slow motion in the view only (the sim pauses through hit-stop, as in 22) | It topples like a tower into the city, the biggest topple of the game, then quiet and the result screen (Keren: let the win land) |

Losing: if the kaiju dies or the clock runs out, the run ends as usual and earnings are kept (D-002, active, no AFK). Proposed:
a retry starts at the last phase reached, not from 100% (my suggestion; I found no source). That keeps the final run from
being a wall, which is 01's late-game-trivial trap in reverse.

## Sim build

**Shape.** A new `sim/mecha.gd`, `class_name Mecha extends RefCounted`, owned by `RampageSim` exactly like `Army`:
`mecha = Mecha.new(self, tuning["boss"], Seeds.derive(rng, 0xB055))`, created only when `stats` flags the boss run, and
stepped after `air.step(dt)`. Its own seeded stream means adding the boss never shifts the army's or the city's draws.

State machine (fixed dt, timers only, no clock):
```
ARRIVE(t) -> CHOOSE -> TELEGRAPH(t_tell) -> STRIKE(1 tick: evaluate shape) -> RECOVER(t_rec) -> CHOOSE ...
any state --(hp <= next threshold, or phase_t >= cap, and phase_t >= min)--> SHIFT(t_shift, invulnerable) -> CHOOSE (next phase)
hp <= 0 -> FALLEN -> sim.end("boss_defeated")
```
- CHOOSE draws from the phase's **shuffle bag** of attack ids (Fisher-Yates on its own stream, as in `Army._place_squads`). Every
  attack appears once before any repeats: learnable, never streaky. A `cooldown` per attack and a `requires` condition (for
  example, Undercut needs a standing tower within reach of the player) filter the bag.
- TELEGRAPH **freezes the target shape at its start** (centre, direction, radius, length) and emits it. The view draws exactly
  what the sim will hit. The player's position at STRIKE decides the hit, never the position at the tell.
- STRIKE evaluates the shape as a `force: Callable` (circle, ring, strip, cone), the same contract as `hit_area`. It damages
  `sim.hp` (minus armour, like tanks) and carves the city through the existing path. Decision point: `hit_area` also kills tanks
  and squads. That is fine while the army stands down; otherwise add a flag to skip units.
- Mecha body in the sim: a 2D position, a facing and a radius for contact (`BodyContact` style), plus `hp` and per-part `plates`
  (each a share of HP). It takes damage from the player's stomp, signature and ultimate through the same force callables:
  `hit_area` gets one more target, as tanks are now. A plate lost is an event, and the view drops those voxels. The body is not
  a carved `Building`, since moving a carving grid is a much bigger change (my judgement).
- Undercut calls `damage_cells` on the chosen tower's floor-0 to floor-1 band, so `Collapse` topples it toward the kaiju. Add one
  sim rule: a toppling part's landing strip damages `sim.hp` (and the mecha) in boss runs. This is a `Collapse` change, so it
  goes through the kaiju-sim-review packet.

**Events (presentation reads, never decides):** `boss_arrive`, `boss_telegraph {attack, shape, at, dir, r, len, t}`,
`boss_strike {attack, hit}`, `boss_hurt {amount, part}`, `boss_plate_lost {part}`, `boss_stagger {t}`, `boss_phase {phase}`,
`boss_fallen {x, z, dir}`. Add `"boss": phase_reached` to `result()`.

**Data schema sketch (`data/boss.json`, schema-validated):**
```json
{
  "id": "bulwark", "hp_by_species": {"reptilian": 9000, "insectoid": 8000, "cephalopod": 10000},
  "radius": 6.0, "speed": 3.0, "armor": 4, "plates": 6,
  "stagger": {"hits": 3, "seconds": 2.0}, "retry_from_phase": true,
  "phases": [
    {"until_hp": 0.70, "min_s": 40, "cap_s": 75, "shift_s": 3.0, "bag": ["charge", "salvo", "stamp"]},
    {"until_hp": 0.35, "min_s": 45, "cap_s": 90, "shift_s": 3.0, "bag": ["charge", "salvo", "undercut", "hurl"]},
    {"until_hp": 0.0,  "min_s": 30, "cap_s": 0,  "speed_mult": 1.4, "radius_mult": 0.75, "bag": ["charge", "undercut"]}
  ],
  "attacks": {
    "charge":   {"shape": "strip", "len": 30, "width": 2.0, "tell": 1.4, "recover": 1.0, "recover_on_wall": 2.5, "damage": 35, "cooldown": 6},
    "salvo":    {"shape": "circles", "count": 3, "r": 3.0, "spread": 4.0, "tell": 1.2, "recover": 0.6, "damage": 20, "cooldown": 5},
    "stamp":    {"shape": "ring", "r": 9.0, "tell": 0.9, "recover": 0.8, "damage": 25, "cooldown": 4, "requires": "player_within:9"},
    "undercut": {"shape": "tower_base", "reach": 14, "tell": 1.6, "recover": 1.2, "damage": 30, "cooldown": 9, "requires": "tower_near_player:14"},
    "hurl":     {"shape": "circle", "r": 3.5, "tell": 1.3, "recover": 0.8, "damage": 25, "cooldown": 7, "requires": "chunk_or_tank:10"}
  },
  "telegraph_floor_s": 0.8
}
```
The values are placeholders. `tell` must not drop below `0.35 + 1.25 x escape / min_species_speed` (a test, below).

**Tests (headless, pinned seeds, every function counted per kaiju-godot-tests):**
1. *Replay:* run the whole fight twice with the same seed and a scripted input track, then compare a hash of the event log and
   of `(hp, mecha.hp, phase)` taken every tick. Equal means deterministic. Factorio's per-tick CRC and replay bisection is the
   model ([FFF #47](https://factorio.com/blog/post/fff-47); [FFF #55](https://factorio.com/blog/post/fff-55)).
2. *Telegraph fairness:* for every attack and every species at base speed, a bot that starts moving straight out of the shape
   0.35 s after `boss_telegraph` takes no damage. A bot that stands still is always hit (the player-effect fixture).
3. *Phase floor:* a maxed build (every node owned) still sees every phase and at least 2 tells of each attack in its bag. This
   is the Astro Prospector "melting it before ... its entire loop" guard (min_s).
4. *Pacing bot:* extend `tools/pacing.gd`. At the expected upgrade level at boss unlock, the scripted player beats the boss in
   3-5 min on 2-3 tries. Just after the final evolution with half the tree, it loses. Assert the bands per species.
5. *City as a tool:* a fixture where Undercut topples a tower and the landing strip damages the kaiju; one where three thrown
   tanks stagger the mecha; one where a charge into a building gives `recover_on_wall`.
6. *Layering:* `sim/mecha.gd` has no Node or Scene reference (the existing layer lint).

## Sources

- Nodebuster godvirus thread: https://steamcommunity.com/app/3107330/discussions/0/594028416743941551/
- Nodebuster late game (Reddit): https://www.reddit.com/r/incremental_games/comments/1g98y7n/nodebuster_is_a_really_fun_and_addicting/
- Chef Knight community hub: https://steamcommunity.com/app/4304930
- Astro Prospector: https://note.com/ebisen/n/n96a4a3d52f2c?hl=en ; https://steamcommunity.com/app/3503440/discussions/0/596284732212325460/ ; https://www.reddit.com/r/incremental_games/comments/1lzrmgb/astro_prospector_is_out_now_on_steam_and_were/
- Brotato Invoker: https://brotato.wiki.spellsandguns.com/Invoker
- Vampire Survivors Reaper: https://vampire.survivors.wiki/w/The_Reaper
- Halls of Torment Lich (guide): https://www.pcinvasion.com/?p=373695
- Rampage: Total Destruction review: https://nintendoworldreport.com/review/11593/rampage-total-destruction-gamecube
- Godzilla PS4 review: https://www.tohokingdom.com/vg/godzilla_ps3_ps4/review_steve_johnson.html
- Stout, boss structure: https://www.gamedeveloper.com/design/boss-battle-design-and-structure ; telegraphing: https://www.gamedeveloper.com/design/enemy-attacks-and-telegraphing
- Keren, Boss Up (GDC 2018): https://www.gdcvault.com/play/1024921/Boss-Up-Boss-Battle-Design ; translation https://www.gcores.com/articles/103804
- Vessal, Psychonauts 2 maneuvers (GDC 2023): https://www.gamedeveloper.com/marketing/using-a-modular-system-of-maneuvers-to-design-i-psychonauts-2-i-s-boss-fights-in-a-hurry
- Pineda, Titanfall 2 Titan combat: https://labs.invenglobal.com/articles/1230/redesigning-titan-combat-strategical-decisions-that-made-titanfall-great-again
- Monster Hunter: https://monsterhunterwiki.org/wiki/Kulve_Taroth_(MHWorld) ; https://monsterhunterworld.wiki.fextralife.com/Safi'jiiva+Siege ; complaint https://www.reddit.com/r/monsterhunterrage/comments/xb8oem/monster_telegraphs_are_kind_of_terrible_in/
- Reaction time: https://coddy.tech/tools/es/reaction-time-test ; https://duckware.com/tech/measure-human-visual-response-times.html
- Giant-creature animation: https://www.vfxvoice.com/weta-digital-gives-weight-to-the-giant-monsters-of-rampage/ ; https://beforesandafters.com/2024/05/01/for-godzillas-walk-we-put-a-speedometer-on-his-feet-just-to-see-how-fast-they-go/
- Pacific Rim design: https://slashfilm.com/526702/pacific-rim-featurette-explains-jaeger-design ; https://www.showbizjunkies.com/movies/pacific-rim-review/amp/
- GigaBash: https://virtualseasia.com/?p=12819
- Shadow of the Colossus camera: https://www.gamedeveloper.com/design/shadow-of-the-colossus-6-6-conclusion
- Cinemachine group framing: https://docs.unity3d.com/Packages/com.unity.cinemachine@3.1/manual/CinemachineGroupFraming.html ; https://forum.unity.com/threads/keep-two-moving-targets-in-view-at-fixed-position-in-screen-space-for-orthographic-top-down-camera.711731/
- Boss bars: https://steamcommunity.com/app/368620/discussions/0/2788243698221782751 ; https://heavensgates.itch.io/tenril/devlog/466716/send-for-the-apothecary-but-not-for-you
- Factorio determinism: https://factorio.com/blog/post/fff-47 ; https://factorio.com/blog/post/fff-55
- Earlier notes: 01-incremental.md (f9, r5), 16-upgrade-tree.md, 19-camera.md, 15-minimal-hud.md, 22-flung-vehicles.md, 02-kaiju-lore.md (f8, f9)

## For Kaiju Incremental (ranked, simplest viable first; costs are my estimates)

1. **Settle the finale's shape before any code: one boss rampage, unlocked by a final landmark node after the last evolution.**
   It is fought in the player's current city, one on one, with the army stood down. Beating it ends the game (credits, then
   free play or a harder loop as 01 suggests), which answers VISION's "what ends the game". This is the director's call
   (VISION open item), put as one question with the concept board from item 7. *Cost: half a day (board and question); no code.*
2. **`sim/mecha.gd` plus `data/boss.json`: the state machine, shuffle bag, three attacks (charge, salvo, stamp), HP-or-time
   phases with a minimum time, events, the `boss_defeated` end, and tests 1-3 and 6.** Use a greybox body (a box of voxels) and
   decals only. This alone makes a playable finale. *Cost: 3-5 days, with the sim-review packet because it adds an end reason and
   a target to `hit_area`.*
3. **Telegraph presentation: a ground decal drawn from the event's shape, charge lights, a rising servo sound, and every tell
   also visual (GAG, 15 finding 5).** Use slow ease-in wind-ups and nothing feinted. *Cost: 1-2 days; view only. It needs a motion
   clip at game speed through the motion critic before it reaches the director.*
4. **The city as the weapon: Undercut (an existing `Collapse` topple plus a landing strip on `sim.hp`), a charge into a building
   that leaves it stuck, and thrown tanks or chunks that stagger it.** The throw half depends on 22's `Flung` (its item 2).
   Without it, ship Undercut and the wall-stun first. *Cost: 2-3 days after `Flung`; a `Collapse` change, so sim review.*
5. **Camera and HUD for the fight: two-target framing (weighted 0.65/0.35, pull-back capped at 1.3x, an edge marker beyond
   that), a thin top boss bar with phase notches, a one-time name card, and plates falling off the body.** *Cost: 1-2 days; needs
   labelled 4K captures and the screen critic, plus the director's yes on the bar as the one HUD exception.*
6. **The ending beat: the mecha falls like the game's biggest tower, a few seconds of quiet, then a results and credits
   screen.** Do not start a new challenge straight after the win (Keren). *Cost: 1-2 days.*
7. **The mecha's art and animation (the biggest cost): a voxel model in the city's own materials, with a rig and 6-8 clips
   (arrive, walk, charge, salvo, stamp, undercut, stagger, fall).** Through the existing Blender pipeline, art QA and realism or
   motion critics. *Cost: 1-2 weeks. Start the concept board early so item 2's greybox can be built at the chosen silhouette's
   size.*

Total, my estimate: about 3-5 weeks, inside phase H, after rooftop mortars as the roadmap orders.

### Original mecha concepts (for the director's board; each avoids a Mechagodzilla read)

Mechagodzilla is by definition a metal copy of Godzilla's own body plan. So **no concept mirrors the player's silhouette**,
and none is an upright reptile (02 finding 9: Toho enforces look-alikes).

1. **BULWARK, the walking district.** The defence force welds standing tower blocks onto a four-legged gantry frame. Its armour
   plates are real city buildings in the city's own materials (glass, brick, concrete), so they carve and fall like the towers
   the player has smashed for hours. Its silhouette is a skyline on legs. It repairs between phases by tearing chunks from
   nearby buildings, so a flattened district starves it: the player's destruction becomes a strategy. In phase 3 the buildings
   are gone and a fast steel frame remains.
2. **CONVOY, the army's last answer.** It is assembled from every tank and helicopter hull the player has wrecked, with the count
   taken from the save. Tank turrets serve as knuckles, rotor blades as a spinning shield and track belts as tendons. Its attacks
   are the army's, made huge (a salvo of shells, a strafing rotor sweep), so the player already knows the tells. Damaged hulls
   drop off as live tanks the player can throw back. This is the cheapest concept for art, since it reuses tank and heli parts.
3. **FOUNDRY, the builder against the destroyer.** A construction machine: tower-crane arms, a wrecking-ball tail swinging like a
   pendulum (the most readable telegraph possible), pile-driver feet and a pour nozzle that raises fresh concrete walls as cover
   and blockades. It rebuilds the city in front of the player while the player tears it down, the pillar inverted as a
   character. It is low and wide, not humanoid.
4. **COUNTERMEASURE, built to fight YOU (adaptive, not a mirror).** It reads the player's species and top tree branch and arrives
   with the counter fitted: heat-sink fins against the breath cone, a spiked dome against Leap Slam, blade arms against Tentacle
   Lash. Each phase it bolts on a new counter, and breaking that part (a plate) removes it. Its body plan is deliberately alien,
   for example a spider tripod or a rolling drum. This concept matches the director's "built to fight you" literally, but costs
   the most (three loadouts), and its reptilian loadout must be checked against Mechagodzilla on the board.

**Evidence gaps:** Keren's talk is only available as a Chinese summary and a members-only video. No source gives telegraph
timings for giant bosses, so 0.8-1.8 s comes from reaction-time data plus our speeds. I found no developer postmortem on the
endings of Nodebuster, Astro Prospector or Chef Knight, and Astro Prospector's ending is unverified (a video only). Halls of
Torment, Ball x Pit (an endless mode after each stage boss, no clear campaign finale found) and GigaBash's bosses are covered
only by guides and store pages. No design interviews were found for Hades or Furi bosses (Furi's post had no boss content), or
for Godzilla PS4, Destroy All Monsters Melee, or the Sonic and Ratchet mech bosses. The phase sheet, HP values, fight length,
camera weights and "retry from the last phase" are my proposals for the pacing bot and a director playtest to settle.
