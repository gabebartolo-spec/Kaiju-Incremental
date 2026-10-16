# Licensing register

Nothing enters `assets/` or `tools/` unless it is listed here as CLEARED (CLAUDE.md hard rule 5).

| Item | Path | Source | Licence | Status |
|---|---|---|---|---|
| Kaiju Rubble, Kaiju Claw, Kaiju Fault display fonts | `assets/fonts/kaiju_*.ttf` | Original glyphs drawn on a cell grid in `tools/fonts/glyphs.py`, built by `tools/fonts/build_fonts.py` (2026-10-16). Not traced from any typeface. | Ours (proprietary to Kaiju Incremental) | CLEARED |
| Font build tools | `tools/fonts/*.py` | Our code. Uses fontTools (MIT) and skia-pathops (BSD-3) at build time only; neither ships in the game or the fonts. | Ours; deps MIT / BSD-3 | CLEARED |
| Kaiju sculpts and skins (reptilian, insectoid, cephalopod; baby/adolescent/adult) | `assets/kaiju/*.kvox`, `*.rig.json` | Generated in Tripo Studio on the director's paid plan, every task set Private; task ids, prompts and credits per model in `docs/provenance/tripo.md`; voxelized and rigged by our `tools/blender/rig_voxel.py`. | Tripo paid-plan terms: the subscriber owns outputs and may use them commercially (free-plan CC BY does not apply). Re-check on any plan change. | CLEARED |
| Blender voxel/rig/inspection tools | `tools/blender/*.py` | Our code; runs inside Blender (GPL) as a separate tool, nothing from Blender ships in the game. | Ours | CLEARED |
