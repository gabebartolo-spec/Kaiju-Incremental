"""Corrective helper joints (D-374, Colossus hip + knee), prototyped on Cascadeur's own deformer data.
A helper for a bone pair (a, b) turns by slerp(Ra, Rb, frac); its pivot c (rest) lands where the pair's average puts it
(0.5 (A c + B c)); then it pushes by push(theta) * d (d in the helper's own frame, theta = b's turn relative to a, push =
(1 - cos theta) / 2). Rest: theta 0, no push, so the bind is unchanged.
Weights: each vert gives share * min(wa, wb) from both bones to the helper (2 * min * share in all).
add_helpers(sk, spec, W) -> sk with extra names/G/IB/W columns (regions.measure measures it)."""
import numpy as np
from scipy.spatial.transform import Rotation as Rot, Slerp


def rot_of(M):
    U, _, Vt = np.linalg.svd(M[:3, :3]); R = U @ Vt
    if np.linalg.det(R) < 0: U[:, -1] *= -1; R = U @ Vt
    return R


def helper_G(Ga, Gb, Ba, Bb, frac, c, d):
    """Ga, Gb posed globals; Ba, Bb bind globals; c rest pivot (cm); d push (cm, helper frame at full turn)."""
    A = Ga @ np.linalg.inv(Ba); B = Gb @ np.linalg.inv(Bb)            # rest -> posed transforms
    Ra, Rb = rot_of(A), rot_of(B)
    R = Slerp([0, 1], Rot.from_matrix([Ra, Rb]))([frac]).as_matrix()[0]
    ch = np.r_[c, 1]; tgt = 0.5 * ((A @ ch)[:3] + (B @ ch)[:3])
    rel = Ra.T @ Rb; th = np.arccos(np.clip((np.trace(rel) - 1) / 2, -1, 1)); push = (1 - np.cos(th)) / 2
    M = np.eye(4); M[:3, :3] = R; M[:3, 3] = tgt - R @ c + R @ (push * np.asarray(d))
    return M                                                             # rest -> posed transform of the helper


def add_helpers(sk, spec, W):
    """spec: list of dict(a=, b=, frac=0.5, share=1.0, d=(0,0,0), name=, sel=None (vert mask or None)).
    Helper bind = identity (its G is already rest -> posed), so IB = I and G = transform."""
    n = list(sk["names"]); G = sk["G"]; IB = list(sk["IB"]); W = W.copy(); bind = [np.linalg.inv(I) for I in sk["IB"]]
    Gx = [G]; cols = []
    for h in spec:
        ia, ib = n.index(h["a"]), n.index(h["b"])
        give = h.get("share", 1.0) * np.minimum(W[:, ia], W[:, ib])
        if h.get("sel") is not None: give = give * h["sel"]
        Pb = (sk["BS"] @ sk["P"].T).T[:, :3]
        c = (Pb * give[:, None]).sum(0) / max(give.sum(), 1e-9) if "c" not in h else np.asarray(h["c"])
        W[:, ia] -= give; W[:, ib] -= give; cols.append(2 * give)
        Gh = np.array([helper_G(G[f][ia], G[f][ib], bind[ia], bind[ib], h.get("frac", 0.5), c, h.get("d", (0, 0, 0))) for f in range(len(G))])
        Gx.append(Gh[:, None]); IB.append(np.eye(4)); n.append(h["name"]); h["c_used"] = c
    W = np.c_[W, np.array(cols).T] if cols else W
    return dict(sk, names=n, G=np.concatenate(Gx, 1), IB=np.array(IB), W=W / W.sum(1, keepdims=True))
