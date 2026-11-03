# DRAFT: Sound and music (roadmap row 9)

**DRAFT for the director's review. Nothing here is built, generated or bought.** Every cost below needs the director's
written yes in docs/DECISIONS.md before any spend. Standing rulings this draft keeps: D-030 (free CC0 libraries,
in-house synthesis), D-138/D-273 (ElevenLabs on his plan), D-114/D-184 (Suno music, he generates), D-125 (layers build
up), D-172/D-176/D-182 (brooding, menacing, classic acoustic orchestra; Jaws, 1954 Godzilla, Imperial March, Isengard;
never modern trailer "epic"), D-189 (low and creeping; fade under the results), D-141/D-184 (title: theme over city
sound), D-155 (panic then eerie quiet), D-247 (judged as a soundscape at playtest, not sound by sound), D-367 (newest
collapse cuts oldest). D-184 also put "revisit music later" on the roadmap: that is this row.

## 1. What exists now

**Mixer** (`autoload/audio_buses.gd`, built from tuning `audio`; there is no default_bus_layout.tres):
Master (limiter) > SFX (player volume, compressor) > Hero | Bed (ducked by Hero: -24 dB thr, 5:1, 800 ms) >
Debris, Crowd, Military, Ambience | UI. Music beside SFX, ducked lightly by Hero (-18 dB, 2.5:1, 400 ms). Stomps and
footsteps duck nothing. Voice manager `scenes/sfx_voices.gd`: 24 voices, hero reserve 8, per-category caps.

**Music** (`assets/music/`, provenance `docs/provenance/music.md`):

| Cue | Files | Trigger |
|---|---|---|
| Menu theme (Suno remaster of G2, D-184) | `theme.ogg` | `scenes/title_ambience.gd`, Music bus, loops from `loop_offset_s` |
| City 1/2/3 layered tracks (Suno Covers, about 65-68 bpm, 4/4, 17-21 bar loops) | `city_N_{low,drums,brass,full}.ogg` | `scenes/music_layers.gd` (one AudioStreamSynchronized), driven by `CitySound.phase`: low 0-0.05, drums 0.2-0.4, brass 0.45-0.65, full 0.75-0.9; 6 dB/s fades |

**City beds** (`scenes/city_sound.gd`, tuning `city_sound`; phase = 0.5 x destruction share + 0.5 x people fled):
crowd (full until 0.3, gone by 0.9), city_siren (peak at 0.2, gone by 0.85), city_gunfire (rises to -16 dB), city_fire
(to -12 dB), city_wind (to -16 dB). Files: `crowd_panic, city_siren, city_gunfire, city_fire, city_wind, siren_far`.

**SFX** (`assets/sfx/`, 62 files, provenance `docs/provenance/sfx.md`, licences `docs/LICENSING_REGISTER.md`):

| Group | Files | Where |
|---|---|---|
| Kaiju body | `stomp_0..2, stomp_crack, footstep, footstep_1..3, roar, breath, lash, leap_whoosh, leap_land, regen_loop` | rampage_footfall, roar_cue, leap_view, slam_view, power_cues |
| Powers | `thunder_beam(_loop,_end), blast_crack/body/rumble, sonic_boom, deflect, ready, chem_hiss, fireworks_crackle` | thunder_beam, sfx_beam, blast_fx, ability_fx |
| Destruction | `collapse` (Hero), collapse_drop (Debris) | rampage, skyline_rampage |
| Military | `rifle, tank_fire, shell_hit, heli_gun, heli_rotor, heli_crash` | tank_fx, tank_yard, heli_wreck, rooftop_view, airstrike_view |
| Rail | `train_rumble, train_horn, train_screech, train_crash, train_slide, station_bell` | rail_view |
| Title | reuses stomp (pitched, low-passed), rifle, synthesised sub/body/crack thumps, boom | title_ambience |
| Lab (Kaiju Creation) | `lab_room, lab_screens, lab_arm, lab_drawup, lab_dispense, lab_latch, lab_strike, lab_crackle, lab_overload, lab_dive, egg_crack` | kaiju_creation |
| UI / tree | `ui_click, ui_confirm, ui_deny, tree_buy, tree_maxed, tree_ring_open, tree_evolve` | ui_button, upgrade_screen, evolution_reveal |
| End | roar only (baked clip) | demo_end |

**Gaps** (no file or no trigger found):
1. Globe (hologram campaign screen): silent. No hum, marker ping or fly-to whoosh.
2. City load (`rampage_load.gd`, `loading_overlay.gd`): silent; the city music starts cold.
3. Results / demo end: D-189 "fade under the results" is the rule, but there is no results sting or stamp sound; the end screen has only the roar.
4. Taskforce: no mech sounds (servos, footfalls, cannon), no gunship identity beyond the one heli rotor, no soldier voices or radio, no VIP rotor (D-143 wants a distinct one).
5. Civilians: one crowd loop only; no near screams, car alarms, or individual flee/death one-shots (D-141 wants an agent's scream).
6. Kaiju species: croc clicking growl, Komodo snorts and tongue flicks, serpent hiss (sound ideas from the idle-states ruling) do not exist; one roar for all.
7. Building collapse: one `collapse` file for every size; no small/medium/landmark variants, no glass shower, no metal-groan pre-roll.
8. Music: no title-to-globe transition, no endless/Colossus track (D-189), wider-city pacing waits on balancing (D-366).

## 2. Cue sheet for the demo

References name qualities only (D-182): copy a proven style, never the work itself; prompts never name the work.

| # | Cue | Purpose | Trigger | Mood | Proven reference (quality copied) | Layer / duck |
|---|---|---|---|---|---|---|
| 1 | Title | Menace before play | title_screen opens | dread, distant | 1954 Godzilla main title (Ifukube): low brass and strings ostinato; far air-raid sirens | theme on Music over city sound (exists); far stomps low-passed (exists) |
| 2 | Globe | Calm before the storm | globe_view shown | cold, clinical | War-room hum of Dr. Strangelove / WarGames; CRT hologram hum | Ambience room tone; theme stripped to low strings or off; marker ping and fly-to whoosh on UI |
| 3 | City load | Bridge the cut | rampage_load start to first frame | held breath | Jaws pre-attack: silence, then a low pulse | music fades to silence; a 1-2 s low swell lands on the first stomp |
| 4 | Calm (phase 0-0.2) | Kaiju arrives | phase | creeping | Jaws approach motif; Ifukube low strings | low stem + crowd; sirens start |
| 5 | Panic (0.2-0.45) | People flee | phase | alarm | Cloverfield street chaos; air-raid sirens | drums enter; crowd and sirens peak; Bed ducked by Hero |
| 6 | Assault (0.45-0.75) | Military answers | phase, Taskforce waves | war-machine march | Imperial March; Isengard anvil five-beat rhythm (D-182) | brass enters; gunfire bed rises; crowd fades |
| 7 | Ruin (0.75-1) | Eerie aftermath | phase | dirge, huge | Shin Godzilla "Who Will Know" style lament: slow, choral weight | full stem; only fire, wind, far gunfire left (D-155) |
| 8 | Kaiju steps | Weight | rampage_footfall per foot | sub-heavy | Jurassic Park T-rex footfall (impact, water ripple); Pacific Rim Jaeger steps | SFX bus, no duck (ruling); tiered by stomp_tiers (exists) |
| 9 | Roar | Hero moment | roar_cue | primal | Godzilla roar method (resined glove on double-bass string); T-rex animal composite | Hero; ducks Bed and Music (exists); per-species variants (gap 6) |
| 10 | Breath / Thunder Beam | Power fantasy | ability | charged | 2014/2019 Godzilla atomic breath: rising crackle charge, then the beam | Hero loop with end tail (exists) |
| 11 | Building collapse | Reward | carve/topple, by size | crushing | Independence Day / San Andreas layered demolition: concrete, rebar groan, glass shower | Hero for big, Debris for small; D-367 voice rule; size tiers (gap 7) |
| 12 | Gunships | Air pressure | heli spawn / fire / crash | menacing | Black Hawk Down rotor wash; Apocalypse Now distance-shaped rotors | Military; rotor doppler by distance; distinct VIP rotor (D-143) |
| 13 | Soldiers | Small, brave | squad fire / death | tense | Saving Private Ryan small-arms realism; wordless radio squelch as texture | Military; short scream on kill (D-141) |
| 14 | Mechs | Rival weight | mech step / fire | industrial | Pacific Rim / RoboCop ED-209 hydraulics and servo whine | Military; steps lighter than the kaiju's so the kaiju stays heaviest |
| 15 | Civilians | Stakes | crowd density, near flee | panic, then gone | Cloverfield crowd; War of the Worlds (2005) street screams | Crowd bus; near one-shots within the crowd cap of 3 |
| 16 | UI | Clear feedback | buttons, tree | crisp | Tactical HUD clicks (Kenney style, exists) | UI bus, never ducked |
| 17 | Results / end | Payoff, calm | rampage ends / demo_end | aftermath | D-189: layers fade over about 2 s leaving low strings; one timpani/brass stamp per result row | Music low stem; UI stamp; roar on demo end (exists) |

## 3. Music plan

- **Keep the model** (D-125): one track per city, four stems on AudioStreamSynchronized, faded by the same phase as the beds. It works and is tested.
- **Tempo and key**: keep each city's measured tempo (64-68 bpm, near the theme's walking pace). Suggest one minor key family across cities, tritone accents per D-182, so title, globe bed and cities join cleanly. Unknown: the takes' keys are not recorded in provenance; measure them from the files before any new take.
- **Transitions**: title theme -> globe (2 s crossfade to low strings of the same theme) -> load (fade to silence, one low swell) -> city low stem on the first stomp -> stems by phase -> results (D-189 fade, low strings remain) -> back to the globe bed. Changes stay volume-only so stems never jump position; option: start a stem's fade on the next bar line so drums and brass land on a downbeat.
- **Ruin**: at phase 0.75+ the beds thin to fire and wind while the full stem fills, so ruin is music-led.
- **Out of the demo unless he says otherwise**: endless/Colossus track (D-189), wider-city pacing (D-366).

## 4. Sourcing options (nothing bought; every cost needs his written yes)

| Option | Licence | Cost | Covers |
|---|---|---|---|
| Kenney audio packs | CC0 | free | UI, impacts, sci-fi (already CLEARED) |
| Freesound, CC0 filter | CC0 (check each file) | free | crowds, sirens, rotors, servos, glass |
| Sonniss GDC bundles | royalty-free, commercial use (per bundle terms) | free | military, destruction, foley (D-030) |
| In-house synthesis (`tools/sfx/build_sfx.py`) | ours | free | thumps, hums, globe tones, stamps |
| ElevenLabs SFX on his plan | plan terms (commercial on paid tier) | existing credits; D-273 covers SFX credits on that subscription only | species roars and growls, mech hydraulics, screams |
| Suno Pro on his plan | Pro: commercial | existing credits; he generates (D-114) | globe bed, load swell, results sting, re-takes |
| Paid libraries (e.g. Boom Library, Soundly Pro, A Sound Effect bundles) | per-seat royalty-free | roughly $20-$400 per pack or a monthly plan (to confirm before any purchase) | heavy destruction, creature design |
| Composer commission | work for hire | quote needed | bespoke score |

## 5. Questions for the director

1. Should the globe have a quiet music bed (the theme stripped to low strings), or only a hologram hum with music off?
2. On city load, cut to silence and start the low strings on the first stomp, or keep the globe music running under the load?
3. Does each kaiju need its own roar (croc clicking growl, Komodo snort, serpent hiss), or one roar pitched per species for the demo?
4. Should collapses sound by size (shop, tower, landmark), with the landmark the loudest sound after the roar?
5. Should soldiers have wordless radio squelch and a scream on death, or stay silent under the gunfire?
6. Results screen: a stamp on each row and a brass hit on the total, or only the fading low strings?
7. Should drums and brass enter on the next bar line (cleaner, up to about 3.5 s late) or the moment the phase is reached (as now)?
8. Is the current city music the demo's music, or is this the "revisit music later" pass with new Suno takes?
9. For the gaps, may sessions use free CC0 sources and ElevenLabs credits under D-273, or do you approve each pack?
