"""Player-effect fixture for tools/kaiju_skin/cor.py (director 2026-10-31, thighs: centres of rotation).

A two-bone limb bent 90 degrees at its joint. With the plain linear blend (off) a cube weighted half to each bone
is pulled in towards the joint, so the limb thins at the bend; with its centre of rotation (on, the shader's move
done here in numpy) it keeps its distance from the joint. Cubes on one bone get no centre.
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
    import cor  # noqa: E402


RING = 8  # cubes round the tube at each x


def _limb():
    """A tube of radius 4 along x from -10 to 10 (RING cubes round each x, the first straight up), the weight
    easing from bone 0 to 1 across the joint at the origin."""
    x = np.repeat(np.arange(-10, 11, dtype=float), RING)
    a = np.tile(np.arange(RING) * 2.0 * np.pi / RING, 21)
    centres = np.stack([x, 4.0 * np.cos(a), 4.0 * np.sin(a)], 1)
    w1 = np.clip((x + 5.0) / 10.0, 0.0, 1.0)
    bones = np.stack([np.zeros(len(x), int), np.ones(len(x), int), np.zeros(len(x), int)], 1)
    weights = np.stack([1.0 - w1, w1, np.zeros_like(x)], 1)
    return centres, bones, weights


def _turn(deg):
    a = np.radians(deg)
    return np.array([[np.cos(a), -np.sin(a), 0.0], [np.sin(a), np.cos(a), 0.0], [0.0, 0.0, 1.0]])


@unittest.skipUnless(np is not None, "numpy is not installed")
class CorTest(unittest.TestCase):
    def test_on_keeps_the_bend_from_thinning(self):
        centres, bones, weights = _limb()
        c, has = cor.centres_of_rotation(centres, bones, weights, 2)
        rot = [np.eye(3), _turn(90.0)]  # bone 1 turns about the joint at the origin (about z)
        mid = 10 * RING  # x 0, top of the tube: half on each bone
        w = weights[mid, :2]
        lbs = w[0] * (rot[0] @ centres[mid]) + w[1] * (rot[1] @ centres[mid])
        half = _turn(45.0)  # the two bones' quaternion blend at half and half
        moved = half @ (centres[mid] - c[mid]) + w[0] * (rot[0] @ c[mid]) + w[1] * (rot[1] @ c[mid])
        rest = np.linalg.norm(centres[mid])
        self.assertEqual(has[mid], 1)
        self.assertLess(np.linalg.norm(lbs), rest - 0.5)  # off: the linear blend pulls it in
        self.assertAlmostEqual(np.linalg.norm(moved), rest, delta=0.5)  # on: it keeps its distance

    def test_one_bone_cubes_get_no_centre(self):
        centres, bones, weights = _limb()
        _, has = cor.centres_of_rotation(centres, bones, weights, 2)
        self.assertTrue((has[: 5 * RING] == 0).all())
        self.assertTrue((has[-5 * RING:] == 0).all())


if __name__ == "__main__":
    unittest.main()
