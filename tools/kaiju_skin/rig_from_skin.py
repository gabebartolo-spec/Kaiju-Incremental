"""Rigs a rig_voxel.py .kvox with a hand-made Blender skin (tools/blender/motion_test.py export) for a
body plan rig_voxel's own skeleton fit cannot trace (the D-046 croc titan is horizontal; rig_voxel
fits upright bipeds). Writes the game's <name>.rig.json from the Blender skeleton and rewrites each
voxel's bone (the .kvox flags byte) from the Blender weights, so the rig, the rigid debug voxels
and the skin (bake.py) all turn about the same joints.

    python tools/kaiju_skin/rig_from_skin.py <name.kvox> <x.skin.json> [mouth]

mouth (optional) = "z0,y0,z1,y1": the closed mouth's tooth line in skin metres, snout end to gape
corner. A sealed Tripo mouth is one skin, so the line splits it: every head voxel in front of the
gape and under the line is jaw, every one above it skull (a straight cut: letting the nearest
welded position decide near the line combed the lips, and teeth are below voxel size). The jaw is
a rigid hinge.
Adult croc (adult3 r10, tools/blender/croc_adult3_export.py; its jaw comes from the skin weights, no mouth line):
    python tools/kaiju_skin/rig_from_skin.py assets/kaiju/reptilian_adult.kvox \\
        assets/kaiju/test/croc_adult3.skin.json
The old croc titan adult (blender-reptile 3ea955d, motion_test KNOWN["C"] mouth re-origined on the pelvis):
    python tools/kaiju_skin/rig_from_skin.py assets/kaiju/reptilian_adult.kvox \\
        assets/kaiju/test/croctitan.skin.json -90.5,82.5,-58,87
"""
import json
import struct
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake  # noqa: E402
import lid_flaps  # noqa: E402
import skin_helpers  # noqa: E402

# The game's biped bones, in rig.json order (each voxel's flags byte is an index into the list). A skin may add bones
# of its own (the adult croc r12's tail tip, D-307): they follow these (bone_names).
GAME_BONES = ["spine0", "spine1", "spine2", "head0", "head1", "arm_l0", "arm_l1", "arm_l2", "leg_l0",
              "leg_l1", "leg_l2", "arm_r0", "arm_r1", "arm_r2", "leg_r0", "leg_r1", "leg_r2"] + [
              f"tail{i}" for i in range(9)] + ["jaw"]


# A skin's own game bones in the order they were added, so a file of the earlier bones stays a prefix of the new list:
# the r12 tail tip and hind toes (D-307), then the eyelids (lid_*, D-335 blinks), then the collar bones (clavicle_l/_r,
# lead 2026-10-28 call A: the Cascadeur rise's shrug, no longer folded into spine2).
LATER = ("lid_", "clavicle_")


def extra_order(name):
    """Sort key of a skin's own game bones: by when they were added (LATER), then by chain, then by number (tail9
    before tail10: parents first). A collar bone is listed after the arm it carries (rig.json is not parents first)."""
    stem = name.rstrip("0123456789")
    late = next((i + 1 for i, p in enumerate(LATER) if name.startswith(p)), 0)
    return late, stem, int(name[len(stem):] or 0)


def bone_names(meta):
    """GAME_BONES, then any other game bone the skin names (tools/blender/croc_adult3_clips.py orders its clips' bones
    the same way)."""
    return GAME_BONES + sorted({b["game"] for b in meta["bones"]} - set(GAME_BONES), key=extra_order)


def game_rig(meta, to_rig, height):
    """rig.json bones: each game bone runs from the head of its first Blender bone to the tail of
    its last (a game bone may gather several: neck0 + neck1 = head0, meta + toe = leg_x2). Blender
    bones are listed parents first, so the first one met is the chain's root."""
    by_name = {b["name"]: b for b in meta["bones"]}
    first, last = {}, {}
    for b in meta["bones"]:
        g = b["game"]
        first.setdefault(g, b)
        # The chain's end: a bone that starts where the chain's last one ends extends it (a bone
        # folded into a game bone without continuing its chain, e.g. a side branch, starts elsewhere).
        if g not in last or (b["parent"] == last[g]["name"]
                             and np.allclose(b["head"], last[g]["tail"], atol=1e-3)):
            last[g] = b
    bones = []
    for g in bone_names(meta):
        root = first[g]
        par = by_name.get(root["parent"])
        head, tail = to_rig(np.array(root["head"])), to_rig(np.array(last[g]["tail"]))
        entry = {"name": g, "parent": par["game"] if par else None, "head": head.round(2).tolist(),
                 "tail": tail.round(2).tolist(), "physics": bool(root.get("physics"))}
        if g == "jaw":
            entry["close"] = 0.0  # the croc titan rests with its mouth shut (no snarl)
        bones.append(entry)
    return {"height": height, "type": "biped", "bones": bones}


def split_mouth(owner, pts, line):
    """The jaw: head voxels in front of the gape under the tooth line (see the module note). The neck's voxels in front
    of the gape count as the head's (the young croc rigs' neck weights reach under the jaw's back, croc-young-casc):
    in front of the gape every voxel is skull or jaw."""
    z0, y0, z1, y1 = line
    head0, head1, jaw = GAME_BONES.index("head0"), GAME_BONES.index("head1"), GAME_BONES.index("jaw")
    at = y0 + (y1 - y0) * (pts[:, 2] - z0) / (z1 - z0)
    zone = np.isin(owner, (head0, head1, jaw)) & (pts[:, 2] < z1 + 0.5)
    out = owner.copy()
    out[zone] = np.where(pts[zone, 1] < at[zone], jaw, head1)
    out[~zone & (owner == jaw)] = head1  # no jaw behind the gape
    return out


def main():
    kvox_path, meta_path = Path(sys.argv[1]), Path(sys.argv[2])
    line = [float(x) for x in sys.argv[3].split(",")] if len(sys.argv) > 3 else None
    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    m = np.array(meta["kvox_cell_to_skin"], dtype=float)
    inv = np.linalg.inv(m)
    # A cell's centre in rig units is cell + 0.5 (rig_voxel's rig.json and .kvox share one grid).
    to_rig = lambda p: (inv @ np.r_[p, 1.0])[:3] + 0.5
    data = bytearray(kvox_path.read_bytes())
    height = struct.unpack_from("<H", data, 12)[0]
    cells, rgb, before = bake.read_kvox(kvox_path)
    names = bone_names(meta)
    # The lower-lid voxels an earlier run added (only they are ever given to a lid_lo bone; a rig_voxel .kvox has none)
    # go before the skin is sampled, so a rerun rebuilds them.
    kept = ~np.isin(before, lid_flaps.lid_bones(names))
    cells, rgb = cells[kept], rgb[kept]
    helpers = skin_helpers.helpers_of(meta)  # D-374 corrective joints: weight columns after the bones (bake.py)
    w, gap = bake.sample_skin(meta_path, cells, names + [h["name"] for h in helpers])
    for k, h in enumerate(helpers):  # a voxel is rigid: a helper's share stays with the bone it rides at rest
        w[:, names.index(h["a"])] += w[:, len(names) + k]
    w = w[:, :len(names)]
    own = w.copy()
    for i in (i for i, n in enumerate(names) if n.startswith("lid_")):  # an eyelid moves its skin by the weights
        own[:, names.index("head1")] += own[:, i]  # (bake.py); the voxel stays a part of the head
        own[:, i] = 0.0
    owner = np.argmax(own, axis=1)
    if line:
        pts = (np.c_[cells, np.ones(len(cells))] @ m.T)[:, :3]
        owner = split_mouth(owner, pts, line)
    rig = game_rig(meta, to_rig, height)
    # LF on every OS: the .vskin stamp hashes these bytes and git checks them out as LF.
    out = kvox_path.with_suffix(".rig.json")
    out.write_text(json.dumps(rig, indent=1), encoding="utf-8", newline="\n")
    lid_flaps.write_kvox(kvox_path, data, cells, rgb, owner)
    lids = lid_flaps.apply(kvox_path, meta, names)  # the lid flaps, made fresh from the rigged voxels
    counts = np.bincount(owner, minlength=len(names))
    print(f"rigged {kvox_path.name} from {meta_path.name}: {len(cells)} voxels; gap to skin median "
          f"{np.median(gap):.2f} m, p95 {np.percentile(gap, 95):.2f} m; {len(names)} bones; jaw {counts[names.index('jaw')]} "
          f"voxels; fewest {names[int(np.argmin(counts))]} {counts.min()}; {lids}")


if __name__ == "__main__":
    main()
