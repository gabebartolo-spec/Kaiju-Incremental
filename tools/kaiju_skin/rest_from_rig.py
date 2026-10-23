"""Writes the rest.json that dump_rest.gd would, for biped rigs, without running Godot (D-164 head tests).

    python tools/kaiju_skin/rest_from_rig.py <out.json> <assets/kaiju dir> <name> [<name> ...]

Mirrors KaijuRig._build + _relax_arms + BipedSwing.rest_arm_bases + dump_rest.gd for a body plan "biped":
every bone rests at its head (identity basis) except the arm chains, which turn from their sculpted
direction to BipedSwing's ARM_UPPER / ARM_FORE / ARM_HAND (a shortest-arc rotation each, relative to the
parent). Check it by baking an unchanged rig and diffing the .vskin against the committed one: the
0-difference result is the proof this still matches the game (see the head-test notes).
"""
import json
import sys
from pathlib import Path

import numpy as np

MODEL_HEIGHT = 10.0  # KaijuModel.MODEL_HEIGHT
ARM_DIRS = [np.array(v, float) for v in ((0.15, -0.92, -0.35), (-0.25, -0.2, -0.95), (-0.2, -0.55, -0.8))]


def arc(a, b):
    """Basis (3x3, columns = images of x, y, z) of the shortest-arc rotation a -> b (Godot Quaternion(a, b))."""
    c, d = np.cross(a, b), float(np.dot(a, b))
    if d < -1 + 1e-9:  # opposite: any perpendicular axis, 180 degrees
        axis = np.cross(a, np.array([1.0, 0, 0]))
        if np.linalg.norm(axis) < 1e-6:
            axis = np.cross(a, np.array([0, 1.0, 0]))
        axis /= np.linalg.norm(axis)
        x, y, z, w = *axis, 0.0
    else:
        s = np.sqrt((1.0 + d) * 2.0)
        x, y, z, w = c[0] / s, c[1] / s, c[2] / s, s * 0.5
    n = x * x + y * y + z * z + w * w
    x, y, z, w = x / np.sqrt(n), y / np.sqrt(n), z / np.sqrt(n), w / np.sqrt(n)
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def rest_for(spec, voxel):
    bones = spec["bones"]
    head = {b["name"]: np.array(b["head"], float) * voxel for b in bones}
    tail = {b["name"]: np.array(b["tail"], float) * voxel for b in bones}
    parent = {b["name"]: b["parent"] for b in bones}
    local_basis = {b["name"]: np.eye(3) for b in bones}
    for side in ("l", "r"):
        if f"arm_{side}0" not in head:
            continue
        outward = np.sign((tail[f"arm_{side}0"] - head[f"arm_{side}0"])[0])
        above = np.eye(3)
        for i, d in enumerate(ARM_DIRS):
            n = f"arm_{side}{i}"
            if n not in head:
                break
            want = d * np.array([outward, 1, 1])
            want /= np.linalg.norm(want)
            direction = tail[n] - head[n]
            world = arc(direction / np.linalg.norm(direction), want)
            local_basis[n] = np.linalg.inv(above) @ world
            above = world
    out = []
    for b in bones:
        n = b["name"]
        m, o = local_basis[n], head[n] - (head[parent[n]] if parent[n] else 0)
        t = (m, o)
        p = parent[n]
        while p:  # compose up the parent chain: child transform applied inside the parent's
            pm, po = local_basis[p], head[p] - (head[parent[p]] if parent[p] else 0)
            t = (pm @ t[0], pm @ t[1] + po)
            p = parent[p]
        m, o = t
        xform = [*m[:, 0], *m[:, 1], *m[:, 2], *o]
        out.append({"name": n, "xform": [float(v) for v in xform], "head": [float(v) for v in head[n]]})
    return out


def main():
    out_path, kdir, names = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3:]
    dump = {}
    for name in names:
        spec = json.loads((kdir / f"{name}.rig.json").read_text(encoding="utf-8"))
        assert spec.get("type", "biped") == "biped", "only biped rigs"
        voxel = MODEL_HEIGHT / spec["height"]
        dump[name] = {"voxel": voxel, "bones": rest_for(spec, voxel)}
    out_path.write_text(json.dumps(dump), encoding="utf-8")
    print(f"wrote {len(dump)} rest pose(s) to {out_path}")


if __name__ == "__main__":
    main()
