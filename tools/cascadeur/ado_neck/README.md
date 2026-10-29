# Adolescent croc neck fix (y9 rig, 2026-10-29)

The y8 adolescent rig creased at the back of the neck when the head bends hard (slam_stop f35-39: 9 flipped or
collapsed head/neck triangles at f37). y9 smooths the neck0/neck1 weights around those triangles.

Neck bar (`ntable.py`): twist under 60 deg on every neck joint pair, and at most 6 bad head+neck triangles on every frame.
slam_stop on y9 in Cascadeur: PASS, worst 1 triangle at f37 (y8: 9), 0 frames over 6. Twist unchanged.

Pipeline (paths are this machine's cascadeur_bridge folders):
1. `nsmooth.py`: seed = neck0/neck1 triangles that go bad in slam_stop f30-45, grow 2 rings, Laplacian smooth
   (20 passes, 0.5), keep the top 4 weights.
2. `mk_ado_wfix.py` -> `ado_wfix_ns1.npz` (2035 vertices changed vs y7) -> Blender FBX -> `rig_y9.sh` builds
   `croc_adolescent_rig_y9.casc`.
3. `run_y9.sh` keys slam_stop on y9, dumps Cascadeur's skin, runs the bar. `neckshot.py` draws the before/after still.
4. `blend_wfix.py` writes the same weights into the young rig .blend; `tools/blender/croc_young_export.py` gives the
   game skin, staged as `assets/kaiju/test/croctitan_adolescent_y9.{skin.json,skinw}` (41 bones -> 36 game bones).

Not live in the game: the baby and adolescent still play on main's 27-bone skeleton until the young clip set is done.
