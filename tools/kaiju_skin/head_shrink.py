"""Shrinks a rigged .kvox's head about the neck joint, matching tools/blender/croc_trex_export.py HEAD_SCALE (director
2026-11-05: the croc's head 10% smaller). The voxels keep their colours, mouth fill and lid flaps: each cell moves
toward the head1 bone's head (the neck joint) by its share of head weight (head1, jaw, lid_*) from the UNSHRUNK skin,
so the neck blends in, then snaps back to the grid (a cell that lands on a taken cell is dropped, the outer one kept).
Run rig_from_skin.py with the shrunk export's skin.json afterwards.

    python tools/kaiju_skin/head_shrink.py <name.kvox> <unshrunk x.skin.json> <scale>
"""
import json
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake  # noqa: E402
import lid_flaps  # noqa: E402
import rig_from_skin  # noqa: E402
import skin_helpers  # noqa: E402


def is_head(name):
    return name in ("head1", "jaw") or name.startswith("lid_")


def main(kvox_path, meta_path, scale):
    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    names = rig_from_skin.bone_names(meta)
    helpers = skin_helpers.helpers_of(meta)
    data = kvox_path.read_bytes()
    cells, rgb, owner = bake.read_kvox(kvox_path)
    w, _gap = bake.sample_skin(meta_path, cells, names + [h["name"] for h in helpers])
    head_cols = [i for i, n in enumerate(names) if is_head(n)]
    share = w[:, head_cols].sum(1) / np.maximum(w.sum(1), 1e-9)
    m = np.array(meta["kvox_cell_to_skin"], dtype=float)
    pivot_skin = next(b["head"] for b in meta["bones"] if b["game"] == "head1")
    pivot = (np.linalg.inv(m) @ np.r_[pivot_skin, 1.0])[:3]
    moved = np.rint(pivot + (cells - pivot) * (1.0 - (1.0 - scale) * share)[:, None]).astype(int)
    far = np.argsort(-((cells - pivot) ** 2).sum(1), kind="stable")  # outer cells first: they win a shared cell
    _u, first = np.unique(moved[far], axis=0, return_index=True)
    keep = np.sort(far[first])
    lid_flaps.write_kvox(kvox_path, data, moved[keep], rgb[keep], owner[keep])
    print(f"{kvox_path.name}: head x{scale} about {pivot.round(1)}; {int((share > 0.01).sum())} cells moved, "
          f"{len(cells) - len(keep)} merged, {len(keep)} left")


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]), float(sys.argv[3]))
