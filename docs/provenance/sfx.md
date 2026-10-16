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
| breath.ogg | synth rising hum (0-0.45 s) + synth roar (swept band-passed noise + 55 Hz buzz) + Kenney `thrusterFire_000` pitched 0.7 + synth sizzle (hiss + crackle) |
| leap_whoosh.ogg | synth swept whoosh + Kenney `impactPlate_light_001` pitched 1.3 (chitin clack) |
| leap_land.ogg | Kenney `lowFrequency_explosion_000` + `explosionCrunch_002` pitched 0.8 + synth sub thump + synth crackle |
| lash.ogg | synth swoosh + synth whip crack + Kenney `slime_000` + `slime_001` pitched 0.8 |
| ready.ogg | synth growl (formant-filtered buzz) + synth chime |
| deflect.ogg | Kenney `impactMetal_heavy_001` + `impactBell_heavy_002` pitched 1.2 |
| regen_loop.ogg | synth bubbles (seamless 2 s loop) |
