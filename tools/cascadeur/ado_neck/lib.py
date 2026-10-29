"""Adult r12l hip-seam skin fix (croc-young-casc, 10-28): candidate weight edits + the skin_check measure (offline LBS)."""
import sys, json, numpy as np
sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_young/knee"); import skin_check as sc
from scipy.spatial import cKDTree
CASES = {"ad_walk": (27, 246), "ad_hlt": (6, 110), "ado_walk": (7, 77), "ado_hlt": (7, 77)}
J = {t: json.load(open(sc.K + "skinj_%s.json" % t)) for t in CASES}
def sw(n): return n[:-2] + ("_r" if n.endswith("_l") else "_l") if n[-2:] in ("_l", "_r") else n

def evaluate(rig, W, tags=("ad_walk", "ad_hlt"), vol=True):
    W0 = rig["W"]; rig["W"] = W; out = {}
    try:
        for tag in tags:
            fr = CASES[tag]; cache = {}; res = {}
            for f in sorted(set(list(fr) + list(range(0, J[tag]["NF"], 3)))):
                M = sc.pose_mats(rig, J[tag], f, "cols"); X = sc.skin(rig, M)
                res[f] = {s: sc.measure(rig, M, X, s, cache, vol and f in fr) for s in "lr"}
            out[tag] = {s: {"flips": max(r[s]["flips"] for r in res.values()), "at": max(res, key=lambda f: res[f][s]["flips"]),
                            "vol": min(res[f][s]["vol"] for f in fr), "edges": max(r[s]["edges_over"] for r in res.values())} for s in "lr"}
    finally:
        rig["W"] = W0
    return out

def ring_adj(T, n):
    import scipy.sparse as sp
    E = np.r_[T[:, [0, 1]], T[:, [1, 2]], T[:, [2, 0]]]
    A = sp.coo_matrix((np.ones(len(E)), (E[:, 0], E[:, 1])), shape=(n, n)); A = ((A + A.T) > 0).astype(float).tocsr(); return A

def mirror_weights(rig, src="l", region=None, k=4):
    """Target-side verts in region get the src side's weights sampled at their mirror point (IDW of k nearest src verts), bones swapped."""
    V, W, gn = rig["V"], rig["W"], rig["gn"]; P = np.array([gn.index(sw(n)) for n in gn])
    srcside = np.sign(V[:, 2]) == (-1 if src == "l" else 1)   # thigh_l at z -4.5
    Vm = V.copy(); Vm[:, 2] *= -1
    t = cKDTree(V[srcside]); si = np.where(srcside)[0]
    d, i = t.query(Vm[region], k=k); w = 1 / np.maximum(d, 1e-4) ** 2; w /= w.sum(1, keepdims=True)
    Ws = (W[si[i]] * w[:, :, None]).sum(1)[:, P]
    W2 = W.copy(); W2[region] = Ws; return normcap(W2), d[:, 0]

def normcap(W, cap=4):
    W = W.copy(); o = np.argsort(-W, 1)[:, cap:]; np.put_along_axis(W, o, 0, 1); W[W < 1e-4] = 0
    return W / W.sum(1, keepdims=True)

def smooth_pair(rig, W, a, b, rings=2, iters=None, lam=0.5):
    """Laplacian-smooth the split between bones a and b over the seam band grown by `rings` rings; the pair's total per vert kept."""
    T = rig["T"]; n = len(W); A = ring_adj(T, n); gn = rig["gn"]; ia, ib = gn.index(a), gn.index(b)
    seam = (W[:, ia] > 1e-3) & (W[:, ib] > 1e-3); band = seam.copy()
    for _ in range(rings): band = band | (A @ band.astype(float) > 0)
    tot = W[:, ia] + W[:, ib]; band &= tot > 1e-3
    f = np.where(tot > 1e-9, W[:, ia] / np.maximum(tot, 1e-9), 0); deg = np.asarray(A.sum(1)).ravel()
    for _ in range(iters or rings * 2):
        nb = (A @ (f * (tot > 1e-3))) / np.maximum(A @ (tot > 1e-3).astype(float), 1e-9)
        f = np.where(band, (1 - lam) * f + lam * nb, f)
    W2 = W.copy(); W2[:, ia] = np.where(band, f * tot, W[:, ia]); W2[:, ib] = np.where(band, (1 - f) * tot, W[:, ib])
    return normcap(W2), band.sum()

def cross_thigh(rig, W):
    V, gn = rig["V"], rig["gn"]; pe = gn.index("pelvis"); W = W.copy(); n = 0
    for s, o in (("l", "r"), ("r", "l")):
        j = gn.index("thigh_" + o); side = np.sign(V[:, 2]) == (-1 if s == "l" else 1)
        m = side & (W[:, j] > 0); n += m.sum(); W[m, pe] += W[m, j]; W[m, j] = 0
    return W, n
