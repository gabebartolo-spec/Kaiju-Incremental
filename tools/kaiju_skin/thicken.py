"""Thicker thighs for a kaiju's voxels at bake time (director 2026-10-31: "Thicken + keep CoR"; the
Colossus's thigh was a thin tube even standing). The .kvox sculpt stays as Tripo made it; bake.py
widens it here, from data/tuning.json skin_bake.thicken.<kaiju>:

    {"thigh": ["leg_l1", "leg_r1"], "hip": ["leg_l0", "leg_r0"], "girth": 1.3,
     "full_to": 0.55, "knee": 0.9, "hip_reach": 0.5}

Each thigh (its bone's head to tail, t 0..1) is pushed out from that axis by `girth` from the hip
to t full_to, easing back to its own width at t knee; above the hip (t < 0, the hip bone's voxels)
it eases back to its own width at t -hip_reach, so it widens into the belly with no step. A new voxel
copies the colour and bone of the voxel it was pushed out from; no voxel is taken away.
"""
import numpy as np


def _ease(x):
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3.0 - 2.0 * x)


def _factor(t, spec):
    """How far a point at t along the thigh is pushed out (1 = not at all)."""
    up = 1.0 - _ease((t - spec["full_to"]) / max(1e-6, spec["knee"] - spec["full_to"]))
    above = _ease(1.0 + t / spec["hip_reach"])
    return 1.0 + (spec["girth"] - 1.0) * np.where(t < 0.0, above, up)


def _one(cells, rgb, owner, region, head, tail, spec):
    """The voxels one thigh adds: lattice points whose pushed-in point lies in `region`."""
    have = {tuple(p): i for i, p in zip(np.nonzero(region)[0], cells[region])}
    axis = tail - head
    length2 = float(axis @ axis)
    grow = (spec["girth"] - 1.0) * np.abs(cells[region] - head).max()
    lo = np.floor(cells[region].min(0) - grow).astype(int)
    hi = np.ceil(cells[region].max(0) + grow).astype(int)
    g = np.stack(np.meshgrid(*[np.arange(a, b + 1) for a, b in zip(lo, hi)], indexing="ij"), -1)
    g = g.reshape(-1, 3)
    t = ((g - head) @ axis) / length2
    on = head + t[:, None] * axis
    back = np.round(on + (g - on) / _factor(t, spec)[:, None]).astype(int)
    src = np.array([have.get(tuple(p), -1) for p in back])
    keep = src >= 0
    return g[keep], src[keep]


def thicken(cells, rgb, owner, names, bones, spec):
    """cells, rgb, owner with the thighs widened (bones: the .rig.json bone list, kvox units)."""
    by = {b["name"]: b for b in bones}
    add_c, add_s = [cells], [np.arange(len(cells))]
    for thigh, hip in zip(spec["thigh"], spec["hip"]):
        region = np.isin(owner, [names.index(thigh), names.index(hip)])
        head, tail = np.array(by[thigh]["head"], float), np.array(by[thigh]["tail"], float)
        c, s = _one(cells, rgb, owner, region, head, tail, spec)
        add_c.append(c)
        add_s.append(s)
    allc, src = np.concatenate(add_c), np.concatenate(add_s)
    _, first = np.unique(allc, axis=0, return_index=True)  # the sculpt's own voxels come first
    first.sort()
    return allc[first], rgb[src[first]], owner[src[first]]
