# Heads: PARKED (D-171, post-demo). Branch claude/heads-skins. Credits used: 580 of 6,500.

## What each round tried and why it failed
- Round 1: Python A/B, Komodo A/B/C as whole-creature Tripo regenerations. Komodo C (own shape) won.
- Round 2 (260 cr): viper A, cobra B via GPT Image 2.5 edit of the croc ref + Smart Mesh + texture. B had a drip shard,
  lip teeth, a thick cape hood, scab blotches; A read as a croc-skull viper with tusk fangs. Critic: both FIX.
- Round 3 (260 cr): redrawn refs fixed the head shapes, but Tripo regenerates the WHOLE body each time (B's neck turned
  long and upright, "a Spinosaurus with a cobra face"). The method cannot hold the body fixed, so the method changed.
- Round 4 (0 cr): head-only voxel graft onto the fixed croc body and rig. Fails: a hard seam at the neck cut on every
  graft (Komodo too, plus its drool strands as voxel sticks), the viper reads as a mask, the cobra hood is a flat disc.
- Real finding: from the game camera (behind, 3/4 above) the head hides behind the back and shoulders; head options
  only show in close shots (title, evolve screen, reveal).

## Tools (test only, nothing wired; numpy, Pillow, Blender CLI; no Godot)
- tools/blender/voxelize.py: `blender -b --python tools/blender/voxelize.py -- m.glb out.kvox <height_vox>` (z extent x 868;
  croc = 320). A model facing +X needs a -90 deg Z turn first (komodo_prep.py in ~/Downloads/kaiju_tripo/skins_work).
- tools/kaiju_skin/head_graft.py: `python head_graft.py croc.kvox donor.kvox out.kvox [--scale --gape Z,Y --tip Z,Y --cut-z]`
  tags head0/head1/jaw and writes the rig.json; the jaw opens at the croc's hinge.
- tools/kaiju_skin/snake_graft.py: same plus --bulge --flatten --fangs --blend --eye --hood (procedural cobra hood).
- tools/kaiju_skin/rest_from_rig.py: Godot-free rest.json; `rest_from_rig.py out.json dir name`, then
  `bake.py out.json dir` (add the name to skin_weights.json). Head cells match the committed skin; 7,419 arm cells differ.
- Views: tools/kaiju_skin/skins/vox_view.py. Models: ~/Downloads/kaiju_tripo/heads_python_r2a/b, r3a/b, heads_komodo_b.glb,
  heads_r4/*.kvox. Provenance rows: docs/provenance/tripo.md.

## Seam fix (proposed) and open items
- Seam: the donor's flat back face meets a different neck cross-section, colour and spines. Fix: a 40-60 voxel blend zone
  (morph the donor outline into the croc neck per z slice, recolour from the hide with a gradient, re-skin the weights
  across it), drop 1-cell drool columns before voxelising; better, retopo the head onto the neck in Blender.
- Cobra hood needs a real sculpt (curved shell from the neck sides, skinned to the neck bones, back view first).
- Skins are NOT parked: skins_board_r6.png went to the director's queue.
