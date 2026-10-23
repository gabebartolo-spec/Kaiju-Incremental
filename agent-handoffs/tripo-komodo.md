# Handoff: tripo-komodo (Tripo asset session, Komodo baby + adolescent)

Updated 2026-10-24. Serves D-197 (reptilian family; next step "Komodo baby and adolescent") and D-196 (Komodo, Tripo
budget 1000; 130 spent before this session). Reports to the lead session (local_a16cd984-...). Branch
`claude/komodo-young-tripo` (from origin/claude/look-options); only docs/provenance/tripo.md and this file change.

## Task
1. Free concept pictures (Tripo Image, GPT Image 2.5, 0 credits): BABY A upright (like the adult), BABY B a real
   four-legged hatchling, ADOLESCENT upright ("lanky, oversized feet, half-grown feature"). Rigging pose, plain grey.
2. Fresh realism critic per round until SHIP. 3. Labelled board to the LEAD (not the director), stop.
4. After the lead relays his baby pick: Smart Mesh P2.0 x4 (100) + Texture (30) per model, six-view, export GLB.
Balance floor 15,905 (was 16,775 at start; still 16,775: everything so far is free).

## State
- Files: `C:/Users/DANTE/cascadeur_bridge/komodo/young/` (babyA_r*, babyB_r*, adol_r* pngs + *_sheet.png; critic
  crops in critic/; real photos in photo_refs/ with SOURCES.txt, director's yes to download, critic use only).
- Rounds: r1 edits of the adult (all FIX/REJECT: edits keep the adult). r2 fresh gens with the adult as ref (cute faces,
  human torsos). r3+ use the real CC0 juvenile photo as the anatomy ref: big jump in realism. B r5 (photo only) is the
  best yet; A r3 #0 and adolescent r4 #1 are FIX with detail lists (see provenance rows). A r4 (from babyA_r3_0) was
  stuck in Tripo with no images at last look.
- Director (this session): 3D Enhance "i cant tell the difference" (not used); Smart UV / Upscale: try once on the picked
  baby model, ask him first.

## Know-how (new, proven this session)
- Local upload works in the built-in browser: fetch the image as a blob in the page (Tripo history URL or
  upload.wikimedia.org, CORS ok), put it in `input[type=file]` with DataTransfer, dispatch change. Two files = two refs.
- Real-photo reference fixes the generator's cute/humanoid drift far better than words ("baby", "big eyes" make it cute).
- Edit dialog: model list opens at x~254; Edit button is clipped, JS `.click()` on it works. Generate panel: model list
  opens upward (scroll the button low first); aspect buttons need a real click, check `data-state`.
- JS calls time out at 45 s: poll in <=35 s chunks. Signed URLs expire in ~1 h.

## Next
Critic on B r5; fix A (consider: stand the B r5 winner upright) and adolescent (tail clear of far thigh, adult-like
hooded eye and straight mouth, no hip ring); board to the lead when all three SHIP.
