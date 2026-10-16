# Licensing register

Nothing enters `assets/` or `tools/` unless it is listed here as CLEARED (CLAUDE.md hard rule 5).

| Item | Path | Source | Licence | Status |
|---|---|---|---|---|
| Kaiju Rubble, Kaiju Claw, Kaiju Fault display fonts | `assets/fonts/kaiju_*.ttf` | Original glyphs drawn on a cell grid in `tools/fonts/glyphs.py`, built by `tools/fonts/build_fonts.py` (2026-10-16). Not traced from any typeface. | Ours (proprietary to Kaiju Incremental) | CLEARED |
| Font build tools | `tools/fonts/*.py` | Our code. Uses fontTools (MIT) and skia-pathops (BSD-3) at build time only; neither ships in the game or the fonts. | Ours; deps MIT / BSD-3 | CLEARED |
