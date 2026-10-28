"""D-374 corrective helper joints, reference model (numpy; the torch fit opt3.py, the Blender bake and the game driver
must all match this). Helper k of bone pair (a, b), per frame, from the rest->posed transforms A = G_a IB_a, B = G_b IB_b:
  Ra, Rb = rotations of A, B;  r = rotvec(Ra^T Rb)  (b's turn relative to a, vs rest; in a's frame)
  R = Ra expmap(frac r)          (frac 0 for a 'single' helper: it turns with a)
  t = (A c + B c) / 2            (c = rest pivot)
  push = D1 r + d (1 - cos|r|) / 2   (helper frame)
  M = [R | t - R c + R push]     (rest -> posed; bind = identity)
Weights: pair helper takes g = share_v * min(w_a, w_b) from BOTH a and b (gets 2 g); single helper ('belly') takes
g = share_v * w_a (within BR of the hip) from a only (gets g). CLEAN: on verts with shin >= CLEAN, pelvis/lumbar0/lumbar1
weight moves to the shin first (weight bleed below the knee)."""
import json, numpy as np
from scipy.spatial.transform import Rotation as Rot
from helpers import rot_of

SINGLE = {"belly"}


def clean(W, n, thr):
    W = W.copy()
    if not thr: return W
    for sd in "lr":
        sh = n.index("shin_" + sd); m = W[:, sh] >= thr
        for jn in ("pelvis", "lumbar0", "lumbar1"):
            j = n.index(jn); W[m, sh] += W[m, j]; W[m, j] = 0
    return W


def helper_M(A, B, frac, c, d, D1, pushq=False):
    Ra, Rb = rot_of(A), rot_of(B); r = Rot.from_matrix(Ra.T @ Rb).as_rotvec()
    R = Ra @ Rot.from_rotvec(frac * r).as_matrix(); ch = np.r_[c, 1]; t = 0.5 * ((A @ ch)[:3] + (B @ ch)[:3])
    g = (1 - np.cos(np.linalg.norm(r))) / 2
    push = (np.asarray(D1) @ r + np.asarray(d)) * g if pushq else np.asarray(D1) @ r + np.asarray(d) * g
    M = np.eye(4); M[:3, :3] = R; M[:3, 3] = t - R @ c + R @ push; return M


def load_specs(paths):
    """opt3 jsons (one per side) -> list of helper dicts with name, kind, a, b, frac, c, d, D1, verts, share."""
    out = []
    for p in paths:
        j = json.load(open(p))
        for k, h in zip(j["kinds"], j["helpers"]):
            out.append(dict(top=j.get("top"), nj=j.get("nj"), spec=p, pushq=bool(j.get("pushq")), clean=(np.array(j["clean"]) if j.get("clean") else None), name="%s_%s" % (k, j["side"]), kind=k, a=h["a"], b=h["b"], frac=0.0 if k in SINGLE else h["frac"],
                            c=np.array(h["c"]), d=np.array(h["d"]), D1=np.array(h["D1"]), verts=np.array(j["verts"]), share=np.array(h["share"])))
    return out


def weights(W0, n, specs, hipr=None):
    """W0 (already cleaned) -> W with one column per helper (normalised)."""
    W = W0.copy(); cols = []
    for h in specs:
        a, b = n.index(h["a"]), n.index(h["b"]); sh = np.zeros(len(W0)); sh[h["verts"]] = h["share"]
        if h["kind"] in SINGLE:
            g = sh * W0[:, a] * h["mask"]; W[:, a] -= g; cols.append(g)
        else:
            g = sh * np.minimum(W0[:, a], W0[:, b]); W[:, a] -= g; W[:, b] -= g; cols.append(2 * g)
    W = np.c_[np.clip(W, 0, None), np.array(cols).T]; W = W / W.sum(1, keepdims=True)
    # opt3 fixed top-K support (the mask the fit was scored with): zero what the fit did not keep, per side's verts
    NJ = W0.shape[1]; done = set()
    for i, h in enumerate(specs):
        if h.get("top") is None or h["spec"] in done: continue
        done.add(h["spec"]); blk = [k for k, x in enumerate(specs) if x["spec"] == h["spec"]]
        keep = np.zeros((len(h["verts"]), W.shape[1]), bool); keep[:, NJ:] = True; keep[:, [NJ + k for k in blk]] = False
        import game_proxy   # a kept game bone keeps every Cascadeur bone merged into it (ungameified W, mk_helpers)
        own = list(range(NJ))
        for ch in game_proxy.CHAINS:
            for x in ch[1:]:
                if x in n: own[n.index(x)] = n.index(ch[0])
        for x, to in game_proxy.FOLD.items():
            if x in n: own[n.index(x)] = n.index(to)
        own = np.array(own)
        for r, cs in enumerate(h["top"]):
            for c in cs:
                if c < NJ: keep[r, :NJ] |= own == c
                else: keep[r, NJ + blk[c - NJ]] = True
        W[h["verts"]] *= keep; W[h["verts"]] /= W[h["verts"]].sum(1, keepdims=True)
    return W


def learned_clean(W, n, specs):
    """Per-vertex learned clean (opt3 LCL): fraction m_v of pelvis+lumbar0+lumbar1 weight moves to the shin."""
    W = W.copy(); done = set()
    for h in specs:
        sd = h["name"][-1]
        if h["clean"] is None or sd in done: continue
        done.add(sd); m = np.zeros(len(W)); m[h["verts"]] = h["clean"]; sh = n.index("shin_" + sd)
        for jn in ("pelvis", "lumbar0", "lumbar1"):
            j = n.index(jn); t = W[:, j] * m; W[:, j] -= t; W[:, sh] += t
    return W


def add(sk, specs, W0c, BR=5.0, zero_push=False):
    """sk (cload) -> sk with helper joints appended (names, G, IB = I, W) for regions.measure."""
    n = list(sk["names"]); Pb = (sk["BS"] @ sk["P"].T).T[:, :3]
    for h in specs:
        hipc = np.linalg.inv(sk["IB"][n.index("thigh_" + h["name"][-1])])[:3, 3]
        h["mask"] = (np.linalg.norm(Pb - hipc, axis=1) < BR).astype(float)
    W0c = learned_clean(W0c, n, specs); W = weights(W0c, n, specs); G = sk["G"]; NF = len(G); IB = list(sk["IB"]); Gx = [G]
    for h in specs:
        a, b = n.index(h["a"]), n.index(h["b"])
        Gh = np.array([helper_M(G[f][a] @ sk["IB"][a], G[f][b] @ sk["IB"][b], h["frac"], h["c"], 0 * h["d"] if zero_push else h["d"], 0 * h["D1"] if zero_push else h["D1"], h["pushq"]) for f in range(NF)])
        Gx.append(Gh[:, None]); IB.append(np.eye(4)); n.append(h["name"])
    return dict(sk, names=n, G=np.concatenate(Gx, 1), IB=np.array(IB), W=W)
