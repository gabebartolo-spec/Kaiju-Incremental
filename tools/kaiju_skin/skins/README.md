# Croc skins as colour tables (D-164): Obsidian, Abyssal, Albino

Proposal and proof only: nothing here is wired into the game. 0 credits (not a Tripo re-texture).

## How the croc is coloured today
The rigged croc (`assets/kaiju/reptilian_adult.kvox`, baked to `.vskin`) is voxel cubes, each with one baked rgb
(the Tripo sculpt's texture sampled when it was voxelised) and a bone index. The species `colors` in
`data/species.json` only tint the effects and the glow; the hide colours live in the cells. So a skin is a
recolour of the cells, never a texture swap.

## The table (one small PNG per skin, Aseprite-editable)
`palettes/<skin>.png` is 4 x 6 pixels, one pixel per swatch (zoom in Aseprite):

| row | region | what it covers |
|---|---|---|
| 0 | back | the olive hide: back, flanks, limbs, head top, tail sides |
| 1 | belly | the pale cream hide: chest, belly, throat, under the tail |
| 2 | spines | the near-black plates along the back, neck and tail |
| 3 | claws | the dark toes and finger claws |
| 4 | eyes | the amber eye patch |
| 5 | teeth | the bright cells inside the mouth |

Columns: 0 shadow, 1 mid, 2 light, 3 glow. A cell keeps its own light and dark (its original luminance, ranked
inside its region, 5th to 95th percentile) and takes its colour along shadow, mid, light, so the scales and bands
survive. Column 3 is for **emissive cells** (the game already has them: a palette colour with alpha 0): which
cells glow is the skin's `<skin>.json` (`glow`: `crevice` = the darkest share of each region, `spots` =
scale-sized clusters on the flanks, `null`; `glow_share`; `glow_regions`).

## How the croc maps onto the table (`regions.py`, run on the .kvox cells)
Cues: bone, original colour, outward normal (up = dorsal, down = ventral).
- belly: lum > 0.38, saturation < 0.5, normal not up, not a limb end
- spines: lum < 0.22, saturation < 0.32, on spine/neck/tail bones, normal up
- claws: lum < 0.2, saturation < 0.55, on arm_?2 / leg_?2
- teeth: lum > 0.68, saturation < 0.45, inside the mouth (upper: normal down on head1; lower: normal up on jaw)
- eyes: saturated amber (r>g>b, b<0.2, sat>0.75) on head0/head1/jaw above y=270
- back: everything else
Counts on the adult: back 268,402; belly 58,495; spines 29,668; claws 10,430; teeth 626; eyes 112 of 367,733.

## Honest limits (questions for the lead)
- Eyes (112 cells) and teeth (626) are tiny: the sculpt has no separate tooth cells and a shut mouth, so the
  Albino pink-red eyes show only as a few cells at game distance. The glowing eye that matters at range is the
  species `eye` colour (breath, effects): a skin should set that too. Decision for the director: should a skin also
  recolour the breath/eye glow? (not assumed)
- The mouth's pink inside is split at run time by BipedHead (MOUTH_RED); recolouring must leave it, so the mapper
  must keep cells with red over 1.35x green or blue. Not implemented here; the boards use the shut mouth, where
  the sculpt has almost no such cells.
- Albino at the game's lighting reads pale cream; a true white would clip.

## Run
    python tools/kaiju_skin/skins/skin_tool.py palettes            # rewrite palettes/*.png from the table in the script
    python tools/kaiju_skin/skins/skin_tool.py board OUT.png        # today + the three skins, behind 3/4, front 3/4, 2x head
Needs numpy and Pillow only (no Godot).
