"""Carries a kaiju's .kclip onto a new skeleton of the same body (croc-young-casc S5: the young crocs' rig rebuilt the
adult r12 way, D-307, with the eyelids, D-335). The game fits a clip to its rig by the rest heads (scenes/kaiju_clips.gd
fit: within 2% of the body height, else no clips), so a clip file baked on the old skeleton must carry the new one:
- each frame's local turns stay; a bone the old file lacks gets the identity turn (it rides its parent, the way
  tools/blender/croc_adult3_clips.py pads an r11 file);
- the header's bones, gathers and rest heads become the new skin's (rig_from_skin.py's bone list and chains);
- the toe tips (the clip's foot spots, which the legs reach: scenes/gait_clip.gd) move along the ground by what the
  new skeleton changes, old tip + (new - old) toe tip of the game's forward kinematics (rest bases identity: a bone's
  world turn = its parent's x its own, its head offset in the parent's turn; the pelvis offset moves the root) on each
  skeleton; their height keeps the clip's profile, shifted by the rest toe tips' height change (a planted foot stays
  on the ground). The old tips are the Blender pose's (motion_test.py), which the game's kinematics on the old
  skeleton meet only to within its gathered chains (printed; the tool stops above TOE_CHECK of the body height);
- the pelvis offset, root yaw, travel and contacts stay.
    python tools/kaiju_skin/kclip_reskeleton.py <in.kclip> <old.skin.json> <new.skin.json> <out.kclip>
"""
import json
import struct
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from rig_from_skin import bone_names  # noqa: E402

IDENTITY = (0, 0, 0, 32767)
Q16 = 32767.0
FLAT = np.array([1.0, 0.0, 1.0])  # the kinematics' change along the ground only
TOE_CHECK = 0.03  # the motion_test croc titan clips: up to ~1.9% (the gathered chains vs the Blender pose)


def chains(meta):
    """Each game bone's rest head (its first skin bone's head), tail (its chain's last bone's tail) and parent game bone,
    in the skin's frame (the clip's metres): rig_from_skin.py game_rig's rule."""
    by = {b["name"]: b for b in meta["bones"]}
    first, last = {}, {}
    for b in meta["bones"]:
        g = b["game"]
        first.setdefault(g, b)
        if g not in last or (b["parent"] == last[g]["name"] and np.allclose(b["head"], last[g]["tail"], atol=1e-3)):
            last[g] = b
    return {g: (np.array(first[g]["head"], float), np.array(last[g]["tail"], float),
                by[first[g]["parent"]]["game"] if first[g]["parent"] else None) for g in first}


def mat(q):
    x, y, z, w = q / np.linalg.norm(q)
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def toes(ch, names, q, offset):
    """World toe tips (left, right) of one frame: the tail of leg_x3 when the skeleton has it, else leg_x2."""
    rot, head = {}, {}
    def solve(n):
        if n in rot:
            return
        h, _, p = ch[n]
        r = mat(q[names.index(n)]) if n in names else np.eye(3)
        if p is None:
            rot[n], head[n] = r, h + offset
        else:
            solve(p)
            rot[n], head[n] = rot[p] @ r, head[p] + rot[p] @ (h - ch[p][0])
    out = []
    for s in "lr":
        n = f"leg_{s}3" if f"leg_{s}3" in ch else f"leg_{s}2"
        solve(n)
        out.append(head[n] + rot[n] @ (ch[n][1] - ch[n][0]))
    return out


def main():
    src, old_meta, new_meta, dst = (Path(a) for a in sys.argv[1:5])
    raw = src.read_bytes()
    assert raw[:4] == b"KCLP"
    hl = struct.unpack_from("<I", raw, 8)[0]
    h = json.loads(raw[12:12 + hl])
    body = raw[12 + hl:]
    old, fb = h["bones"], h["frame_bytes"]
    assert fb == len(old) * 8 + 26
    meta_o = json.loads(old_meta.read_text(encoding="utf-8"))
    meta_n = json.loads(new_meta.read_text(encoding="utf-8"))
    new = bone_names(meta_n)
    missing = [b for b in old if b not in new]
    assert not missing, f"bones the new skeleton lacks: {missing}"
    ch_o, ch_n = chains(meta_o), chains(meta_n)
    rest_gap = max(np.linalg.norm(np.array(h["rest_heads_m"][g]) - ch_o[g][0]) for g in old)
    assert rest_gap < 0.01, f"{src.name} was not baked on {old_meta.name} (rest heads off by {rest_gap:.3f} m)"
    nf = len(body) // fb
    toe_bone = lambda ch, s: f"leg_{s}3" if f"leg_{s}3" in ch else f"leg_{s}2"
    rise = [np.array([0.0, ch_n[toe_bone(ch_n, s)][1][1] - ch_o[toe_bone(ch_o, s)][1][1], 0.0]) for s in "lr"]
    out, worst_old, worst_move = bytearray(), 0.0, 0.0
    for f in range(nf):
        fr = body[f * fb:(f + 1) * fb]
        q = np.array(struct.unpack_from(f"<{4 * len(old)}h", fr), float).reshape(-1, 4) / Q16
        tail = fr[len(old) * 8:]
        offset = np.array(struct.unpack_from("<3h", tail, 0), float) / 100.0
        feet = np.array(struct.unpack_from("<6h", tail, 6), float).reshape(2, 3) / 100.0
        t_old = toes(ch_o, old, q, offset)
        worst_old = max(worst_old, max(np.linalg.norm(a - b) for a, b in zip(t_old, feet)))
        t_new = [ft + (n - o) * FLAT + lift for ft, n, o, lift in zip(feet, toes(ch_n, old, q, offset), t_old, rise)]
        worst_move = max(worst_move, max(np.linalg.norm(a - b) for a, b in zip(t_new, feet)))
        qs = b"".join(fr[old.index(n) * 8:(old.index(n) + 1) * 8] if n in old else struct.pack("<4h", *IDENTITY)
                      for n in new)
        cm = [int(round(c * 100.0)) for c in np.r_[t_new[0], t_new[1]]]
        out += qs + tail[:6] + struct.pack("<6h", *cm) + tail[18:]
    limit = TOE_CHECK * float(h.get("body_height_m", 100.0))
    assert worst_old < limit, f"the game's kinematics miss the old toe tips by {worst_old:.2f} m (limit {limit:.2f})"
    h.update({"bones": new, "frame_bytes": len(new) * 8 + 26,
              "gathers": {g: [b["name"] for b in meta_n["bones"] if b["game"] == g] for g in new},
              "rest_heads_m": {g: [round(float(c), 3) for c in ch_n[g][0]] for g in new},
              "source": f"{h.get('source', src.name)}; reskeleton {new_meta.name}"})
    head = json.dumps(h, separators=(",", ":")).encode()
    dst.write_bytes(b"KCLP" + struct.pack("<II", 1, len(head)) + head + bytes(out))
    print(f"RESKELETON {src.name} -> {dst.name}: {len(old)} -> {len(new)} bones, {nf} frames; the game's kinematics meet "
          f"the old toe tips within {worst_old:.2f} m; toe tips moved up to {worst_move:.2f} m by the new skeleton")


if __name__ == "__main__":
    main()
