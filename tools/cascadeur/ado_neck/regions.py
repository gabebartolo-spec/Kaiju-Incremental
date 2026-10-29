"""Region deformation measure on Cascadeur's own skin data (croc-young-casc, 10-28, director verdicts on Colossus drafts).
Every frame of a cdump: posed skin x = sum_j w_j G_j(f) IB_j BS p. Per region (tris by dominant joint):
  head = neck2/head/jaw/lids; leg_l, leg_r = thigh+shin per side.
  flips: posed normal vs the dominant joint's rigid turn of the rest normal, dot < 0.
  collapsed: posed area < COLLAPSE x rest area.  stretch: worst edge length change %.
python regions.py tag [tag...]   (optional  tag=weights.npz  to swap in other weights: npz with W (nv x 41) in Cascadeur order)"""
import sys, numpy as np
from cascflip import cload, cskin
D = "C:/Users/DANTE/cascadeur_bridge/croc_young/skinfix/"
COLLAPSE = 0.10
CREASE = 60.0
REG = {"head": ("neck2", "head", "jaw", "lid_up_l", "lid_lo_l", "lid_up_r", "lid_lo_r"),
       "leg_l": ("thigh_l", "shin_l"), "leg_r": ("thigh_r", "shin_r")}


def polar(M):
    U, _, Vt = np.linalg.svd(M); R = U @ Vt
    if np.linalg.det(R) < 0: U[:, -1] *= -1; R = U @ Vt
    return R


def tri(X, T):
    n = np.cross(X[T[:, 1]] - X[T[:, 0]], X[T[:, 2]] - X[T[:, 0]]); a = np.linalg.norm(n, axis=1)
    return n / np.maximum(a, 1e-12)[:, None], a


def measure(sk, frames=None, W=None, Wreg=None):
    Wr = sk["W"] if Wreg is None else Wreg   # regions from these weights (fixed across candidates)
    if W is not None: sk = dict(sk, W=W)
    T, names = sk["T"], sk["names"]; G = sk["G"]; NF = len(G)
    bind = np.array([np.linalg.inv(I) for I in sk["IB"]])
    X0, Pb = cskin(sk, bind); n0, a0 = tri(Pb, T)
    dom = sk["W"][T].sum(1).argmax(1); ok = a0 > 1e-6 * a0.max()
    E = np.unique(np.sort(np.r_[T[:, [0, 1]], T[:, [1, 2]], T[:, [2, 0]]], 1), axis=0)
    l0 = np.linalg.norm(Pb[E[:, 0]] - Pb[E[:, 1]], axis=1)
    vdom = Wr.argmax(1); domr = Wr[T].sum(1).argmax(1)
    # interior edges and their two tris (for the crease measure: dihedral fold change over CREASE deg vs rest)
    from collections import defaultdict
    et = defaultdict(list)
    for t, (a, b, c) in enumerate(T):
        for u, v in ((a, b), (b, c), (c, a)): et[(min(u, v), max(u, v))].append(t)
    EP = np.array([ts for ts in et.values() if len(ts) == 2]); EV = np.array([k for k, ts in et.items() if len(ts) == 2])
    c0 = np.einsum("ij,ij->i", n0[EP[:, 0]], n0[EP[:, 1]])
    rc = {r: np.isin(vdom[EV], [names.index(b) for b in bs]).any(1) & ok[EP].all(1) for r, bs in REG.items()}
    rt = {r: np.isin(domr, [names.index(b) for b in bs]) & ok for r, bs in REG.items()}
    re = {r: np.isin(vdom[E], [names.index(b) for b in bs]).all(1) & (l0 > 1e-4) for r, bs in REG.items()}
    out = {r: [] for r in REG}
    for f in (frames if frames is not None else range(NF)):
        X = cskin(sk, G[f])[0]; n1, a1 = tri(X, T)
        R = np.array([polar((G[f][j] @ sk["IB"][j])[:3, :3]) for j in range(len(names))])
        ref = np.einsum("tij,tj->ti", R[dom], n0); dots = np.einsum("ij,ij->i", ref, n1)
        dl = np.linalg.norm(X[E[:, 0]] - X[E[:, 1]], axis=1) / np.maximum(l0, 1e-9) - 1
        c1 = np.einsum("ij,ij->i", n1[EP[:, 0]], n1[EP[:, 1]])
        fold = np.degrees(np.arccos(np.clip(c1, -1, 1))) - np.degrees(np.arccos(np.clip(c0, -1, 1)))
        for r in REG:
            m = rt[r]; me = re[r]
            out[r].append((f, int((m & (dots < 0)).sum()), int((m & (a1 < COLLAPSE * a0)).sum()),
                           round(100 * float(dl[me].max()), 1), round(100 * float(dl[me].min()), 1), int((rc[r] & (fold > CREASE)).sum())))
    return out


def summary(tag, out):
    s = []
    for r, rows in out.items():
        wf = max(rows, key=lambda t: (t[1] + t[2], t[5]))
        s.append("%s flips %d coll %d crease %d @f%d (clip max: flips %d coll %d crease %d)" % (
            r, wf[1], wf[2], wf[5], wf[0], max(t[1] for t in rows), max(t[2] for t in rows), max(t[5] for t in rows)))
    print("REG %-12s " % tag + " | ".join(s), flush=True)


if __name__ == "__main__":
    for a in sys.argv[1:]:
        tag, _, wn = a.partition("=")
        sk = cload(tag); W = np.load(wn)["W"] if wn else None
        summary(tag + ("+" + wn.split("/")[-1] if wn else ""), measure(sk, W=W))


def measure_X(sk, f, X, Wreg=None):
    """Same flips/collapsed/stretch/crease for given posed positions X (cskin order) at frame f."""
    Wr = sk["W"] if Wreg is None else Wreg; T, names = sk["T"], sk["names"]; G = sk["G"]
    bind = np.array([np.linalg.inv(I) for I in sk["IB"]]); _, Pb = cskin(sk, bind); n0, a0 = tri(Pb, T)
    dom = sk["W"][T].sum(1).argmax(1); domr = Wr[T].sum(1).argmax(1); ok = a0 > 1e-6 * a0.max(); vdom = Wr.argmax(1)
    E = np.unique(np.sort(np.r_[T[:, [0, 1]], T[:, [1, 2]], T[:, [2, 0]]], 1), axis=0); l0 = np.linalg.norm(Pb[E[:, 0]] - Pb[E[:, 1]], axis=1)
    n1, a1 = tri(X, T); R = np.array([polar((G[f][j] @ sk["IB"][j])[:3, :3]) for j in range(len(names))])
    dots = np.einsum("ij,ij->i", np.einsum("tij,tj->ti", R[dom], n0), n1)
    dl = np.linalg.norm(X[E[:, 0]] - X[E[:, 1]], axis=1) / np.maximum(l0, 1e-9) - 1; out = {}
    for r, bs in REG.items():
        m = np.isin(domr, [names.index(b) for b in bs]) & ok; me = np.isin(vdom[E], [names.index(b) for b in bs]).all(1) & (l0 > 1e-4)
        out[r] = (int((m & (dots < 0)).sum()), int((m & (a1 < COLLAPSE * a0)).sum()), round(100 * float(dl[me].max())), round(100 * float(dl[me].min())))
    return out
