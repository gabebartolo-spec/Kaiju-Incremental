# Rooftop mortars you kill by toppling their building (research notes, 2026-10-21, roadmap Phase H)

Director, 2026-10-19 (docs/ROADMAP.md line 25): "rooftop mortars (topple the building to kill them)". Phase H lists
"Rooftop mortars" first (docs/ROADMAP.md line 83). Code read (read-only) at `claude/walkers-on-pavement`, tip 8bda611:
`sim/army.gd` in full, `sim/collapse.gd`, `sim/carving.gd`, `sim/structure.gd`, `sim/voxel_frame.gd`,
`sim/rampage_sim.gd` (Building, Fall), `sim/city_gen.gd` (districts, cores), `scenes/rooftop_view.gd`, `data/tuning.json`
(army.rooftop, city, camera). Builds on research 01, 06, 15, 19 and 22.

**The most important code fact: the game already has rooftop enemies.** D-063 rooftop squads (`Army.Squad`) stand
on the roof chunk `cell` of building `building`. They are placed at sim start on roofs of 4 floors and up, fire
rifle volleys at range 24 plus the stomp radius, and die when `sim.buildings[squad.building].frame.alive(squad.cell)`
turns false or a splash reaches their roof floor. They pay `rooftop_rubble` by tier and emit `rooftop_destroyed`.
A mortar is therefore a new kind of an existing unit, not a new system. The work is in the telegraph, the
out-ranging and the topple payoff.

## Key findings

1. **"Shot at from the building you then destroy" is the genre's oldest pattern, but as written it is a slow,
   ignorable health drain.** In Rampage: Total Destruction, "Gunners are always taking pot shots from buildings
   above, so your health tends to slowly decrease over time". The same review says the army is little danger if
   dealt with quickly ([Nintendo World Report](https://nintendoworldreport.com/review/11593/rampage-total-destruction-gamecube)).
   The 1986 arcade original had soldiers firing through windows, so the player dodged or smashed that section. Weak
   source: this comes from a search summary of a Tropedia page, which I could not open (HTTP 402). Wikipedia lists
   only "enemy bullets, shells, sticks of dynamite" among damage sources
   ([Wikipedia](https://en.wikipedia.org/wiki/Rampage_(video_game))). *Lesson:* our D-063 rifles are already this
   "chip" design. A mortar has to be the opposite: rare, telegraphed, a real threat, and worth a detour.

2. **Collapsing a structure onto the enemy is the payoff reviewers single out in destruction games.** Red Faction:
   Guerrilla: "There is nothing more satisfying than strategically collapsing a ten story smokestack onto
   unsuspecting EDF" ([The HD Room](https://thehdroom.com/reviews/red-faction-guerrilla-ps3-xbox-360-review-30235/)).
   Cinemablend notes that a short delay before collapse "lets you admire your destruction"
   ([Cinemablend](https://cinemablend.com/games/Review-Red-Faction-Guerrilla-18124.html), via search summary).
   Designer James Hague says falling debris can "cause further destruction, including killing people"
   ([Red Faction Wiki interview](https://www.redfactionwiki.com/wiki/Interview_with_James_Hague)). Bad Company 2
   was marketed on toppling a building "with enemies inside", and it was rare in the campaign because buildings took
   "a considerable amount of punishment" first
   ([The Boar](https://theboar.org/2010/03/battlefield-bad-company-2/), via search summary). *Lesson:* the kill should
   land when the tower lands (the visible moment), not when its support breaks.

3. **Kill-by-collapse becomes a cheap exploit when every target is collapsible. Shipped games answered by limiting
   which targets are exposed.** In BC2 multiplayer, objectives inside destructible houses could be toppled, which
   players called cheap. DICE added indestructible cover in BF3 "for many gameplay reasons, including making it
   easier for defenders in the Rush game mode" ([MP1st](https://mp1st.com/news/update-dice-clarifies-destruction-in-battlefield-3);
   context in [Battlefield Wiki search summary](https://battlefield.fandom.com/wiki/Destruction)). For us the
   exploit runs the other way, and it is the point: toppling is the verb we want rewarded. The open risk is a mortar
   placed on a building the kaiju cannot realistically topple (a landmark, a tower that dwarfs it). Spawn rules must
   exclude those.

4. **A stationary artillery piece works as a priority target when it out-ranges you and warns you.** Helldivers 2's
   automaton mortar emplacements get an explicit "enemy artillery" warning, the only enemy structure that does.
   Players say the launch sound ("PTOOM") already gives the position away, ask for a direction ("southeast of your
   position"), and want the warning only on entering range. The standing advice is "Just look up" to see where
   shells come from ([Steam discussion](https://steamcommunity.com/app/553850/discussions/0/4840896594183790667/?ctp=1)).
   Just Cause 2 puts 185 SAM sites on base roofs and perimeters, worth 500 Chaos each, and guides say to destroy
   them first when attacking from the air
   ([Just Cause Wiki](https://justcause.fandom.com/wiki/SAMs_in_Panau)). *Lesson:* a launch sound, a direction
   and a one-time warning are enough. Repeated text warnings annoy.

5. **Telegraph rules: a delay, a consistent cue, sound plus sight, and the hit resolves when the marker ends.**
   Mike Stout: players must know an attack is coming before they are expected to avoid it. Projectiles are
   telegraphed with a mix of animation, sound, effects and a charge-up, not animation alone
   ([Game Developer](https://gamedeveloper.com/design/enemy-attacks-and-telegraphing)). Final Fantasy XIV's
   ground-AoE convention: bright orange ground highlights, and the hit "snapshots" when the telegraph disappears
   ([FFXIV wiki](https://ffxiv.consolegameswiki.com/wiki/AoE_marker)). One cue must always mean one outcome
   ([Game Developer, ARPG readability](https://www.gamedeveloper.com/game-platforms/designing-for-difficulty-readability-in-arpgs),
   via search summary). Subset Games made telegraphed attacks central to Into the Breach so that every death feels
   like the player's own fault ([Game Developer, Road to the IGF](https://gamedeveloper.com/game-platforms/road-to-the-igf-subset-games-i-into-the-breach-i-),
   via search summary). *For us:* a landing ring that fills over the flight time, with damage applied on the tick
   it completes, is deterministic and fair.

6. **Off-screen threats need a second channel and must not rely on colour alone.** Xbox Accessibility Guideline 103:
   "Damage halos, directional indicators, and enemy markers supplement audio", and colour should "Reinforce other
   channels — never the sole channel" ([Xbox XAG 103](https://devdocs.xbox.com/gaming/accessibility/xbox-accessibility-guidelines/103)).
   This matches research 15's edge-vignette plan. A mortar firing from behind the camera needs a positional launch
   sound and a shaped (chevron) edge cue, not just a red tint.

7. **Kaiju games mostly use the military as fodder, so a building-bound artillery threat is a gap we can own.**
   Godzilla (PS4, 2015) has G-Force troops and asks the player to destroy G-Energy generators
   ([Wikipedia](https://en.wikipedia.org/wiki/Godzilla_(2014_video_game));
   [Plugged In](https://www.pluggedin.com/game-reviews/godzilla-2015-playstation/)). War of the Monsters lets you
   "wage war on rooftops, and bring them crashing down", but I found no source on rooftop turrets there
   ([Lutris listing](https://lutris.net/games/war-of-the-monsters/)). Prototype's soldiers call in a "strike team"
   (1-4 helicopters, up to 4 UAVs) unless stopped first, and destroying a base stops the calls for a while
   ([Prototype Wiki, search summary](https://prototype.fandom.com/wiki/Military_base)). That is a priority-target
   pattern: kill the caller before the bigger threat arrives.

8. **The code already supports almost everything (my reading, verified line by line).**
   (a) Squad death is a roof-chunk check every tick (`army.gd:96`). The carved grid keeps the chunk Structure "as a
   coarse mirror for what still reads chunks (army squads ...)", and a chunk dies at `chunk_alive_share` 0.5 of its
   cells (`carving.gd:14-18`, `tuning.json:676`).
   (b) `Collapse.settle` removes the falling part's chunks from the Structure (`structure.gd:82-84`) and emits
   `fall_start {id, building, cells, kind "drop"|"topple", pivot, dir, cut_dir, drop, duration}`. So **today a squad
   on a toppling tower dies on the next tick after the fall starts**, and its dust puff and "+N" appear at the old
   roof position in mid-air. That is not where the tower lands.
   (c) `Collapse._land` emits `fall_land {id, kind, building, from, to, width, scrap}`, pays the chunks with
   `city.topple_bonus` (1.5), crushes a strip of street (other buildings' low floors, and sets every tank in the
   strip to hp 0) and calls `army_units.clear_dead()` (`collapse.gd:166-245`).
   (d) Placement is seeded at sim start from the army's own stream (`Seeds.derive(rng, 0x2007)`, Fisher-Yates over
   buildings of `min_height` and up).
   A mortar can reuse (a) and (d) as they are. It needs (b) changed into "ride the fall", and it gets (c) for free.

9. **At our camera, a roof figure is small at 4K, and the existing volley art is tuned to stay visible.**
   `rooftop_view.gd` puts the muzzle flash at 0.5 world units, "about 15 px at the Behemoth's game camera". Flashes
   and sparks are unshaded, additive and fog-free so a volley "reads at the game camera from across the city". At
   most 36 figures are drawn, nearest first. My estimate: 4K, 60 degree vertical FOV, 1 world unit at distance D
   covers about 1870/D px. The camera sits about 32-49 units from the kaiju (offset (0,16,30) times zoom
   0.95-1.43, research 19). A mortar about 40 units past the kaiju is therefore about 70-90 units away, so 1 unit
   is about 20-27 px, and a 1-unit figure is about 20 px. A mortar has to read from shape and light, not from the
   figure: a 2x2-cell emplacement, a beacon, a smoke column and the landing ring.

10. **A mortar breaks a "stay in the centre" stomp loop only if it out-ranges the kaiju and cannot hit at point
    blank.** Inference from findings 1, 4 and 7. Rifles hit within 24 plus the stomp radius, and tanks follow the
    kaiju. A mortar that fires at 2-3x rifle range, with a dead zone up close, gives a reason to walk to it. Toppling
    it then pays a bounty plus the topple bonus and can crush a convoy in the strip, the "bigger than the last"
    beat. The 1-2 s flight lets a moving kaiju dodge: base speed 5.0 units/s (`tuning.json:67`) covers 8 units in
    1.6 s, so a blast radius under about 6 is dodgeable. This is an estimate and has not been played.

## Telegraph sheet (PROPOSAL, my design, not sourced as a whole; numbers are starting values)

| Event (sim) | Visual | Sound | Timing | Camera / HUD cue |
|---|---|---|---|---|
| Mortar placed (sim start) | 2x2-cell sandbag ring and tube on the roof, a red beacon strobing at 1 Hz (unshaded, fog-free, drawn like `rooftop_view` flashes), visible over BuildingFade's screen door | none | constant | none (the beacon is the cue) |
| Kaiju enters mortar range (first time per mortar) | beacon strobe speeds up to 3 Hz, tube turns to the kaiju | a short klaxon from the roof (positional) | once | none |
| `mortar_fired {mortar, from, to, t_land}` | muzzle flash plus a grey smoke puff, and a shell tracer climbing out of the roof (slow, about 1 s visible) | a deep "thunk" from the roof, positional | t = 0 | if the mortar is off screen, a chevron at the screen edge pointing at it, 1 s (shape, not colour alone, XAG 103) |
| Shell in flight | landing ring on the ground at `to`: an outline at full radius plus a fill growing from the centre to the rim over the flight time | a rising whistle in the last 0.6 s | flight time T = 1.6 s (1.2-2.0 by tier) | none (the ring is in the world) |
| `mortar_landed {mortar, at, hit}` | blast, dust, cells carved if it lands on buildings (optional), and a hit flash on the kaiju if hit | blast boom; the same hit growl as other damage | t = T, the tick the fill completes | edge vignette pulse if hit (research 15) |
| `mortar_destroyed {mortar, cause, x, y, z}` | cause "topple": dust and a "+N" float at the landing point; "carve": a puff at the roof; beacon goes out | crash plus a small bounty chime | at `fall_land` for a topple, at once for a carve | "+N" float text (existing Label3D pattern) |

Rules: one cue, one meaning (red beacon = mortar, only mortars). Never more than about 4 rings on screen at once
(cap the number of mortars firing at once). Rings and the beacon are presentation only and read sim fields
(`from`, `to`, `t_land`). They never write them.

## Sim hooks (grounded in the code read; a PROPOSAL for the shape)

**Unit state.** Use a new `class Mortar` in a new `sim/mortars.gd` owned by `Army` (`army.gd` is 233 lines; split as
`collapse.gd` was):
`id, building, cell: Vector3i, pos: Vector2, cooldown, fall_id := -1, dead := false, cause := ""`, plus
`shells: Array` of `{from: Vector3, to: Vector2, t_land: float}`. Tunables go in `data/tuning.json` under
`army.mortar` (schema-validated): `min_height`, `max_by_tier`, `min_spacing`, `range`, `min_range`,
`fire_interval`, `interval_jitter`, `flight_time_by_tier`, `blast_radius`, `damage_by_tier`, `bounty_by_tier`,
`max_firing`.

**Spawn rule.** Run at sim start like `_place_squads`, on its own derived stream
(`Seeds.derive(rng, <new salt>)`), so the run stays replayable and squads are unchanged:
- Candidates: buildings with `height >= mortar.min_height`, set above the rifle `min_height` of 4 (e.g. 12 floors,
  about tier 2 at `tier_height` 7), `landmark == ""` and `in_arena`, preferring those inside a tower core
  (`CityGen.cores`, x, z, radius). Downtown reads as "the army dug in on the towers".
- Exclude buildings the current size tier cannot bring down. A dwarfing tower takes `Growth.dwarf_mult` of each
  blow (D-091), so a cap such as `height <= k x kaiju height` keeps every mortar topple-able. Finding 3.
- Fisher-Yates over candidates; take while `count < max_by_tier[tier]` and the new one is `>= min_spacing` from every
  placed mortar. Starting value 2/3/4/5 per tier: rare, so each is an event.
- The mortar's roof cell avoids the squad's roof cell and the stair-hut corner (the same rule as `army.gd:214`).
- No line-of-fire test: a mortar is indirect fire, unlike tanks (`convoy.clear_line`). That is what lets it shell
  the kaiju from behind a block.

**Firing.** Each tick, when `cooldown <= 0` and `min_range + stomp_radius < dist <= range + stomp_radius` and fewer
than `max_firing` shells are in the air: `to = sim.kaiju_pos` (aim where the kaiju is; no lead, so moving dodges),
`t_land = sim.time + flight_time`. Append the shell and emit `mortar_fired`. Each tick, a shell whose
`t_land <= sim.time` resolves: `sim.hp -= damage x army.threat_scale()` if
`sim.kaiju_pos.distance_to(to) <= blast_radius + body radius`, then `mortar_landed`. This is a timed landing with no
integration. Research 22's exact-parabola event (`p0, v0, tick0`) is the upgrade path if shells ever need to hit
buildings mid-flight. Presentation draws the arc from `from`, `to` and `flight_time`. No clock is used; `sim.time`
advances by fixed dt.

**Death on carve.** The same check as squads: `not sim.buildings[m.building].frame.alive(m.cell)`. Carved buildings
mirror into the chunk Structure (finding 8a). Cause `"carve"`; death and payment at once.

**Death on topple (the director's verb), with "ride the fall".** In `Collapse.settle`, when a part's `cells` contain
a mortar's `cell` for that `building`, set `m.fall_id = f.id` (and stop it firing). The per-tick alive check skips a
mortar with `fall_id >= 0`. In `Collapse._land`, any mortar with `fall_id == f.id` is killed with cause
`"topple"` if `f.kind == "topple"` and `"drop"` otherwise. The event carries the landing point (`to` for a topple,
the pivot for a drop), so dust and "+N" appear where the tower hits. One `fall_id` field and two lookups.
Determinism holds: the fall ids and the scan order are already fixed. A "scrap" fall (`cells` empty) cannot contain
the cell, so it never carries a mortar.

**Splash.** The director's words say topple. Recommend mortars ignore `Army.splash` (stomp, cone, ring), so the
only kills are taking the roof away: topple, drop, or carving the roof cell. That keeps the verb distinct from
rifle squads. This is the director's call.

**Credit.** On death: `sim.rubble += bounty_by_tier[tier] x sim.stat("rubble_mult") x (city.topple_bonus if cause
== "topple" else 1)`. Count `mortars_destroyed` and `mortars_toppled` in the run stats next to `toppled` and
`tallest_topple` (`rampage_sim.gd:188`). The tower's own chunks still pay through `sim.pay` with the topple bonus.
**Combo:** `_crush_strip` already kills tanks in the strip. Adding mortars whose building is struck and whose roof
floor is below the strip height (short neighbours) is a one-loop addition. Tall neighbours fall through the normal
path when their low floors break.

**Tests (pinned seed, per kaiju-godot-tests and kaiju-sim-review).** (1) The same seed places the same mortars
twice. (2) A forced topple of a mortar's building gives `mortar_destroyed cause=topple` on the same tick as that
fall's `fall_land`, not at `fall_start`. (3) Carving the roof cell kills with cause carve. (4) A shell at a
stationary kaiju hits; a kaiju moving at base speed out of the ring misses. (5) Stomp splash does not kill a mortar
(if the director rules so). This touches shared sim rules, so a kaiju-sim-review packet is needed.

## Sources

- Nintendo World Report, Rampage: Total Destruction (GC): https://nintendoworldreport.com/review/11593/rampage-total-destruction-gamecube
- Wikipedia, Rampage (1986): https://en.wikipedia.org/wiki/Rampage_(video_game)
- Tropedia, Rampage (not opened, HTTP 402; search summary only): https://tropedia.fandom.com/wiki/Rampage_(video_game)
- The HD Room, Red Faction: Guerrilla review: https://thehdroom.com/reviews/red-faction-guerrilla-ps3-xbox-360-review-30235/
- Cinemablend, Red Faction: Guerrilla review (search summary): https://cinemablend.com/games/Review-Red-Faction-Guerrilla-18124.html
- Red Faction Wiki, interview with James Hague: https://www.redfactionwiki.com/wiki/Interview_with_James_Hague
- GDC Vault, Multiplayer Level Design in Red Faction Guerrilla (page only): https://gdcvault.com/play/1012330/Multiplayer-Level-Design-in-Red
- The Boar, Bad Company 2 (search summary): https://theboar.org/2010/03/battlefield-bad-company-2/
- Battlefield Wiki, Destruction (not opened, HTTP 402; search summary only): https://battlefield.fandom.com/wiki/Destruction
- MP1st, DICE clarifies destruction in BF3: https://mp1st.com/news/update-dice-clarifies-destruction-in-battlefield-3
- Steam, Helldivers 2 artillery warning thread: https://steamcommunity.com/app/553850/discussions/0/4840896594183790667/?ctp=1
- Just Cause Wiki, SAMs in Panau: https://justcause.fandom.com/wiki/SAMs_in_Panau
- Game Developer, Mike Stout, Enemy Attacks and Telegraphing: https://gamedeveloper.com/design/enemy-attacks-and-telegraphing
- FFXIV wiki, AoE markers: https://ffxiv.consolegameswiki.com/wiki/AoE_marker
- Game Developer, Designing for difficulty readability in ARPGs (search summary): https://www.gamedeveloper.com/game-platforms/designing-for-difficulty-readability-in-arpgs
- Game Developer, Road to the IGF: Into the Breach (search summary): https://gamedeveloper.com/game-platforms/road-to-the-igf-subset-games-i-into-the-breach-i-
- Xbox Accessibility Guideline 103: https://devdocs.xbox.com/gaming/accessibility/xbox-accessibility-guidelines/103
- Wikipedia, Godzilla (2014 video game): https://en.wikipedia.org/wiki/Godzilla_(2014_video_game)
- Plugged In, Godzilla (PS4): https://www.pluggedin.com/game-reviews/godzilla-2015-playstation/
- Lutris, War of the Monsters listing: https://lutris.net/games/war-of-the-monsters/
- Prototype Wiki, Military base (search summary): https://prototype.fandom.com/wiki/Military_base
- Repo (read-only): sim/army.gd, sim/collapse.gd, sim/carving.gd, sim/structure.gd, sim/rampage_sim.gd, sim/city_gen.gd, scenes/rooftop_view.gd, data/tuning.json, docs/ROADMAP.md

## For Kaiju Incremental (ranked, simplest viable first)

1. **Mortar as a sibling of the rooftop squad, placed at sim start, killed by losing its roof (cost: about 1.5-2
   days sim plus tests).** Add `sim/mortars.gd` (Mortar, placement, firing, timed shells) and `army.mortar` data.
   Placement: tall, non-landmark, topple-able buildings, preferring tower cores, spaced, 2-5 per tier. Fire beyond
   rifle range with a dead zone up close, one shell per 4-6 s, flight 1.6 s, aimed at where the kaiju is. Death by
   the existing roof-chunk check. Needs a kaiju-sim-review and a pinned-seed suite (tests 1, 3, 4).
2. **"Ride the fall": kill and pay at `fall_land`, with the topple bonus and a mortar bounty (cost: about 0.5 day).**
   `fall_id` on the mortar, set in `Collapse.settle`, resolved in `Collapse._land`. This is the director's "topple the
   building to kill them" made visible, with the "+N" where the tower hits (finding 2). Test 2 proves it. Consider
   the same fix for D-063 squads: today they die mid-air at fall start (finding 8b).
3. **Telegraph kit from existing parts (cost: about 1.5-2 days presentation).** Beacon and flash in the
   `rooftop_view` style (unshaded, additive, fog-free, drawn over the fade). A filling landing ring as a decal or a
   flat unshaded mesh. Thunk, whistle and boom through the existing `play_near` SFX. Free CC0 sounds only, each
   added to `LICENSING_REGISTER.md` before use, no spend. Needs a 4K capture at the Behemoth camera, judged by a
   screen critic, before the director sees it.
4. **Off-screen chevron for a firing mortar (cost: about 0.5-1 day).** Show it only for 1 s after `mortar_fired`, only
   when the mortar is off screen, using `camera.unproject_position` clamped to the screen edge (research 15 pattern).
   Shape plus a positional sound per XAG 103. No persistent markers, which keeps the minimal HUD.
5. **Topple-onto combo (cost: about 0.5 day).** In `_crush_strip`, also kill mortars on struck buildings whose roof
   floor is under the strip height, with a combo bounty. Tanks already die there, so a tower dropped across a convoy
   and a mortar nest is the "bigger than the last" beat.
6. **Upgrade-tree hooks (cost: data plus design; nodes are the director's to choose).** "Bounty" (mortar biomass
   up), "Topple radius" (crush-strip half-width up), "Falling debris kills" (the strip reaches higher floors),
   "Shell-shrug" (mortar damage down). These change what the player chases, not just numbers (research 01,
   finding 5).
- **Not recommended now:** a live spawn director that adds mortars mid-run (start-placed is simpler and
  deterministic); leading the aim (undodgeable at kaiju speed); mortars that hit buildings mid-flight (needs research
  22's ballistic sweep); mortars on landmarks or dwarfing towers (an exploit-proof kill the player cannot make).

## Evidence gaps

I could not open the Rampage 1986 window-soldier detail at a primary source, the Battlefield wiki (402), the RFG and
BC2 GDC talks (gated) or any War of the Monsters or GigaBash turret detail. I found no shipped kaiju game with
rooftop artillery killed by collapse, and no published telegraph timing for mortar flight. All pixel sizes, flight
times, counts and ranges here are my estimates from our code and data, not playtested.
