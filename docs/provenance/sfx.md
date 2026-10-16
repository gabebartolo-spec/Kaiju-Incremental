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
| stomp_0/1/2.ogg | synth sub thump (falling sine + click) + Kenney `impactPunch_heavy_000/001/002` pitched 0.6 + synth low rumble |
| stomp_crack.ogg | Kenney `explosionCrunch_001` pitched 0.7 + synth crackle |
| breath.ogg | synth rising hum (0-0.45 s) + synth roar (swept band-passed noise + 55 Hz buzz) + Kenney `thrusterFire_000` pitched 0.7 + synth sizzle (hiss + crackle) |
| leap_whoosh.ogg | synth swept whoosh + Kenney `impactPlate_light_001` pitched 1.3 (chitin clack) |
| leap_land.ogg | Kenney `lowFrequency_explosion_000` + `explosionCrunch_002` pitched 0.8 + synth sub thump + synth crackle |
| lash.ogg | synth swoosh + synth whip crack + Kenney `slime_000` + `slime_001` pitched 0.8 |
| ready.ogg | synth growl (formant-filtered buzz) + synth chime |
| deflect.ogg | Kenney `impactMetal_heavy_001` + `impactBell_heavy_002` pitched 1.2 |
| regen_loop.ogg | synth bubbles (seamless 2 s loop) |
