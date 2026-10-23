# Handoff: tripo-komodo (Tripo asset session: Komodo young stages, new croc, serpent)

Updated 2026-10-24. Serves D-197 (reptilian family) and D-196 (Tripo budget 1000; 130 spent before this session, 0 since).
Reports to the lead session (local_a16cd984-...). Branch `claude/komodo-young-tripo` (from origin/claude/look-options);
only docs/provenance/tripo.md and this file change. Balance 16,775 (floor 15,905). All pictures so far are free
(GPT Image 2.5 quota ~265/1000).

## Queue (lead's order) and state
1. Komodo baby A/B + adolescent: DONE, board sent to the lead (`~/cascadeur_bridge/komodo/young/komodo_young_board.png`,
   files babyA_final.png, babyB_final3.png, adol_final.png; look-only critic SHIP). Waiting on the director's A/B pick
   via the lead; then Smart Mesh P2.0 x4 (100) + Texture (30) per model, six-view clay + textured, critic, GLB.
2. New croc A/B: DONE, board sent (`~/cascadeur_bridge/croc_new/croc_new_board.png`; croc_A_final = powerhouse level
   spine, croc_B_final = lean mid-stride sprinter). If B is picked, regenerate it both feet down before Smart Mesh.
3. Serpent A/B (python vs spitting cobra): round 2 (serpA2_*, serpB2_*) with a look-only critic now that real snake
   photos are in `~/cascadeur_bridge/serpent/photo_refs/` (director's yes). Board next.

## Rulings and method (this session)
- Lead 2026-10-24 (D-188 method change after 7 rounds): concept pictures are judged on LOOK AND READ only; mesh-level
  items (toe count, ear slit, claw length, small seams) move to the six-view gate after Smart Mesh; in critic briefs
  the approved adult wins over real photos.
- Director: 3D Enhance "i cant tell the difference" (unused); Smart UV / Upscale: try once on a picked model, ask first.
- Real reference photos: the critic refuses without one; the director said yes to Wikimedia downloads (Komodo juveniles,
  snakes), stored with SOURCES.txt, critic use only.

## Know-how (proven this session)
- Upload works in the built-in browser: fetch the image as a blob in the page (Tripo history URL or upload.wikimedia.org),
  set it on `input[type=file]` with DataTransfer, dispatch change; two files = two references.
- A real photo as the anatomy reference beat words: "baby/big eyes" wording made the generator cute.
- Edits output a square crop (cuts wide 4:3 subjects): for long creatures use the generate panel with the picture as reference.
- Generate panel: model list opens upward; aspect buttons need a real click (check `data-state`); JS calls time out at
  45 s, poll in <=35 s chunks. Download: read signed URLs from the page, curl them (scratchpad dl.sh builds a sheet).
- Multiview Image is free but its views disagree (tail/pose change): not usable as Smart Mesh multi-view input.

## Next
Serpent critic verdict -> board to the lead. Then wait for picks; the 3D step needs the director's pick per creature.
