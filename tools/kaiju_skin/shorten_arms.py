"""Shortens a rigged kaiju's arms along their own axis, the shoulder kept where it is (director
2026-10-25 on the young croc: "realistically his arms are probably 40% long and dont require the
dangle from the wrist, short and stumpy arms are the aim"). One-off asset edit, then re-bake:

    python tools/kaiju_skin/shorten_arms.py reptilian_baby 0.4
    GODOT=... bash tools/kaiju_skin/bake_all.sh

For each side (arm_l*, arm_r*) the arm axis runs from the upper arm's head (the shoulder) to the
hand's tail. Every point past the shoulder along that axis keeps its distance from the axis and moves
along it so the whole arm is `factor` of its length: the hand keeps HAND_KEEP of its own (the claws
still read as claws), the upper arm and forearm take the rest of the cut:
- the .kvox voxels the arm bones own (cells that land together keep the one nearest the hand, so the
  claws stay at the tip);
- the arm bones' heads and tails in the .rig.json, which also gets "lock_wrist": true (the hand is
  held in line with the forearm: BipedSwing.hold_wrists) and "arm_length" (KaijuClips.fit lets the
  baked clips keep driving the moved elbows and wrists);
- the listed Blender skin's positions weighted mostly to an arm bone (.skinw, via kvox_cell_to_skin),
  so the baked weights still match the shorter arm.
Run once per asset: running it again shortens again.
"""
import json
import struct
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
from bake import skin_files  # noqa: E402

KDIR = Path("assets/kaiju")
HAND_KEEP = 0.6
SIDES = ("l", "r")


def axes(rig, factor):
    """{side: (shoulder, unit axis, bone indices, (wrist distance, arm scale, hand scale))} in .kvox
    cell units."""
    bones = rig["bones"]
    out = {}
    for side in SIDES:
        names = [f"arm_{side}{i}" for i in range(3)]
        idx = [i for i, b in enumerate(bones) if b["name"] in names]
        if len(idx) != 3:
            continue
        by = {b["name"]: b for b in bones}
        s = np.array(by[names[0]]["head"], float)
        t = np.array(by[names[2]]["tail"], float)
        axis = (t - s) / np.linalg.norm(t - s)
        total = np.linalg.norm(t - s)
        wrist = (np.array(by[names[2]]["head"], float) - s) @ axis
        hand = HAND_KEEP * (total - wrist)
        out[side] = (s, axis, idx, (wrist, (factor * total - hand) / wrist, HAND_KEEP))
    return out


def squash(p, shoulder, axis, scales):
    """Points p (n x 3) moved along the axis: up to the wrist times the arm scale, past it the
    hand scale; nothing behind the shoulder moves."""
    wrist, arm, hand = scales
    along = (p - shoulder) @ axis
    past = np.maximum(along, 0.0)
    new = np.where(past <= wrist, past * arm, wrist * arm + (past - wrist) * hand)
    return p + np.outer(new - past, axis), along


def shorten_kvox(path, sides):
    data = bytearray(path.read_bytes())
    assert data[:4] == b"KVOX" and struct.unpack_from("<I", data, 4)[0] >= 2, path
    assert struct.unpack_from("<H", data, 8)[0] == 1, "one pose only"
    n, off = struct.unpack_from("<I", data, 14)[0], 18
    dt = np.dtype([("x", "<i2"), ("y", "<i2"), ("z", "<i2"), ("r", "u1"), ("g", "u1"), ("b", "u1"), ("f", "u1")])
    rec = np.frombuffer(bytes(data[off : off + n * dt.itemsize]), dtype=dt).copy()
    keep = np.ones(n, bool)
    for shoulder, axis, idx, scales in sides.values():
        mine = np.isin(rec["f"], idx)
        p = np.c_[rec["x"][mine], rec["y"][mine], rec["z"][mine]].astype(float)
        moved, along = squash(p, shoulder, axis, scales)
        cells = np.rint(moved).astype(int)
        rows = np.nonzero(mine)[0]
        best = {}
        for row, cell, a in zip(rows, map(tuple, cells), along):
            if cell not in best or a > best[cell][1]:
                best[cell] = (row, a)
        winners = {row for row, _ in best.values()}
        for row, cell in zip(rows, cells):
            rec["x"][row], rec["y"][row], rec["z"][row] = cell
            keep[row] = row in winners
    rec = rec[keep]
    struct.pack_into("<I", data, 14, len(rec))
    path.write_bytes(bytes(data[:off]) + rec.tobytes() + bytes(data[off + n * dt.itemsize :]))
    return n, len(rec)


def shorten_rig(path, rig, sides, factor):
    for b in rig["bones"]:
        for side, (shoulder, axis, _, scales) in sides.items():
            if b["name"].startswith(f"arm_{side}"):
                for key in ("head", "tail"):
                    moved, _ = squash(np.array([b[key]], float), shoulder, axis, scales)
                    b[key] = [round(float(v), 2) for v in moved[0]]
    rig["lock_wrist"] = True
    rig["arm_length"] = round(rig.get("arm_length", 1.0) * factor, 3)
    path.write_text(json.dumps(rig, indent=1) + "\n", encoding="utf-8", newline="\n")


def shorten_skin(meta_path, weights_path, sides):
    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    m = np.array(meta["kvox_cell_to_skin"], float)
    to_skin = lambda c: (np.c_[c, np.ones(len(c))] @ m.T)[:, :3]  # noqa: E731
    from_skin = lambda p: (np.c_[p, np.ones(len(p))] @ np.linalg.inv(m).T)[:, :3]  # noqa: E731
    raw = bytearray(weights_path.read_bytes())
    assert raw[:4] == b"KSKW", weights_path
    count = struct.unpack_from("<I", raw, 8)[0]
    dt = np.dtype([("p", "<f4", 3), ("b", "u1", 4), ("w", "<f4", 4)])
    rec = np.frombuffer(bytes(raw[14 : 14 + count * dt.itemsize]), dtype=dt).copy()
    game = [b["game"] for b in meta["bones"]]
    top = rec["b"][np.arange(count), np.argmax(rec["w"], axis=1)]
    for side, (shoulder, axis, _, scales) in sides.items():
        arm = np.array([g.startswith(f"arm_{side}") for g in game] + [False])  # 255 = no bone
        mine = arm[np.minimum(top, len(game))]
        moved, _ = squash(from_skin(rec["p"][mine].astype(float)), shoulder, axis, scales)
        rec["p"][mine] = to_skin(moved).astype(np.float32)
        for b in meta["bones"]:
            if b["game"].startswith(f"arm_{side}"):
                for key in ("head", "tail"):
                    cell = from_skin(np.array([b[key]], float))
                    b[key] = [round(float(v), 4) for v in to_skin(squash(cell, shoulder, axis, scales)[0])[0]]
        print(f"skin: {mine.sum()} arm_{side} positions moved")
    raw[14 : 14 + count * dt.itemsize] = rec.tobytes()
    weights_path.write_bytes(bytes(raw))
    meta_path.write_text(json.dumps(meta, indent=1) + "\n", encoding="utf-8", newline="\n")


def main():
    name, factor = sys.argv[1], float(sys.argv[2])
    rig_path = KDIR / f"{name}.rig.json"
    rig = json.loads(rig_path.read_text(encoding="utf-8"))
    sides = axes(rig, factor)
    files = skin_files(KDIR, name)  # before the rig changes: the listing does not depend on it
    before, after = shorten_kvox(KDIR / f"{name}.kvox", sides)
    print(f"{name}.kvox: {before} -> {after} voxels")
    shorten_rig(rig_path, rig, sides, factor)
    if files:
        shorten_skin(files[0], files[1], sides)


if __name__ == "__main__":
    main()
