"""D-374 corrective helper joints for a Blender skin export (tools/kaiju_skin/bake.py).

A skin.json may list "helpers": joints with no rig node that sit between two game bones (the
Colossus's hip, knee, web, ankle and belly helpers per leg). The export's .skinw weights them after its
bones (index len(bones) + k). Each is given in skin.json space (game metres) as
    {"name", "a", "b" (game bones), "frac", "grow" (bool), "centre" [3], "push" [3], "per_turn" [3][3]}
and scenes/voxel_skin_helpers.gd poses it every frame from bones a and b (rest-to-now A, B):
    r = rotation vector of Ra^T Rb, R = Ra exp(frac r), t = (A c + B c) / 2, g = (1 - cos|r|) / 2,
    push = (P r + d) g when grow, else P r + d g;  helper = [R | t - R c + R push].
This module moves those numbers into the rig's rest space (the units scenes/voxel_skin.gd works in)
and writes the .vskin's optional helper block after the filler.
"""
import struct

import numpy as np

TAG = b"HELP"
# u8 a, u8 b, u8 flags, u8 pad, f32 frac, centre, push, per_turn columns (VoxelSkinHelpers.HELPER_BYTES).
HELPER_FORMAT = "<BBBxf3f3f9f"
ORTHO_TOL = 1e-4  # a skin-to-rig map must be a similarity (scale times a rotation or mirror)


def helpers_of(meta):
    """The skin.json's helper list (empty when it has none)."""
    return list(meta.get("helpers", []))


def skin_to_bone_rest(meta, rest_bone, voxel):
    """The affine map (4x4) from skin.json space to the rig's rest space for points on rest_bone:
    skin -> .kvox cell (inverse kvox_cell_to_skin), the cell centre in rig units (bake.py's
    (cell + half up) * voxel), then the bone's own rest move (dump_rest xform, as bake.py does)."""
    to_cell = np.linalg.inv(np.array(meta["kvox_cell_to_skin"], dtype=float))
    lift = np.eye(4)
    lift[:3, 3] = [0.0, 0.5, 0.0]
    scale = np.diag([voxel, voxel, voxel, 1.0])
    xf = np.array(rest_bone["xform"], dtype=float)
    move = np.eye(4)
    move[:3, :3] = xf[:9].reshape(3, 3).T  # columns x, y, z
    move[:3, 3] = xf[9:] - move[:3, :3] @ np.array(rest_bone["head"], dtype=float)
    return move @ scale @ lift @ to_cell


def to_rig(helpers, meta, rest_bones, names, voxel):
    """Each helper with its bones as indices into names and its numbers in rig rest units."""
    out = []
    for h in helpers:
        a, b = names.index(h["a"]), names.index(h["b"])
        m = skin_to_bone_rest(meta, rest_bones[a], voxel)
        lin = m[:3, :3]
        s = abs(np.linalg.det(lin)) ** (1.0 / 3.0)
        q = lin / s
        assert np.abs(q @ q.T - np.eye(3)).max() < ORTHO_TOL, f"{h['name']}: skin-to-rig map is not a similarity"
        mirror = float(np.sign(np.linalg.det(q)))  # a turn's axis flips in a mirror
        centre = (m @ np.r_[np.array(h["centre"], dtype=float), 1.0])[:3]
        push = s * q @ np.array(h["push"], dtype=float)
        per_turn = mirror * s * q @ np.array(h["per_turn"], dtype=float) @ q.T
        out.append(dict(name=h["name"], a=a, b=b, frac=float(h["frac"]), grow=bool(h["grow"]),
                        centre=centre, push=push, per_turn=per_turn))
    return out


def block(rig_helpers):
    """The .vskin helper block (empty bytes when there are none)."""
    if not rig_helpers:
        return b""
    out = TAG + struct.pack("<H", len(rig_helpers))
    for h in rig_helpers:
        cols = np.asarray(h["per_turn"], dtype=float).T.reshape(-1)  # column-major: Basis(x, y, z)
        out += struct.pack(HELPER_FORMAT, h["a"], h["b"], 1 if h["grow"] else 0, h["frac"],
                           *np.asarray(h["centre"], dtype=float), *np.asarray(h["push"], dtype=float), *cols)
    return out


def pose(h, a, b):
    """Helper h's rest-to-now matrix from bone matrices a and b (4x4): the reference for
    scenes/voxel_skin_helpers.gd (tests compare the two)."""
    def ortho(m):
        u, _, vt = np.linalg.svd(m)
        return u @ vt
    ra, rb = ortho(a[:3, :3]), ortho(b[:3, :3])
    rel = ra.T @ rb
    angle = np.arccos(np.clip((np.trace(rel) - 1.0) / 2.0, -1.0, 1.0))
    turn = np.zeros(3)
    r = ra
    if angle > 1e-6:
        axis = np.array([rel[2, 1] - rel[1, 2], rel[0, 2] - rel[2, 0], rel[1, 0] - rel[0, 1]])
        if np.linalg.norm(axis) < 1e-9:  # a half turn: the axis from the symmetric part
            w, v = np.linalg.eigh(rel + rel.T)
            axis = v[:, np.argmax(w)]
        axis /= np.linalg.norm(axis)
        turn = axis * angle
        r = ra @ _axis_angle(axis, h["frac"] * angle)
    c = np.asarray(h["centre"], dtype=float)
    t = 0.5 * ((a @ np.r_[c, 1.0])[:3] + (b @ np.r_[c, 1.0])[:3])
    g = (1.0 - np.cos(angle)) / 2.0
    p, d = np.asarray(h["per_turn"], dtype=float), np.asarray(h["push"], dtype=float)
    push = (p @ turn + d) * g if h["grow"] else p @ turn + d * g
    m = np.eye(4)
    m[:3, :3] = r
    m[:3, 3] = t - r @ c + r @ push
    return m


def _axis_angle(axis, angle):
    k = np.array([[0, -axis[2], axis[1]], [axis[2], 0, -axis[0]], [-axis[1], axis[0], 0]])
    return np.eye(3) + np.sin(angle) * k + (1 - np.cos(angle)) * k @ k
