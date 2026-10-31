"""Player-effect fixture for tools/kaiju_skin/thicken.py (director 2026-10-31, "Thicken + keep CoR", girth 1.3).

A straight voxel thigh (a solid cylinder on its bone, a hip block above it) baked with the step off and on: on, the
thigh is girth times as wide at mid-thigh and its own width at the knee, every sculpted voxel stays with its colour
and bone, and a new voxel takes both from the voxel it was pushed out from. Synthetic, so it needs no LFS asset.
"""

import sys
import unittest
from pathlib import Path

try:
    import numpy as np
except ImportError:  # the CI lint image has no numpy; the bake tools need it
    np = None

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "kaiju_skin"))
if np is not None:
    import thicken  # noqa: E402

NAMES = ["spine0", "leg_l0", "leg_l1"]
BONES = [{"name": "leg_l1", "head": [0.0, 100.0, 0.0], "tail": [0.0, 0.0, 0.0]}]
SPEC = {"thigh": ["leg_l1"], "hip": ["leg_l0"], "girth": 1.3, "full_to": 0.55, "knee": 0.9, "hip_reach": 0.5}
RADIUS = 10


def _leg():
    cells, owner = [], []
    for y in range(0, 121):
        for x in range(-RADIUS, RADIUS + 1):
            for z in range(-RADIUS, RADIUS + 1):
                if x * x + z * z <= RADIUS * RADIUS:
                    cells.append((x, y, z))
                    owner.append(NAMES.index("leg_l1") if y <= 100 else NAMES.index("leg_l0"))
    cells = np.array(cells)
    rgb = np.stack([cells[:, 1] % 256, np.full(len(cells), 7), np.full(len(cells), 9)], 1).astype(np.uint8)
    return cells, rgb, np.array(owner)


def _width(cells, y):
    return np.abs(cells[cells[:, 1] == y][:, 0]).max()


@unittest.skipUnless(np is not None, "numpy is not installed")
class ThickenTest(unittest.TestCase):
    def test_on_widens_mid_thigh_and_keeps_the_knee(self):
        cells, rgb, owner = _leg()
        on, on_rgb, on_owner = thicken.thicken(cells, rgb, owner, NAMES, BONES, SPEC)
        mid = 70  # t 0.3 along the thigh: full girth
        self.assertEqual(_width(cells, mid), RADIUS)
        self.assertEqual(_width(on, mid), round(RADIUS * SPEC["girth"]))
        self.assertEqual(_width(on, 5), RADIUS)  # t 0.95: past the knee mark, its own width
        self.assertGreater(len(on), len(cells))

    def test_sculpt_kept_and_new_voxels_copy_their_source(self):
        cells, rgb, owner = _leg()
        on, on_rgb, on_owner = thicken.thicken(cells, rgb, owner, NAMES, BONES, SPEC)
        np.testing.assert_array_equal(on[: len(cells)], cells)
        np.testing.assert_array_equal(on_rgb[: len(cells)], rgb)
        added = on[len(cells):]
        self.assertTrue((on_rgb[len(cells):, 1] == 7).all())
        self.assertTrue(np.isin(on_owner[len(cells):], [1, 2]).all())
        # A new voxel's colour encodes the height it was copied from: never far from its own.
        self.assertLessEqual(np.abs(on_rgb[len(cells):, 0].astype(int) - added[:, 1] % 256).max(), 3)

    def test_girth_one_changes_nothing(self):
        cells, rgb, owner = _leg()
        on, _, _ = thicken.thicken(cells, rgb, owner, NAMES, BONES, dict(SPEC, girth=1.0))
        np.testing.assert_array_equal(on, cells)


if __name__ == "__main__":
    unittest.main()
