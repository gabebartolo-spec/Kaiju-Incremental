#!/usr/bin/env python3
"""The Unity slice's C++ core against Godot's: replays digests.json (tools/unity/export_slice.gd)
through kaiju_core.dll and fails on the first step whose grid, labels, islands, tips or mesh differ.

    python tools/unity/check_core.py
"""
import ctypes as C
import hashlib
import json
import pathlib
import struct
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2] / "unity"
SLICE = ROOT / "Assets" / "StreamingAssets" / "slice"
DLL = ROOT / "Assets" / "Plugins" / "x86_64" / "kaiju_core.dll"
VERTEX_BYTES = 36
TIP_CAP = 64
ISLAND_CAP = 1 << 16
REGION = 16


class Tip(C.Structure):
    _pack_ = 1
    _fields_ = [("part", C.c_int32), ("level", C.c_int32), ("dir_x", C.c_int32), ("dir_z", C.c_int32),
                ("pivot_x", C.c_float), ("pivot_z", C.c_float)]


def read_buildings() -> list[dict]:
    raw = (SLICE / "buildings.bin").read_bytes()
    assert raw[:4] == b"KSB1", "buildings.bin header"
    count = struct.unpack_from("<I", raw, 4)[0]
    at = 8
    out = []
    for _ in range(count):
        w, h, d, ox, oy, oz = struct.unpack_from("<6i", raw, at)
        at += 24
        fx, fy, fz, voxel = struct.unpack_from("<4f", raw, at)
        at += 16
        salt = struct.unpack_from("<I", raw, at)[0]
        at += 4
        noise, ux, uy, ax, ay = struct.unpack_from("<5f", raw, at)
        at += 20
        has_fix, res = struct.unpack_from("<2i", raw, at)
        at += 8
        n = w * h * d
        b = {"dims": (w, h, d), "offset": (ox, oy, oz), "origin": (fx, fy, fz), "voxel": voxel,
             "has_fixtures": has_fix, "res": res}
        for key, size in (("cells", n), ("drawn", n), ("looks", n), ("palette", 1024), ("finish", 256),
                          ("fixtures", 256)):
            b[key] = raw[at:at + size]
            at += size
        out.append(b)
    return out


def load_core() -> C.CDLL:
    core = C.CDLL(str(DLL))
    core.kc_mesher_create.restype = C.c_void_p
    core.kc_mesher_create.argtypes = [C.c_int] * 6 + [C.c_float] * 4 + [C.c_char_p] * 3 + [C.c_int]
    core.kc_mesh_region.argtypes = [C.c_void_p, C.c_void_p, C.c_int, C.c_int, C.c_int, C.c_void_p, C.c_void_p]
    core.kc_mesh_copy.argtypes = [C.c_void_p, C.c_void_p]
    core.kc_carve_sphere.argtypes = [C.c_void_p, C.c_void_p] + [C.c_int] * 3 + [C.c_float] * 4 + [C.c_void_p, C.c_int]
    core.kc_label.argtypes = [C.c_void_p, C.c_void_p, C.c_int, C.c_int, C.c_int, C.c_int, C.c_void_p]
    core.kc_islands.argtypes = [C.c_void_p, C.c_void_p, C.c_void_p, C.c_int, C.c_int, C.c_int, C.c_int,
                                C.c_void_p, C.c_int, C.c_void_p, C.c_int, C.c_void_p]
    core.kc_topple.argtypes = [C.c_void_p, C.c_void_p, C.c_void_p] + [C.c_int] * 4 + [C.c_void_p, C.c_int]
    return core


def mesh_all(core: C.CDLL, mesher: int, drawn, dims) -> tuple[int, int, str]:
    w, h, d = dims
    nr = [(v + REGION - 1) // REGION for v in dims]
    sha = hashlib.sha256()
    total_v = total_i = 0
    nv = C.c_int32()
    ni = C.c_int32()
    for rx in range(nr[0]):
        for ry in range(nr[1]):
            for rz in range(nr[2]):
                core.kc_mesh_region(mesher, drawn, rx, ry, rz, C.byref(nv), C.byref(ni))
                if nv.value == 0:
                    continue
                vb = C.create_string_buffer(nv.value * VERTEX_BYTES)
                ib = C.create_string_buffer(ni.value * 4)
                core.kc_mesh_copy(vb, ib)
                total_v += nv.value
                total_i += ni.value
                raw = vb.raw
                # Interleaved {pos, normal, rgba8, uv} to Godot's separate arrays, in digest order.
                stride = VERTEX_BYTES
                pos = b"".join(raw[k:k + 12] for k in range(0, len(raw), stride))
                nrm = b"".join(raw[k + 12:k + 24] for k in range(0, len(raw), stride))
                col = b"".join(raw[k + 24:k + 28] for k in range(0, len(raw), stride))
                uvs = b"".join(raw[k + 28:k + 36] for k in range(0, len(raw), stride))
                for part in (pos, nrm, col, uvs, ib.raw):
                    sha.update(part)
    return total_v, total_i, sha.hexdigest()


def sha_of(buffer, size: int) -> str:
    return hashlib.sha256(bytes(buffer)[:size]).hexdigest()


def main() -> int:
    data = json.loads((SLICE / "digests.json").read_text())
    buildings = read_buildings()
    core = load_core()
    failures = 0
    checks = 0
    for entry in data["buildings"]:
        b = buildings[entry["index"]]
        w, h, d = b["dims"]
        n = w * h * d
        cells = (C.c_ubyte * n).from_buffer_copy(b["cells"])
        drawn = (C.c_ubyte * n).from_buffer_copy(b["drawn"])
        fix = (C.c_ubyte * 256).from_buffer_copy(b["fixtures"])
        ox, oy, oz = b["offset"]
        fx, fy, fz = b["origin"]
        mesher = core.kc_mesher_create(w, h, d, ox, oy, oz, fx, fy, fz, b["voxel"], b["looks"], b["palette"],
                                       b["finish"], 0)
        labels = (C.c_int32 * n)()
        island_cells = (C.c_int32 * n)()
        sizes = (C.c_int32 * ISLAND_CAP)()
        tips = (Tip * TIP_CAP)()
        for k, step in enumerate(entry["steps"]):
            cx, cy, cz = step["centre"]
            r = step["radius"]
            removed = core.kc_carve_sphere(cells, drawn, w, h, d, cx, cy, cz, r, None, 0)
            count = core.kc_label(cells, fix, b["has_fixtures"], w, h, d, labels)
            total = C.c_int32()
            parts = core.kc_islands(labels, cells, fix, b["has_fixtures"], w, h, d, island_cells, n, sizes,
                                    ISLAND_CAP, C.byref(total))
            found = core.kc_topple(labels, cells, fix, w, h, d, count, tips, TIP_CAP)
            got_tips = []
            for t in tips[:found]:
                got_tips.append({
                    "part": t.part, "level": t.level, "dir": [t.dir_x, t.dir_z],
                    "pivot": [(t.pivot_x + ox) / b["res"], (t.level + oy) / b["res"], (t.pivot_z + oz) / b["res"]],
                })
            verts, indices, mesh_sha = mesh_all(core, mesher, drawn, b["dims"])
            got = {
                "removed": removed,
                "cells_sha": sha_of(cells, n),
                "labels_sha": sha_of(labels, n * 4),
                "count": count,
                "island_sizes": list(sizes[:parts]),
                "islands_sha": sha_of(island_cells, total.value * 4),
                "verts": verts,
                "indices": indices,
                "mesh_sha": mesh_sha,
            }
            for key, value in got.items():
                checks += 1
                if value != step[key]:
                    failures += 1
                    print(f"building {entry['index']} step {k} {key}: got {value}, godot {step[key]}")
            checks += 1
            if not same_tips(got_tips, step["tips"]):
                failures += 1
                print(f"building {entry['index']} step {k} tips: got {got_tips}, godot {step['tips']}")
            for i in island_cells[:total.value]:
                cells[i] = 0
                drawn[i] = 0
        print(f"building {entry['index']} dims {b['dims']}: {len(entry['steps'])} steps, "
              f"last {verts} verts, {count} parts")
        core.kc_mesher_destroy.argtypes = [C.c_void_p]
        core.kc_mesher_destroy(mesher)
    print(f"check_core: {checks} checks, {failures} failures")
    return 1 if failures else 0


def same_tips(a: list, b: list) -> bool:
    if len(a) != len(b):
        return False
    for x, y in zip(a, b):
        if x["part"] != y["part"] or x["level"] != y["level"] or x["dir"] != y["dir"]:
            return False
        if any(abs(p - q) > 1e-3 for p, q in zip(x["pivot"], y["pivot"])):
            return False
    return True


if __name__ == "__main__":
    sys.exit(main())
