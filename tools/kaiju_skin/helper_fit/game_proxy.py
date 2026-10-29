"""game_proxy.py: a Cascadeur dump (cload) as the GAME skins it (croc_adult3_clips.py world_pose + bake.py top3):
merged chains move as one game bone (spine1 = lumbar0+lumbar1, head0 = neck0..2: the first bone's turn, then a swing so
the chain's end lands on its joint; every other game bone = its Cascadeur joint), weights summed per game bone; top3()
then keeps 3 bones per vertex with u8 weights like bake.py. gameify(sk) -> sk with G (each member = the game bone's
rest->posed) and W (merged into the chain's first column, others 0)."""
import numpy as np
from scipy.spatial.transform import Rotation as Rot

# merged chain -> its end joint (the next joint along the chain, whose head is the chain's tail)
CHAINS = {("lumbar0", "lumbar1"): "chest", ("neck0", "neck1", "neck2"): "head"}
FOLD = {"lid_up_l": "head", "lid_lo_l": "head", "lid_up_r": "head", "lid_lo_r": "head"}   # export folds lids into head


def _swing(u, v):
    u = u / np.linalg.norm(u); v = v / np.linalg.norm(v); ax = np.cross(u, v); s = np.linalg.norm(ax); c = float(u @ v)
    if s < 1e-12: return np.eye(3)
    return Rot.from_rotvec(ax / s * np.arctan2(s, c)).as_matrix()


def gameify(sk):
    n = list(sk["names"]); G = sk["G"].copy(); IB = sk["IB"]; W = sk["W"].copy(); NF = len(G)
    rest_head = {x: np.linalg.inv(IB[i])[:3, 3] for i, x in enumerate(n)}
    for chain, end in CHAINS.items():
        f = n.index(chain[0]); e = n.index(end)
        for k in range(NF):
            A = G[k][f] @ IB[f]; R0 = A[:3, :3]
            h = (G[k][f])[:3, 3]; t = (G[k][e])[:3, 3]                       # posed head of first, posed chain tail
            rd = rest_head[end] - rest_head[chain[0]]
            R = _swing(R0 @ rd, t - h) @ R0
            M = np.eye(4); M[:3, :3] = R; M[:3, 3] = h - R @ rest_head[chain[0]]
            for x in chain: G[k][n.index(x)] = M @ np.linalg.inv(IB[n.index(x)])
        for x in chain[1:]: W[:, f] += W[:, n.index(x)]; W[:, n.index(x)] = 0
    for x, to in FOLD.items():
        if x in n:
            j, t = n.index(x), n.index(to); W[:, t] += W[:, j]; W[:, j] = 0; G[:, j] = G[:, t] @ IB[t] @ np.linalg.inv(IB[j])
    return dict(sk, G=G, W=W)


def top3(W):
    """bake.py top3: 3 biggest per vertex, renormalised, first two quantised to u8, third = the rest."""
    top = np.argsort(-W, 1)[:, :3]; tw = np.take_along_axis(W, top, 1); tw = tw / np.maximum(1e-9, tw.sum(1, keepdims=True))
    q = np.round(tw[:, :2] * 255); q[:, 1] = np.minimum(q[:, 1], 255 - q[:, 0]); q = q / 255.0
    out = np.zeros_like(W); np.put_along_axis(out, top, np.c_[q, 1 - q.sum(1)], 1); return out
