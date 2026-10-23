# Handoff: tripo-komodo (Tripo asset session: Komodo young stages, new croc, serpent)

Updated 2026-10-24. Serves D-197 (reptilian family), D-204 (Tripo budget now 5000 in total; each new 3D model still
needs the director's pick), D-206 (serpent hybrid). Reports to the lead session (local_a16cd984-...). Branch
`claude/komodo-young-tripo` (from origin/claude/look-options); only docs/provenance/tripo.md and this file change.
Credits: 330 spent before 03:30 + 60 texture = about 390; balance about 16,515 (floor 15,905 in the original brief).
All pictures are free (GPT Image 2.5 quota ~295/1000).

## Queue and state (lead's D-209: "Straight to 3D" once a concept passes its critic; 2 generations at once account-wide)
1. Komodo young: DONE. GLBs reported to the lead: young/glb/baby_43ccb5b7_tex.glb, young/glb/adol_08adb296_tex.glb,
   adult komodo/mesh/komodo_tex_6a8a224e.glb; board young/komodo_young_3d_board.png. Textured critic FIX, touch-ups only
   (Blender/rig, the lead's call). Remove Lighting was not on for these two (Texture has no settings dialog).
2. Croc, 3 stages (croc share up to 600 credits of D-204's 5000): the adult is "B with A's power". M1-M3 FIX; M4
   (5e94ef8d, croc_new/crocM4_*, B as the only reference) is with its critic. On SHIP: Smart Mesh P2.0 x4 -> six views ->
   Texture with Remove Lighting on -> GLB in croc_new/models/adult/. Then a baby and a teen of the same animal (bigger head
   and eyes, shorter snout, lighter build), same pipeline into models/baby and models/teen. Report each GLB to the lead.
3. Serpent: handed to the tripo-serpent session (local_cebec3c3-...) with the latest adult serpH1_1 (FIX, rattle only).
   Do no serpent work here. Komodo palettes dropped (the lead does skins in Blender).

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

## Running jobs
Croc M4 realism critic (results in croc_new/critic/m4/). My browser tabs: "seed" (image page), "tab-1" (model page).

## Next
Croc M4 verdict -> adult 3D or one more round; then baby and teen.
