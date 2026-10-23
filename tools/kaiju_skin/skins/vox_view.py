"""Orthographic voxel viewer for skin boards (numpy + PIL, no Godot): renders a rigged kaiju's .kvox cells
with any per-cell colour array. Used by skin_tool.py. Not game code.

    pos, col, bone = load("reptilian_adult")
    img, scale, view_centre = render(pos, col, normals(pos), yaw, pitch)
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "kaiju_skin"))
import bake  # noqa: E402  (read_kvox)


def load(name="reptilian_adult"):
    pos, col, bone = bake.read_kvox(REPO / "assets" / "kaiju" / f"{name}.kvox")
    return pos, col, bone


def bone_names(name="reptilian_adult"):
    import json
    rig = json.loads((REPO / "assets" / "kaiju" / f"{name}.rig.json").read_text(encoding="utf-8"))
    return [b["name"] for b in rig["bones"]]


def normals(pos):
    """Outward normal per cell: minus the mean offset of occupied cells in a 5x5x5 window."""
    mn = pos.min(0) - 3
    idx = pos - mn
    occ = np.zeros(idx.max(0) + 4, dtype=np.uint8)
    occ[idx[:, 0], idx[:, 1], idx[:, 2]] = 1
    acc = np.zeros((len(pos), 3), dtype=np.float32)
    for dx in range(-2, 3):
        for dy in range(-2, 3):
            for dz in range(-2, 3):
                if dx == dy == dz == 0:
                    continue
                v = occ[idx[:, 0] + dx, idx[:, 1] + dy, idx[:, 2] + dz].astype(np.float32)
                acc -= v[:, None] * np.array([dx, dy, dz], dtype=np.float32)
    n = np.linalg.norm(acc, axis=1, keepdims=True)
    n[n < 1e-6] = 1
    return acc / n


def camera(yaw_deg, pitch_deg):
    y, p = np.radians(yaw_deg), np.radians(pitch_deg)
    ry = np.array([[np.cos(y), 0, np.sin(y)], [0, 1, 0], [-np.sin(y), 0, np.cos(y)]])
    rx = np.array([[1, 0, 0], [0, np.cos(p), -np.sin(p)], [0, np.sin(p), np.cos(p)]])
    return rx @ ry


def render(pos, col, nrm, yaw, pitch, size=(1000, 800), scale=None, center=None, light=(-0.4, 0.8, 0.45),
           bg=(168, 170, 172), ambient=0.42, glow=None, extent_from=None, gain=1.0):
    """Splat cells nearest-wins. glow: optional bool array of emissive cells (drawn unshaded).
    extent_from: positions whose view-space extent set the auto scale/centre (so crops stay in step).
    Returns (image, scale, centre) so a later call can zoom on the same view."""
    m = camera(yaw, pitch)
    p = pos.astype(np.float32) @ m.T
    ref = p if extent_from is None else extent_from.astype(np.float32) @ m.T
    if center is None:
        center = (ref.min(0) + ref.max(0)) / 2
    if scale is None:
        ext = ref.max(0) - ref.min(0)
        scale = min(size[0] * 0.92 / ext[0], size[1] * 0.92 / ext[1])
    p = p - center
    W, H = size
    sx = (p[:, 0] * scale + W / 2).astype(int)
    sy = (H / 2 - p[:, 1] * scale).astype(int)
    depth = p[:, 2]
    nv = nrm @ m.T
    L = np.array(light, dtype=np.float32)
    L /= np.linalg.norm(L)
    diff = np.clip(nv @ L, 0, 1)
    rim = np.clip(1 - np.abs(nv[:, 2]), 0, 1) * 0.08
    shade = ambient + (1 - ambient) * diff + rim
    if glow is not None:
        shade = np.where(glow, 1.0, shade)
    rgb = np.clip(col.astype(np.float32) * shade[:, None] * gain, 0, 255)
    img = np.zeros((H, W, 3), np.float32)
    img[:] = bg
    zb = np.full((H, W), 1e9, np.float32)
    order = np.argsort(-depth)  # far first, near overwrites
    k = int(np.ceil(scale)) + 1
    for dx in range(k):
        for dy in range(k):
            xs, ys = sx + dx - k // 2, sy + dy - k // 2
            ok = (xs >= 0) & (xs < W) & (ys >= 0) & (ys < H)
            o = order[ok[order]]
            xo, yo, zo = xs[o], ys[o], depth[o]
            img[yo, xo] = np.where((zo < zb[yo, xo])[:, None], rgb[o], img[yo, xo])
            zb[yo, xo] = np.minimum(zb[yo, xo], zo)
    return Image.fromarray(img.astype(np.uint8)), scale, center
