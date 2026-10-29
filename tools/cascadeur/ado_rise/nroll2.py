"""nroll2.py DUMP_TAG SRC_KEY DST_MOVE: set neck1's roll to the chain's own (the twist-free) roll.
Measured on Cascadeur dumps (pmodel.py): neck0 and neck2 take the minimal turn from their parent to aim at the next
joint (err 0.0-0.1 deg), but neck1 takes its roll from its pole neck1_AdditionalPoint (its local x is square to the
pole offset; err vs the minimal turn up to 26 deg, swinging with the run's chest roll). neck2 inherits it and the head
does not, so the whole error lands in neck2>head (adolescent slam_stop nb180 f0-30: 7-19 flipped head tris).
Fix, per frame from DUMP_TAG (the same key keyed as is): turn the pole offset about neck1's aim axis until it is square
to the minimal-turn frame's x axis (the solution on the same side as now). The pole keeps its distance and its angle
to the aim; every other point untouched. Then nfix's side margin. Saves DST_MOVE like dk.save (DK_SUFFIX)."""
import json, math, sys
import numpy as np
sys.path[:0] = ["C:/Users/DANTE/cascadeur_bridge/croc_new/claw/drafts", "C:/Users/DANTE/cascadeur_bridge/croc_new/claw/grown_fix1",
                "C:/Users/DANTE/cascadeur_bridge/croc_young/skinfix"]
import dk  # noqa: E402
from cascflip import cload  # noqa: E402
from regions import polar  # noqa: E402
from nfix import rot, fix_frame, A  # noqa: E402
from nside import side  # noqa: E402


def u(v): return v / np.linalg.norm(v)


def rmin(a, b):
    a, b = u(a), u(b); v = np.cross(a, b); c = np.dot(a, b)
    K = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]]); return np.eye(3) + K + K @ K / (1 + c)


if __name__ == "__main__":
    tag, src, dst = sys.argv[1:4]
    sk = cload(tag); n = sk["names"]; G = sk["G"]; bind = [np.linalg.inv(I) for I in sk["IB"]]
    D = json.load(open(dk.HERE + "frames_%s.json" % src)); FR = []; turns = []; geo = []; SIG = float(sys.argv[4]) if len(sys.argv) > 4 else 2.0
    i0, i1, i2 = n.index("neck0"), n.index("neck1"), n.index("neck2")
    B0, B1 = polar(bind[i0][:3, :3]), polar(bind[i1][:3, :3]); BP1, BP2 = bind[i1][:3, 3], bind[i2][:3, 3]
    for f, fr in enumerate(D["frames"]):
        R0, R1 = polar(G[f][i0][:3, :3]), polar(G[f][i1][:3, :3]); P1, P2 = G[f][i1][:3, 3], G[f][i2][:3, 3]
        Rt = R0 @ B0.T @ B1; Rt = rmin(Rt @ (B1.T @ (BP2 - BP1)), P2 - P1) @ Rt   # minimal-turn neck1 frame
        ax = u(P2 - P1); xt = Rt[:, 0]; xa = R1[:, 0]
        p = np.asarray(fr[A], float) - P1
        # angle about ax that brings p square to xt: p(phi).xt = 0; choose the root nearest 0 keeping p's side (z sign)
        c1 = np.dot(p - ax * np.dot(p, ax), xt); c2 = np.dot(np.cross(ax, p), xt)   # p(phi).xt = c1 cos + c2 sin (+ axial 0 if xt square to ax)
        base = math.atan2(-c1, c2)   # roots: base, base + pi
        prev = math.radians(turns[-1]) if turns else 0.0   # the root that continues the last frame's turn (no pop)
        best = min((base + k * math.pi for k in range(-3, 4)), key=lambda t: abs(t - prev))
        turns.append(math.degrees(best)); geo.append((P1, ax, p))
    k = np.exp(-0.5 * (np.arange(-6, 7) / SIG) ** 2); k /= k.sum()   # Gaussian smooth of the turn (frames)
    sm = np.convolve(np.pad(turns, 6, mode="edge"), k, mode="valid")
    for fr, (P1, ax, p), t in zip(D["frames"], geo, sm):
        o = dict(fr); o[A] = tuple(round(float(c), 4) for c in P1 + rot(p, ax, float(t)))
        FR.append(fix_frame(o, 6.0)[0])
    turns = list(sm)
    PP = np.array([f[A] for f in FR]); print("pole step max %.3f cm/f" % np.linalg.norm(np.diff(PP, axis=0), axis=1).max())
    print("NROLL2 %s -> %s: pole turn about the neck1 aim max %.1f deg, mean |%.1f|; side min %+.2f" % (
        src, dst, max(abs(t) for t in turns), sum(abs(t) for t in turns) / len(turns), min(side(f) for f in FR)))
    meta = dict(D["meta"]); meta["neck1_roll_fix"] = tag
    dk.save(dst, FR, {k: v for k, v in meta.items() if k not in ("move", "stage", "NF", "fps", "rig")})
