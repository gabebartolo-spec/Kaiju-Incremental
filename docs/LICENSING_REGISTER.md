# Licensing register

Nothing enters `assets/` or `tools/` unless it is listed here as CLEARED (CLAUDE.md hard rule 5).

| Item | Path | Source | Licence | Status |
|---|---|---|---|---|
| Kaiju Rubble, Kaiju Claw, Kaiju Fault display fonts | `assets/fonts/kaiju_*.ttf` | Original glyphs drawn on a cell grid in `tools/fonts/glyphs.py`, built by `tools/fonts/build_fonts.py` (2026-10-16). Not traced from any typeface. | Ours (proprietary to Kaiju Incremental) | CLEARED |
| Font build tools | `tools/fonts/*.py` | Our code. Uses fontTools (MIT) and skia-pathops (BSD-3) at build time only; neither ships in the game or the fonts. | Ours; deps MIT / BSD-3 | CLEARED |
| Kenney Impact Sounds 1.0, Kenney Sci-fi Sounds 1.0 (layers in the power sounds) | `assets/sfx/*.ogg` (mixed in) | kenney.nl/assets/impact-sounds, kenney.nl/assets/sci-fi-sounds; per-file list in `docs/provenance/sfx.md`. Raw packs kept outside the repo (D-030). | CC0 1.0 (License.txt in each pack) | CLEARED |
| Power sounds (synthesized layers and the mixes) | `assets/sfx/*.ogg` | Built by `tools/sfx/build_sfx.py` (2026-10-16) | Ours | CLEARED |
| Sound build tool | `tools/sfx/build_sfx.py` | Our code. Uses numpy (BSD-3) and imageio-ffmpeg's ffmpeg at build time only; neither ships in the game. | Ours; deps BSD-3 / LGPL (build-time) | CLEARED |
