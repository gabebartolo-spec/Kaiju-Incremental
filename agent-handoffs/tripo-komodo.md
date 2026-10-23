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
2. Croc, 3 stages (croc share up to 600 credits of D-204's 5000). Generation rounds M1-M4 all failed (a heavy reference
   brings back the hump; "feet side by side" forces a standing T-rex). Method that works: Tripo Edit Image on B itself
   (keeps its line). Adult E1 -> E2 -> E3 (croc_new/crocE3.png, 5377566d): critic FIX only on two pose items (hips not
   over the front foot, near elbow overlapping the belly line); asked the lead whether they move to the rig gate. If yes:
   Smart Mesh x4 -> six views -> Texture (Remove Lighting on) -> croc_new/models/adult/. Baby: crocBabyE3.png
   (e2e51cc9), teen: crocTeenE1.png (3d3dadc7), both edits of the adult chain; critics running. The Edit dialog's
   "current image" is the newest edit in that card's chain: select the right one in History before editing.
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
Critics for croc baby E3 and teen E1 (croc_new/critic/baby_e3, teen_e1). Waiting on the lead about the adult pose items.
Balance 16,385 (the serpent session spends from the same account).

## Next
On the lead's yes and critic SHIPs: Smart Mesh each stage, six views, texture, GLB, report each GLB to the lead.
