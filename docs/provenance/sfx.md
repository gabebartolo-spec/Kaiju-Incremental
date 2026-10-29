# Sound provenance

Cap: 200 lines. One row per shipped file in `assets/sfx/`: its layers, where each layer
came from, and that source's licence. All files are built by `tools/sfx/build_sfx.py`
(seeded, so a rebuild matches). Raw packs stay outside the repo (D-030).

Sources:
- **Kenney Impact Sounds 1.0** (kenney.nl/assets/impact-sounds, created 19-12-2019): CC0 1.0.
- **Kenney Sci-fi Sounds 1.0** (kenney.nl/assets/sci-fi-sounds): CC0 1.0.
- **In-house synthesis**: `tools/sfx/build_sfx.py` (numpy). Ours.

| File | Layers (source file, treatment) |
|---|---|
| stomp_0/1/2.ogg (light, heavy, titan) | synth sub thump (sine, fast pitch drop to 40/37/34 Hz) + Kenney `impactSoft_heavy_000/001/002` pitched down and low-passed at 2.5 kHz + synth 150 Hz knock + synth rumble tail (low-passed brown noise); tiers 1-2 add a quiet late debris settle (low-passed at 2.5 kHz). High-passed at 28 Hz. Reworked 2026-10-16 after the director: "crinkly like they're walking on cellophane". |
| footstep.ogg (every foot plant; pitched by size tier in game) | synth sub thump (62 to 38 Hz) + Kenney `impactSoft_heavy_003` pitched 0.6, low-passed at 1.8 kHz + a quiet synth grit crackle (low-passed at 2.2 kHz). High-passed at 28 Hz. Added 2026-10-18 (D-050). |
| footstep_1/2/3.ogg (step variants, taken in turn with footstep.ogg) | as footstep.ogg, with Kenney `impactSoft_heavy_000` / `_001` / `_004` pitched 0.59 / 0.63 / 0.67 and low-passed at 1.8 kHz, synth sub thumps 60-36, 65-40 and 58-37 Hz, and different grit. High-passed at 28 Hz. Added 2026-10-18 (D-050). |
| stomp_crack.ogg (heavy stomps that crack the street) | Kenney `impactMining_000/001/002` pitched 0.5/0.45/0.4, low-passed at 3.5 kHz, staggered + synth rock grind (band-passed noise sweeping 420 to 160 Hz) + synth grit trickle (low-passed crackle). High-passed at 40 Hz. Added 2026-10-18 (D-050). |
| collapse.ogg (a building part lands) | Kenney `explosionCrunch_000` pitched 0.6 + `lowFrequency_explosion_001` + synth sub thump + Kenney `impactGlass_heavy_000/001/002` pitched 0.85, low-passed at 6 kHz (windows) + synth rumble (low-passed brown noise) + synth debris rain (low-passed crackle) + Kenney `impactMining_001/002/003` pitched 0.45, low-passed at 2.5 kHz (falling chunks). High-passed at 30 Hz. Added 2026-10-18 (D-050). |
| roar.ogg (croc titan roar: demo end card, evolution reveal) | synth band-passed inhale (0-0.34 s), then from 0.32 s a 1.7 s synth bellow timed to the biped head's lunge. The bellow is a 38-52 Hz buzz with 28 harmonics and a half-rate rasp, through throat formants at 280, 650 and 1300-950 Hz, plus a breath hiss. Under it: Kenney `lowFrequency_explosion_000` pitched 0.5 and low-passed at 400 Hz, and a synth sub thump. Then a 2.5 s synth echo tail (convolved with dark decaying noise). High-passed at 28 Hz; 99% of the energy is below 500 Hz. Added 2026-10-18 (D-050). |
| ui_click.ogg, ui_confirm.ogg, ui_deny.ogg (menus: every button; buying an upgrade; can't buy) | synth only: band-passed noise tick + 420 Hz body; two-note chime (C5 then G5) over a synth sub thump; a 110 Hz buzz, low-passed at 1.5 kHz. Added 2026-10-18 (D-050). |
| tree_buy.ogg, tree_maxed.ogg, tree_ring_open.ogg, tree_evolve.ogg (evolution tree, D-396: a node bought; a node maxed; a ring opening; an evolution) | synth only: glass tick (band-passed noise at 3.4 kHz) + liquid gurgle (noise band-passed on a 9 Hz wobble) + a 180-420 Hz rising tone; the same under a three-note chime (E5 G#5 B5); a struck glass dish (decaying partials 523-3170 Hz) over a pressure hiss and a 70-45 Hz thump; an electric snap (4.2 kHz) over a 120-38 Hz sub boom with arcing crackle. Added 2026-10-30. |
| tank_fire.ogg (a tank's cannon) | synth muzzle crack (band-passed noise) + Kenney `explosionCrunch_001` pitched 0.75 + `lowFrequency_explosion_001` + synth thump + synth echo tail. Added 2026-10-18 (D-050). |
| shell_hit.ogg (a shell hits the unarmoured kaiju) | Kenney `impactPunch_heavy_001` pitched 0.7 + `impactMetal_light_002` pitched 0.8 + synth thump + synth grit crackle. Added 2026-10-18 (D-050). |
| heli_rotor.ogg (seamless 2 s loop) | synth only: 19 Hz main-blade slap (pulsed low-passed noise), 76 Hz tail-rotor buzz (band-passed noise), turbine whine (2.4/3.6 kHz sines), 57 Hz hum; the 0.5 s overrun is crossfaded into the start. Added 2026-10-18 (D-050). |
| heli_gun.ogg (a helicopter's chin-gun burst) | synth only: five rounds at 11 a second, each a band-passed noise crack over a low-passed thud, plus a synth echo tail. Added 2026-10-18 (D-050). |
| heli_crash.ogg (a helicopter shot down) | synth falling turbine whine + Kenney `lowFrequency_explosion_000` + `explosionCrunch_003` pitched 0.85 + synth thump + Kenney `impactMetal_heavy_000..003` pitched 0.75-0.9 (metal raining down). Added 2026-10-18 (D-050). |
| crowd_panic.ogg (seamless 6 s loop; faded by fleeing civilians and the destruction rate) | synth only: 14 murmuring voices (formant-filtered noise with a syllable rhythm), 9 screams and shouts (wavering harmonic glides through a mouth formant), running-feet crackle, low-passed at 3.5 kHz with a synth echo off the buildings, high-passed at 300 Hz so it stays clear of the stomps; the 1 s overrun is crossfaded into the start. Added 2026-10-18 (D-050). |
| rifle.ogg (a rooftop squad's volley) | synth only: five band-passed noise cracks (2.8-3.8 kHz) with 380 Hz bodies, scattered over 0.22 s, plus a short synth slapback tail. Added 2026-10-18 (D-063). |
| breath.ogg | synth rising hum (0-0.45 s) + synth roar (swept band-passed noise + 55 Hz buzz) + Kenney `thrusterFire_000` pitched 0.7 + synth sizzle (hiss + crackle) |
| leap_whoosh.ogg | synth swept whoosh + Kenney `impactPlate_light_001` pitched 1.3 (chitin clack) |
| leap_land.ogg | Kenney `lowFrequency_explosion_000` + `explosionCrunch_002` pitched 0.8 + synth sub thump + synth crackle |
| lash.ogg | synth swoosh + synth whip crack + Kenney `slime_000` + `slime_001` pitched 0.8 |
| ready.ogg | synth growl (formant-filtered buzz) + synth chime |
| deflect.ogg | Kenney `impactMetal_heavy_001` + `impactBell_heavy_002` pitched 1.2 |
| regen_loop.ogg | synth bubbles (seamless 2 s loop) |
| blast_crack.ogg (a red barrel's first instant, near the camera only) | synth high-passed noise snap + Kenney `explosionCrunch_004` pitched 1.15, high-passed at 400 Hz + synth band-passed noise sweep 3.2-0.9 kHz. High-passed at 150 Hz. Added 2026-10-21 (comments #19, #20); a stand-in until an ElevenLabs take (wanted list in the PR). |
| blast_body.ogg (the blast itself) | Kenney `explosionCrunch_000` pitched 0.5 + `explosionCrunch_002` pitched 0.62 + `lowFrequency_explosion_000` pitched 0.7 + synth sub thump (62 to 30 Hz) + synth fire whoosh (low-passed noise) + synth crackle + Kenney `impactMining_002..004` pitched 0.55 (debris, high-passed at 300 Hz). High-passed at 28 Hz. Added 2026-10-21. |
| blast_rumble.ogg (the tail) | synth brown-noise rumble low-passed at 320 Hz with a slow swell + Kenney `lowFrequency_explosion_001` pitched 0.6, low-passed at 900 Hz + synth echo. High-passed at 25 Hz. Added 2026-10-21. |
| sonic_boom.ogg (played late by distance, BlastFx) | two synth thumps 0.11 s apart (75 to 32 Hz and 170 to 85 Hz each, the N-wave's double shock) + low-passed noise clicks + synth echo. High-passed at 28 Hz. Added 2026-10-21. |
| fireworks_crackle.ogg (each fireworks burst) | 14 seeded synth pops (300 to 120 Hz thumps with noise clicks) + synth crackle low-passed at 5 kHz + two synth rising whistles (1.4 to 2.6 kHz). High-passed at 80 Hz. Added 2026-10-21. |
| chem_hiss.ogg (a fuse burning, a chem lab's cloud) | synth band-passed noise hiss (3.4 kHz) + Kenney `impactMetal_heavy_002/003` pitched 0.45, low-passed at 2.5 kHz (metal creak). High-passed at 60 Hz. Added 2026-10-21. |

## ElevenLabs replacements (2026-10-19, D-092; picked by the director from a loudness-matched shootout)

Generated in ElevenLabs Sound Effects (Starter plan, prompt influence 60%, fixed duration, loop where noted; 4 takes per
generation, 532 credits for all 13 generations). Each pick was converted to mono 44.1 kHz Vorbis 96 kb/s, its gain set so
its loud-part RMS matches the sound it replaces (within 0.5 dB, so the mix in `data/tuning.json` holds), peak-limited.
They replace the synth/Kenney mixes listed above for these files; shell_hit.ogg keeps the old mix (the director's pick).

| File | Take | Prompt (ElevenLabs) |
|---|---|---|
| roar.ogg | roar t2, 4.0 s | High-quality, professionally recorded giant reptile monster roar, one-shot. Deep guttural bellow rising into a ragged, rasping scream, enormous creature, slight outdoor reverb. Cinematic creature sound effect, no music, no voices. |
| breath.ogg | breath t1, 3.0 s | High-quality cinematic energy breath weapon, one-shot. A giant monster's searing atomic beam: hissing plasma roar with crackling fire, sustained and powerful. Sound effects foley, no music, no voices. |
| stomp_0.ogg | stomp_small t1, 1.5 s | High-quality, professionally recorded heavy creature footstep on asphalt, one-shot impact. Deep thud with a short crunch of cracking pavement. Sound effects foley, no music. |
| stomp_1.ogg | stomp_mid t2, 2.0 s | High-quality, professionally recorded giant monster footstep impact on a city street, one-shot. Very deep ground-shaking thud, cracking concrete and a short low rumble tail. Sound effects foley, no music. |
| stomp_2.ogg | stomp_heavy t2, 2.5 s | High-quality cinematic colossal monster footstep, one-shot impact. Earth-shaking sub-bass boom, shattering concrete, debris rattle and a rolling low rumble tail. Sound effects, no music. |
| collapse.ogg | collapse t2, 4.0 s | High-quality, professionally recorded concrete building collapse, one-shot. Crumbling walls, heavy rubble cascade, breaking glass and a deep dusty rumble. Sound effects foley, no music, no voices. |
| rifle.ogg | rifle_near t2, 1.0 s (raised 24 dB; the take was quiet) | High-quality, professionally recorded single rifle shot outdoors in a city, one-shot. Sharp supersonic crack with a short slap echo off buildings. Sound effects foley, no music. Its onset is at 2 ms, so `sfx.start_s` for rifle and rifle_far is now 0.0 (was 0.13 for the old sample's silent lead-in). |
| tank_fire.ogg | tank_fire t2, 2.5 s | High-quality, professionally recorded tank main gun firing outdoors, one-shot. Massive cannon boom with a pressure-wave thump and a rolling echo between buildings. Sound effects, no music. |
| heli_rotor.ogg | heli_rotor t1, 5.0 s loop | High-quality, professionally recorded military attack helicopter hovering nearby, steady rotor blade thump and turbine whine, loop. Sound effects, no music. |
| crowd_panic.ogg | crowd_panic t1, 6.0 s loop | High-quality recording of a large stadium crowd panicking, thousands of people screaming and running, chaotic, loop. Sound effects ambience, no music. |
| footstep.ogg, footstep_1..3.ogg | footstep_small t1, 1.0 s; the variants are the same take at pitch 0.96 / 1.04 / 0.92 | High-quality, professionally recorded small reptile creature footstep on concrete, one-shot. Soft heavy pad thud with a light scrape. Sound effects foley, no music. |
| thunder_beam.ogg (one-shot on the Thunder Beam's start) | start_b, 4.48 s, -6.9 dB, 0.3 s fade-out; picked for the loudest crack and longest bright crackle | High-quality cinematic sound effect of a colossal lightning beam fired from a giant monster's mouth, one-shot, 4.5 seconds. Starts with a sharp, deafening thunder crack, then a sustained roaring torrent of crackling electricity and searing plasma hum with buzzing arcs, ending in a deep rolling thunder rumble that fades out. Huge, powerful, godlike. Sound effects only, no music, no voices. |
| thunder_beam_loop.ogg (looped while the beam is on) | loop_a, 3.00 s seamless, -7.3 dB; the steadiest (rms spread 0.8 dB, 0.3 dB step at the seam) | Seamless loop of a sustained colossal lightning beam: a roaring torrent of crackling high-voltage electricity, searing plasma hum, constant buzzing arcs and sizzling sparks, steady intensity, no start and no end. Huge and powerful. Sound effects only, no music, no voices. |
| thunder_beam_end.ogg (one-shot on the beam's end) | end_b, 3.48 s, -5.0 dB, 0.2 s fade-out; the cleanest decay (-2 to -49 dB) | One-shot ending of a colossal lightning beam: the electric crackle cuts off with a final sharp thunder crack, followed by a deep rolling thunder rumble that echoes across a city and fades out slowly. Sound effects only, no music, no voices. |

The three thunder_beam files (lead, 2026-10-23, ElevenLabs flow Pmr8C0DI22Q6LD0EIoh0, model eleven_text_to_sound_v2, prompt
influence 0.5, 4 takes each, 175 credits on the director's paid plan, D-138): mono 44.1 kHz Vorbis 96 kb/s, peak-limited
below 0 dBFS. Raw takes kept outside the repo.

Not usable: the distant-rifle prompt (and one near-rifle take) came back near-silent (peak about -45 dBFS); rifle_far keeps
playing the rifle sample pitched 0.7, as before.

| siren_far.ogg | siren_far take A, 20.0 s seamless loop (mp3 converted to ogg vorbis, 44.1 kHz stereo) | ElevenLabs Sound Effects v2 (eleven_text_to_sound_v2), 2026-10-22, flow 2dN0E00nqUIe779VfJXy, D-138. Prompt: distant city emergency sirens wailing, several, far away, echoing between buildings, no voices, loopable. Used only by the title screen ambience (TitleAmbience), at -34 dB. |

## City beds (2026-10-23, D-155, D-138)

Four loops for CitySound, generated in ElevenLabs Sound Effects on the director's paid plan (model eleven_text_to_sound_v2, prompt influence 0.5, loop on, fixed duration; flow oRbWcPVQmGlj1NYUxCJI; 2 takes each, 8 generations, 333.3 credits; D-092, D-138). Each pick was converted to mono 44.1 kHz Vorbis 96 kb/s, gain set so the whole-loop RMS hits the target (siren -24, gunfire -33, fire -24, wind -26 dBFS; measured within 0.1 dB) with the peak at or under -1.5 dBFS (gunfire -2.0 dBFS: sparse, crest 31 dB), no fades. Gains: siren -17.87 dB, gunfire +20.61, fire +0.48, wind +1.74. Raw takes stay outside the repo.

| File | Take | Prompt (ElevenLabs) |
|---|---|---|
| city_siren.ogg | siren a, 16 s loop (generation NhcfJy7PGeLP2pdYiifG) | High-quality, professionally recorded emergency sirens heard from several blocks away across a large city at night: two police and ambulance sirens wailing at different pitches, overlapping, echoing off tall buildings, distant and dark. No voices, no traffic, no music. Sound effects ambience, loop. |
| city_gunfire.ogg | gunfire b, 12 s loop (generation xQMpCIcETnas6ZopXczI) | High-quality, professionally recorded distant gunfire across a city: sparse muffled rifle pops and a few short bursts, long gaps between them, echoing between tall buildings from far away, dull and low. No voices, no explosions, no music. Sound effects ambience, loop. |
| city_fire.ogg | fire b, 10 s loop (generation vsoyqeoWjCpBW6Gbdo4O) | High-quality, professionally recorded large fires burning across a city seen from far off: a deep low roar of wind-fed flames with steady crackling and snapping, no single loud event. No voices, no music. Sound effects ambience, loop. |
| city_wind.ogg | wind b, 12 s loop (generation OWsFcg8wbCa439qtLFkq) | High-quality, professionally recorded cold wind gusting through empty city streets and between skyscrapers: low moaning with faint whistling through broken windows, eerie and desolate, slow swells. No voices, no traffic, no birds, no music. Sound effects ambience, loop. |
| train_horn.ogg | horn take 1, 2.5 s (eleven_text_to_sound_v3, 2026-10-25, 4 takes per generation, no generation id shown; opus converted to vorbis 44.1 kHz stereo) | A loud metro train horn blaring, two-tone warning blast, close. |
| train_screech.ogg | screech take 1, 3.0 s (v3, 2026-10-25, no generation id shown) | Train wheels screeching on steel rails under emergency braking and derailment, harsh metallic squeal. |
| train_crash.ogg | crash take 1, 4.0 s (v3, 2026-10-25, no generation id shown) | A heavy metro train car crashing off a viaduct onto a street: massive metal impact, crunching steel, shattering glass, debris. |
| station_bell.ogg | bell take 1, 2.0 s (v3, 2026-10-25, no generation id shown) | Metro station platform chime, two clear electronic tones, departure announcement chime. |
| train_rumble.ogg | rumble d, 11.4 s seamless loop (generation w79xT96kyuHlnYVeNQQa; 4 takes, v3, influence 0.5, loop on, 12 s, 2026-10-25, D-247) | Seamless steady loop: an elevated metro train running at constant speed over a steel viaduct, heard from the street below. Rhythmic wheel clatter over rail joints, a low steel-deck drone and rumble, a faint electric traction motor whine. Constant level, no horn, no brakes, no announcements, no voices, no music, no start or end. |
| train_slide.ogg | slide a, 7.4 s seamless loop (generation 9oz5917feH9iguQfu7EG; 4 takes, v3, influence 0.5, loop on, 8 s, 2026-10-25, D-247) | Seamless continuous loop: a derailed metro train carriage grinding and dragging along a steel bridge deck on its side. Harsh sustained scraping and screeching of steel on steel, a hissing shower of sparks, heavy metallic groans, an occasional dull bang and clank of debris. Constant intensity throughout, no explosion, no horn, no voices, no music, no start or end. |

Train loops (023): 8 takes (4 per sound) from two generations; picks by measurement (steadiest level, no one-off event that would repeat audibly, balanced spectrum). Processing (`process_loops.py`, outside the repo): the last 0.6 s is crossfaded (equal power) into the start so the wrap continues the material (12 s -> 11.4 s, 8 s -> 7.4 s), mono 44.1 kHz, gain so the loud-part RMS is -26 dB (rumble, like city_wind) and -21 dB (slide, under the horn -12 and screech -14), 5 ms / 80 ms limiter at -1.5 dBFS, Vorbis 96 kb/s. Seam check: three loops back to back, both joins scored against 200 interior points of the same file (level, spectrum, sample step). Raw takes stay outside the repo.

## Kaiju Creation lab sounds (2026-10-25, D-138; director's 10-sound list, cap 500 credits)

Generated in ElevenLabs Sound Effects on the director's paid Starter plan (model eleven_text_to_sound_v3, prompt
influence 0.5, fixed duration; the room tone with the web defaults: influence 0.3, auto duration, 4 takes). 2 takes
per sound, 22 generations, 235 credits. Provisional picks from measurements (loudness, silence share, spectrum),
for the director to change on `C:\Users\DANTE\Documents\KAIJU\sfx_shootout\index.html`. Processing
(`process.py`, outside the repo): mono 44.1 kHz, gain so the loud-part RMS hits the target, a smooth 5 ms / 80 ms
peak limiter at -1.5 dBFS, Vorbis 96 kb/s. Loops are cut to length and their 0.5 s overrun is crossfaded into the
start; one-shots get a 30 ms tail fade. Raw takes stay outside the repo.

| File | Prompt (shortened) | Take ids (pick first) | Length | Loud RMS |
|---|---|---|---|---|
| lab_room.ogg (loop) | clean sterile lab room tone: HVAC hum, freezer compressor drone, faint monitor beeps | jN2exUvfby9C1kYyX76D (of 4) | 12 s | -34 dB |
| lab_screens.ogg (loop) | soft data chirps and blips, quiet heartbeat-monitor pulse | hfuxyK9ZyP7MZBl1Rz2J / vQVUW8yQVtxrT6uaUCNs | 6 s | -30 dB |
| lab_latch.ogg | servo whir, crisp latch, vial slides up out of a metal rack | YJQ3JAYR5LQOagjXJkrT / wUZZTjAWtjyS2QEFPa9P | 1.6 s | -22 dB |
| lab_arm.ogg | precision robotic arm servo whine swinging and lowering, soft pneumatic hiss | SHzmxkjpXkzJvGxOTjIi / F3E3nQYJxji2roptnGsk | 2.5 s | -22 dB |
| lab_drawup.ogg | syringe injector draws liquid up: plunger servo, wet suction gurgle | blBMpHuvR6tvs09TeMGS / nB218sohH1JnNBTA6omd | 2 s | -22 dB |
| lab_dispense.ogg | injector dispenses thick liquid into a glass dish: pneumatic push, viscous drips | 2uYW2EZTCi5PsmJHNzz6 / M1Fe2ABElkDTuDq7Giyd | 2 s | -22 dB |
| lab_strike.ogg | needle clicks into glass, one bright violent electric snap | jbSfWVpLGJ1kMtuzEq00 / shS224HZMB0jjxDJgIR4 | 1 s | -17 dB |
| lab_crackle.ogg (loop) | white-hot electrical arcing, branching lightning, tesla discharge | 4lkP6CQfG76unnvYIPyH / a4EEVE6JkM5qZfm1FKSO | 4 s | -21 dB |
| lab_overload.ogg | power surge whining up to a deep electric bang with sub boom | YFnC1raLNpKHMbbmrBO5 / xgfok9ECRxnwODBCMFyt | 2.5 s | -15 dB |
| lab_dive.ogg | fast rising cinematic whoosh, abrupt end | 3ar6lZF5csJz8xj8cbY4 / DHqvghaVznmDWdjVwTOC | 1.5 s | -18 dB |
| egg_crack.ogg | reptile eggshell cracking in a dark silent space, wet split | dzPIKVrsf1UuA4XhFoqT / fBEUQq7cS0sNhNzPF7db | 2 s | -20 dB |

(History lists a sound's two takes without saying which one became "a", so both ids are given per file.)
