# Handoff: tripo-komodo (Tripo asset session: Komodo young stages, new croc, serpent)

Updated 2026-10-24. Serves D-197 (reptilian family), D-204 (Tripo budget now 5000 in total; each new 3D model still
needs the director's pick), D-206 (serpent hybrid). Reports to the lead session (local_a16cd984-...). Branch
`claude/komodo-young-tripo` (from origin/claude/look-options); only docs/provenance/tripo.md and this file change.
Credits: 330 spent before 03:30 + 60 texture = about 390; balance about 16,515 (floor 15,905 in the original brief).
All pictures are free (GPT Image 2.5 quota ~295/1000).

## Queue and state
1. Komodo young (director: baby B four legs, adolescent "Yes, build it"): Smart Mesh x4 each (49992ded baby,
   60ab6cb9 adol), clay critic picked baby 43ccb5b7 and adol 08adb296, textured (30 each), GLBs in
   `~/cascadeur_bridge/komodo/young/glb/` (baby_43ccb5b7_tex.glb, adol_08adb296_tex.glb), textured six-views
   sixtex_*.png there. Textured critic: both FIX, no new Tripo run: baby neck ledge + foot smear (Blender), head ~20 deg
   lower (rig); adol hue to olive with a cream belly, darker back row (texture), hind feet ~40 deg inward (rig). Crops in
   young/critic/tex/. Next: boards to the lead; the lead decides who does the Blender/texture pass.
2. New croc "B with A's power" (director's pick): rounds M1 (f6465b38), M2 (6c4f0fce), M3 (40ade93f) all FIX. Each
   heavy-build reference brings back A's shoulder hump; words alone overcorrect the head down. M4 (2af90577): B's
   picture as the only reference, power in words. Critic next, then the picture to the lead before any credits.
3. Serpent: D-206 replaces the python-vs-cobra pick (baby spitting cobra, adolescent gains the rattle, adult python
   constrictor). Director to this session: "final stage is python body, venom spitting cobra head, viper rattle
   vibrating grabby tail". Adult hybrid concept: serpB2_3 (cobra head) + serpA5_0 (python body), generating. Python-only
   rounds A3-A6 stopped (free). Look-only critic next, then to the lead.

## Rulings and method
- Lead (D-188 method change): concept pictures are judged on look and read only; mesh items (toes, ear slit, claws,
  seams) are judged at the six-view gate; in critic briefs the approved adult wins over real photos.
- Director: 3D Enhance "i cant tell the difference" (unused); Smart UV / Upscale: try once on a picked model, ask first.
- Real photos (Komodo juveniles, snakes) are for critic use only (director's yes to the download); describe them in words
  for the generator.

## Know-how (proven)
- Upload: fetch the image as a blob in the page (Tripo history URL; older cards need real mouse scrolls to load), set it
  on `input[type=file]` with DataTransfer, dispatch change; two files give two references. Reload the page to clear
  references. Signed URLs need their query string (unsigned = 403); scratchpad dl.sh builds numbered sheets.
- A reference image carries its defects into every round (dots, grid pattern, hump): when a word fix fails twice,
  change or drop the reference.
- Generate panel: model list opens upward; aspect buttons need a real click (check `data-state`); prompt at screen
  (212,160) after scrollIntoView; Generate at (212,566). Check a new card appears; a click can silently miss.
- Texture: the Texture 30 button starts at once (no settings dialog). Export: JS click Export, then the last Export
  button, with `HTMLAnchorElement.prototype.click` replaced to capture the signed GLB URL (no download, no dialog); curl it
  before it expires (~6 min).
- Six-views: scratchpad six_all.sh (clay, `_six_`) and six_tex.sh (textured, `sixtex_`), Blender 5.2 headless.
- Multiview Image is free but its views disagree: not usable as Smart Mesh multi-view input.

## Next
Croc M4 critic and serpent hybrid critic, then one report to the lead (6 lines) with the Komodo boards, croc and serpent.
