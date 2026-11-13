"""Gives a croc stage on the adult skeleton the adult's takes as they are (D-484, "Re-rig the Behemoth"): every frame's
bone turns, root yaw and planted bits are copied unchanged from the adult .kclip; only what the body's own bone lengths
decide is rebuilt for the stage's skeleton (its <x>.skin.json, the same game bones as the adult's):
- rest_heads_m: the stage's own bone heads (KaijuClips.fit checks the clips against its rig);
- the stance: the pelvis sits lower by a constant, so the stage's legs stand as bent as the adult's, BEND_MARGIN more (hip to ankle, a
  share of the leg's length: the adolescent's stood 0.96 straight to the adult's 0.92, and every adult stride then
  pushed its leg past straight, so the game's catch steps fired on each step);
- the pelvis offset, scaled by the leg lengths (stage / adult, hip to ankle: the two bones the game's leg solver bends),
  so a crouch, a rise or a lurch keeps its share of the leg;
- both toe tips: the stage's own rest toe tip plus the adult's stored toe travel from its rest toe tip, across and
  fore-aft scaled by the leg lengths, up by the hip heights (a stomp lifts its share of the hip), so a foot the adult
  holds still stays still and a foot never reaches further than the adult's does (forward kinematics of the copied
  turns on the stage's own bone proportions slid a standing toe ~0.2 m in a stomp, and the catch step lifted it twice);
- stride_m, scaled by how far the planted toe tips travel per walk cycle on the stage's legs against the adult's.
Bones the stage's skeleton lacks (the approved croc's toe chains) are dropped. Rest toe tips and ankles come by
forward kinematics (a bone's head is its parent's head plus the parent's turn of the rest offset; the toe tip is
leg_x3's tail).
    python tools/kaiju_skin/kclip_from_adult.py <adult.kclip> <adult.skin.json> <stage.skin.json> <out.kclip>
The adult's own skin is only used to check the forward kinematics against its stored toe tips (printed)."""
import json
import struct
import sys
from pathlib import Path

import numpy as np

QS = 32767.0
CM = 0.01
## The stage stands this much more bent than the adult (share of leg length): at the adult's own bend, the standing
## turn's widest stride reached 3.063 m against a 3.038 m leg (the motion suite measured a 6.65 deg aloft yaw from the
## catch step); 0.015 deeper keeps every take inside the leg (motion: aloft yaw 0, catch 0 on every route).
BEND_MARGIN = 0.015


def read_kclip(path):
    raw = Path(path).read_bytes()
    assert raw[:4] == b"KCLP", path
    n = struct.unpack("<I", raw[8:12])[0]
    head = json.loads(raw[12:12 + n])
    return head, raw[12 + n:]


def skeleton(skin_path):
    """Game bone -> (parent game bone, head, tail) in skin metres, from a croc .skin.json (gathered skin bones)."""
    meta = json.loads(Path(skin_path).read_text())
    game = {b["name"]: b["game"] for b in meta["bones"]}
    out, order = {}, []
    for b in meta["bones"]:
        g = b["game"]
        par = game.get(b["parent"]) if b["parent"] else None
        if g not in out:
            out[g] = [par if par != g else None, np.array(b["head"], float), np.array(b["tail"], float)]
            order.append(g)
        else:
            out[g][2] = np.array(b["tail"], float)  # a gathered bone runs on to the last one's tail
    for g in out:  # a parent inside the same gather is the gather's own parent
        p = out[g][0]
        while p is not None and p == g:
            p = None
        out[g][0] = p
    return out, order


def qmul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return np.array([aw * bx + ax * bw + ay * bz - az * by, aw * by - ax * bz + ay * bw + az * bx,
                     aw * bz + ax * by - ay * bx + az * bw, aw * bw - ax * bx - ay * by - az * bz])


def qrot(q, v):
    u, w = q[:3], q[3]
    return v + 2.0 * np.cross(u, np.cross(u, v) + w * v)


def frames(head, data, bones):
    nb = len(head["bones"])
    fb = head["frame_bytes"]
    assert fb == nb * 8 + 26
    keep = [head["bones"].index(b) for b in bones]
    total = len(data) // fb
    for f in range(total):
        at = f * fb
        q = np.frombuffer(data, "<i2", nb * 4, at).reshape(nb, 4) / QS
        tail = data[at + nb * 8: at + fb]
        off = np.frombuffer(tail, "<i2", 3, 0) * CM
        feet = np.frombuffer(tail, "<i2", 6, 6).reshape(2, 3) * CM
        yield {b: q[i] / np.linalg.norm(q[i]) for b, i in zip(bones, keep)}, off, feet, tail[18:26]


def fk(turns, pelvis, skel, order):
    """Each game bone's world turn and posed head."""
    world, posed = {}, {}
    for g in order:
        par, h, _ = skel[g]
        world[g] = turns[g] if par is None else qmul(world[par], turns[g])
        posed[g] = pelvis if par is None else posed[par] + qrot(world[par], h - skel[par][1])
    return world, posed


def fk_toes(turns, pelvis, skel, order):
    world, posed = fk(turns, pelvis, skel, order)
    return [posed[f"leg_{s}3"] + qrot(world[f"leg_{s}3"], skel[f"leg_{s}3"][2] - skel[f"leg_{s}3"][1])
            for s in ("l", "r")]


def _leg(skel):
    """The left leg's length the game's solver bends: hip to ankle (leg_l0 and leg_l1)."""
    return sum(float(np.linalg.norm(skel[f"leg_l{j}"][2] - skel[f"leg_l{j}"][1])) for j in range(2))


def _bend(skel, order, bones, drop=0.0):
    """How straight the left leg stands at rest with the pelvis `drop` metres lower and the foot where it was: hip to
    ankle over the leg's length."""
    still = {g: np.array([0.0, 0.0, 0.0, 1.0]) for g in bones}
    _, posed = fk(still, skel["spine0"][1], skel, order)
    return float(np.linalg.norm(posed["leg_l2"] - posed["leg_l0"] + np.array([0.0, drop, 0.0]))) / _leg(skel)


def _drop(skel, order, bones, bend):
    """How far the pelvis sinks (metres) so the leg stands `bend` straight (bisection)."""
    lo, hi = 0.0, skel["spine0"][1][1] * 0.5
    for _ in range(50):
        mid = (lo + hi) * 0.5
        lo, hi = (mid, hi) if _bend(skel, order, bones, mid) > bend else (lo, mid)
    return lo


def walk_travel(rows, clip):
    """Mean fore-aft travel of a planted toe tip per frame over a clip (metres; the walk in place drags it back)."""
    first, n = clip["first"], clip["frames"]
    moves = []
    for f in range(first, first + n - 1):
        for i in range(2):
            bits_a, bits_b = rows[f][2], rows[f + 1][2]
            if bits_a & (1 << i) and bits_b & (1 << i):
                moves.append(rows[f + 1][1][i][2] - rows[f][1][i][2])
    return float(np.mean(moves)) if moves else 0.0


def main(adult_kclip, adult_skin, stage_skin, out):
    head, data = read_kclip(adult_kclip)
    a_skel, a_order = skeleton(adult_skin)
    s_skel, s_order = skeleton(stage_skin)
    bones = [b for b in head["bones"] if b in s_skel]
    missing = set(s_skel) - set(head["bones"])
    assert not missing, f"the adult clips lack the stage's bones {sorted(missing)}"
    dropped = [b for b in head["bones"] if b not in s_skel]
    a_rest = {b: np.array(v, float) for b, v in head["rest_heads_m"].items()}
    a_order = [g for g in a_order if g in bones]
    s_order = [g for g in s_order if g in bones]
    a_skel_k = {g: [p, a_rest[g], a_rest[g] + (t - h)] for g, (p, h, t) in a_skel.items() if g in a_rest}
    kh = s_skel["spine0"][1][1] / a_rest["spine0"][1]  # hip heights: a lift's share
    k = _leg(s_skel) / _leg(a_skel_k)  # leg lengths: a stride's and the pelvis's share
    scale = np.array([k, kh, k])
    bend = _bend(a_skel_k, a_order, bones) - BEND_MARGIN
    drop = np.array([0.0, _drop(s_skel, s_order, bones, bend), 0.0])
    still = {g: np.array([0.0, 0.0, 0.0, 1.0]) for g in bones}
    a_toe0 = fk_toes(still, a_rest["spine0"], a_skel_k, a_order)
    s_toe0 = fk_toes(still, s_skel["spine0"][1], s_skel, s_order)

    a_rows, s_rows, out_frames, worst = [], [], [], 0.0
    for turns, off, feet, rest in frames(head, data, bones):
        bits = rest[6]
        fa = fk_toes(turns, a_rest["spine0"] + off, a_skel_k, a_order)
        worst = max(worst, max(float(np.linalg.norm(fa[i] - feet[i])) for i in range(2)))
        s_off = off * k - drop
        fs = [s_toe0[i] + (feet[i] - a_toe0[i]) * scale for i in range(2)]
        a_rows.append((turns, feet, bits))
        s_rows.append((turns, fs, bits))
        buf = bytearray()
        for b in bones:
            buf += struct.pack("<4h", *[int(round(x * QS)) for x in turns[b]])
        for v in (s_off, fs[0], fs[1]):
            buf += struct.pack("<3h", *[int(round(x / CM)) for x in v])
        buf += rest  # root yaw, root travel, planted bits, pad: as the adult's
        out_frames.append(bytes(buf))
    walk = next(c for c in head["clips"] if c["name"] == "walk")
    ta, ts = walk_travel(a_rows, walk), walk_travel(s_rows, walk)
    stride = head["stride_m"] * (ts / ta if ta else k)

    new = dict(head)
    new["bones"] = bones
    new["frame_bytes"] = len(bones) * 8 + 26
    new["rest_heads_m"] = {b: [round(float(x), 3) for x in s_skel[b][1]] for b in bones}
    new["gathers"] = {b: v for b, v in head.get("gathers", {}).items() if b in bones}
    new["stride_m"] = round(stride, 3)
    new["source"] = (f"{head.get('source', '')}: the adult's takes as they are on {Path(stage_skin).name} "
                     "(tools/kaiju_skin/kclip_from_adult.py, D-484)")
    blob = json.dumps(new).encode()
    Path(out).write_bytes(b"KCLP" + struct.pack("<II", 1, len(blob)) + blob + b"".join(out_frames))
    print(f"{out}: {len(out_frames)} frames, {len(bones)} bones (dropped {dropped}), clips "
          f"{[c['name'] for c in head['clips']]}; hip ratio {kh:.3f}, leg ratio {k:.3f}, stance "
          f"{bend:.3f} straight (pelvis down {drop[1]:.2f} m), stride {head['stride_m']} -> {stride:.2f} m; "
          f"adult FK check: worst toe tip {worst:.3f} m from the stored")


if __name__ == "__main__":
    main(*sys.argv[1:5])
