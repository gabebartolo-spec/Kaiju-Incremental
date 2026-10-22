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

