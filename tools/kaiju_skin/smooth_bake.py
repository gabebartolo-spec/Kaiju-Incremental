"""Look-boards mock C (capture-only branch, not for merge): the croc titan's own Tripo mesh and texture,
skinned to the game's hand rig, so it can be drawn smooth instead of as cubes.

    python tools/kaiju_skin/smooth_bake.py <rest.json from dump_rest.gd> <the Tripo .glb> <name, e.g. reptilian_adolescent> <out dir>

It follows tools/kaiju_skin/bake.py and skin_faces.py: the GLB's points go through rig_voxel's cell grid
and the export's kvox_cell_to_skin into skin space (where each lands on a welded, weighted position of the
Blender skin), take that position's bone weights (Blender bones counted for their "game" bone), and are moved
into the rig's real rest pose exactly as bake.py moves the voxels. Out: <name>.smesh (little-endian: "SMSH",
u32 version 1, u32 vertices, u32 indices, then f32 position[3], normal[3], uv[2], bone[4], weight[4] per
vertex, then u32 index) and <name>.png (the base-colour texture).
"""
import json
import struct
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
TYPES = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
DTYPES = {5126: "<f4", 5123: "<u2", 5125: "<u4", 5121: "u1"}


def read_glb(path):
    raw = Path(path).read_bytes()
    jlen = struct.unpack_from("<I", raw, 12)[0]
    doc = json.loads(raw[20:20 + jlen])
    off = 20 + jlen
    blen, btype = struct.unpack_from("<II", raw, off)
    blob = raw[off + 8:off + 8 + blen]

    def view(i):
        v = doc["bufferViews"][i]
        return blob[v.get("byteOffset", 0):v.get("byteOffset", 0) + v["byteLength"]]

    def accessor(i):
        a = doc["accessors"][i]
        n = TYPES[a["type"]]
        arr = np.frombuffer(view(a["bufferView"]), dtype=DTYPES[a["componentType"]], count=a["count"] * n,
                            offset=a.get("byteOffset", 0))
        return arr.reshape(a["count"], n) if n > 1 else arr

    prim = doc["meshes"][0]["primitives"][0]
    pos = accessor(prim["attributes"]["POSITION"]).astype(float)
    nrm = accessor(prim["attributes"]["NORMAL"]).astype(float)
    uv = accessor(prim["attributes"]["TEXCOORD_0"]).astype(float)
    idx = accessor(prim["indices"]).astype(np.uint32)
    tex = doc["textures"][0]["source"]
    img = view(doc["images"][tex]["bufferView"])
    return pos, nrm, uv, idx, img, doc["images"][tex].get("mimeType", "image/png")


def main():
    rest_path, glb, name, out = sys.argv[1:5]
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    rest = json.loads(Path(rest_path).read_text(encoding="utf-8"))[name]
    kdir = ROOT / "assets" / "kaiju"
    stem = name.replace("reptilian", "croctitan")
    meta_path = kdir / "test" / f"{stem}.skin.json"
    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    pos, nrm, uv, idx, img, mime = read_glb(glb)
    # glTF (Y up) -> Blender (Z up), as the Blender importer does.
    bl = np.c_[pos[:, 0], -pos[:, 2], pos[:, 1]]
    bl = np.c_[-bl[:, 1], bl[:, 0], bl[:, 2]]  # the skin was exported from this mesh turned to face -Y (found by search)
    lo, hi = bl.min(0), bl.max(0)
    sc = (meta["kvox_height"] - 1) / (hi[2] - lo[2])
    origin = np.array([(lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, lo[2]])
    k = (bl - origin) * sc - 0.5
    cell = np.c_[-(k[:, 0] + 1), k[:, 2], k[:, 1]]
    m = np.array(meta["kvox_cell_to_skin"], dtype=float)
    p_skin = (np.c_[cell, np.ones(len(cell))] @ m.T)[:, :3]
    raw = (meta_path.parent / meta["weights_file"]).read_bytes()
    count = struct.unpack_from("<I", raw, 8)[0]
    rec = np.frombuffer(raw, dtype=[("p", "<f4", 3), ("b", "u1", 4), ("w", "<f4", 4)], count=count, offset=14)
    welded = rec["p"].astype(float)
    near = np.zeros(len(p_skin), dtype=np.int64)
    worst = 0.0
    for s in range(0, len(p_skin), 512):
        d2 = ((p_skin[s:s + 512, None, :] - welded[None]) ** 2).sum(-1)
        near[s:s + 512] = d2.argmin(1)
        worst = max(worst, float(np.sqrt(d2.min(1)).max()))
    print(f"worst weld gap {worst:.4f} skin m (limit 0.05)")
    if worst > 0.05:
        raise SystemExit("this GLB is not the one the skin was exported from")
    names = [b["name"] for b in rest["bones"]]
    to_game = np.array([names.index(b["game"]) for b in meta["bones"]])
    per = np.zeros((len(p_skin), len(names)))
    for slot in range(4):
        b = rec["b"][near, slot]
        real = b != 255
        np.add.at(per, (np.nonzero(real)[0], to_game[b[real]]), rec["w"][near, slot][real])
    per = np.maximum(per, 0.0)
    per[per.sum(1) <= 0, names.index("spine0")] = 1.0
    per /= per.sum(1, keepdims=True)
    # Into the rest pose the game builds (bake.py): at = (cell + (0, .5, 0)) * voxel, then each bone's move.
    v = rest["voxel"]
    xf = np.array([b["xform"] for b in rest["bones"]])
    basis = xf[:, :9].reshape(-1, 3, 3).transpose(0, 2, 1)
    org, head = xf[:, 9:], np.array([b["head"] for b in rest["bones"]])
    at = (cell + np.array([0.0, 0.5, 0.0])) * v
    moved = np.zeros_like(at)
    for b in np.where(per.any(0))[0]:
        moved += per[:, b:b + 1] * ((at - head[b]) @ basis[b].T + org[b])
    # Normals: glTF -> Blender -> game cell axes, turned by the blended bone basis.
    nb = np.c_[nrm[:, 0], -nrm[:, 2], nrm[:, 1]]
    nb = np.c_[-nb[:, 1], nb[:, 0], nb[:, 2]]
    ng = np.c_[-nb[:, 0], nb[:, 2], nb[:, 1]]
    nout = np.zeros_like(ng)
    for b in np.where(per.any(0))[0]:
        nout += per[:, b:b + 1] * (ng @ basis[b].T)
    nout /= np.maximum(1e-9, np.linalg.norm(nout, axis=1, keepdims=True))
    top = np.argsort(-per, axis=1)[:, :4]
    tw = np.take_along_axis(per, top, 1)
    tw /= np.maximum(1e-9, tw.sum(1, keepdims=True))
    blob = b"SMSH" + struct.pack("<III", 1, len(moved), len(idx))
    for arr in (moved, nout, uv, top.astype(float), tw):
        blob += arr.astype("<f4").tobytes()
    blob += idx.reshape(-1, 3)[:, [0, 2, 1]].astype("<u4").tobytes()  # glTF winds counter-clockwise, Godot clockwise
    (out / f"{name}.smesh").write_bytes(blob)
    (out / f"{name}.{'png' if 'png' in mime else 'jpg'}").write_bytes(img)
    print(f"{name}.smesh: {len(moved)} vertices, {len(idx) // 3} triangles; bounds {moved.min(0).round(2)} .. {moved.max(0).round(2)}")


main()
