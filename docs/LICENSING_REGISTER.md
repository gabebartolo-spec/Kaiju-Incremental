# Licensing register

Nothing enters `assets/` or `tools/` unless it is listed here as CLEARED (CLAUDE.md hard rule 5).

| Item | Path | Source | Licence | Status |
|---|---|---|---|---|
| Kaiju Rubble, Kaiju Claw, Kaiju Fault display fonts | `assets/fonts/kaiju_*.ttf` | Original glyphs drawn on a cell grid in `tools/fonts/glyphs.py`, built by `tools/fonts/build_fonts.py` (2026-10-16). Not traced from any typeface. | Ours (proprietary to Kaiju Incremental) | CLEARED |
| Font build tools | `tools/fonts/*.py` | Our code. Uses fontTools (MIT) and skia-pathops (BSD-3) at build time only; neither ships in the game or the fonts. | Ours; deps MIT / BSD-3 | CLEARED |
| OpenStreetMap map data (Melbourne CBD district, later districts the same way) | `data/cities/*.json` (baked), raw cache `tools/osm/cache/` (gitignored, never shipped) | © OpenStreetMap contributors, fetched once per district from the Overpass API by `tools/osm/fetch_osm.py` (fair use: one bbox query, cached). Never Google Maps, Street View or traced photos: their terms forbid it. | ODbL 1.0 (opendatacommons.org/licenses/odbl/1-0/). Owed: (1) the credit line "Map data © OpenStreetMap contributors, ODbL" on a credits screen and in the store page / README; (2) share-alike: our baked `data/cities/*.json` is a Derivative Database, so on request we offer it (and the bake script) under ODbL; the game itself is a Produced Work and stays ours. | CLEARED |
| OSM bake tools | `tools/osm/*.py` | Our code, Python standard library only. Runs offline at dev time; nothing in the shipped game touches the network. | Ours | CLEARED |
