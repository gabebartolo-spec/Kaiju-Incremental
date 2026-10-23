# Heads: PARKED (D-171, post-demo). Branch claude/heads-skins. Credits used: 580 of 6,500.

## What each round tried and why it failed
- Round 1 (earlier session): Python A/B, Komodo A/B/C as whole-creature Tripo regenerations. Komodo C (own shape) won.
- Round 2 (A viper, B cobra, 260 cr): GPT Image 2.5 edit of the croc ref, Smart Mesh + texture. B had a drip shard,
  lip teeth, a thick cape hood, scab blotches; A read as a croc-skull viper with tusk fangs. Critic: A FIX, B FIX.
- Round 3 (260 cr): redrawn refs fixed head shape, but Tripo regenerates the WHOLE body every time (B's neck became
  long and upright, "a Spinosaurus with a cobra face"). The method cannot hold the body fixed. Changed method.
- Round 4 (0 cr): head-only voxel graft onto the fixed croc body/rig. Fails: hard seam at the neck cut on every graft
  (Komodo too, plus its drool strands as voxel sticks), viper reads as a mask, cobra hood is a flat paper disc.
- Real finding: from the game camera (behind, 3/4 above) the head is hidden behind the back and shoulders, so head
  options only show in close shots (title screen, evolve screen, reveal).

## Tools (all test-only, nothing wired; numpy + Pillow + Blender CLI; no Godot)
- tools/blender/voxelize.py: `blender -b --python tools/blender/voxelize.py -- model.glb out.kvox <height_vox>` (height =
  model z extent x 868; croc is 320). A model facing +X needs a -90 deg Z rotation first (heads tests: komodo_prep.py).
- tools/kaiju_skin/head_graft.py: Komodo-style graft: `python head_graft.py croc.kvox donor.kvox out.kvox [--scale 0.7
  --gape Z,Y --tip Z,Y --cut-z -330]`; tags head0/head1/jaw, writes the matching rig.json; jaw opens at the croc's hinge.
- tools/kaiju_skin/snake_graft.py: viper/cobra: adds --bulge --flatten --fangs --blend --eye --hood (procedural hood).
- tools/kaiju_skin/rest_from_rig.py: Godot-free rest.json (head cells bit-identical to the committed croc skin; 7,419 arm
  cells differ). Bake: rest_from_rig.py out.json dir name; bake.py out.json dir (needs skin_weights.json entry).
- Views: tools/kaiju_skin/skins/vox_view.py renders any .kvox; scratch scripts in ~/Downloads/kaiju_tripo/skins_work.
- Models: ~/Downloads/kaiju_tripo/heads_python_r2a/b, heads_python_r3a/b, heads_komodo_b.glb (C), heads_r4/*.kvox;
  provenance rows in docs/provenance/tripo.md.

## Seam problem and proposed fix
The cut leaves the donor head's flat back face against the croc's neck (different cross-section, colour, spines).
Fix: a blend zone 40-60 voxels long: morph the donor's cross-section into the croc's neck outline (scale/offset per z
slice), re-colour that zone from the croc's hide with a gradient, re-skin the weights across it, and drop donor drool
strands (thin 1-cell columns) before voxelising. Do it in Blender (retopo the head onto the neck mesh) rather than on cells.

## Open items
- Cobra hood needs a real sculpt (curved shell from the neck sides, skinned to neck bones, back view first).
- Skins are NOT parked: final board skins_board_r6.png went to the director's queue.
