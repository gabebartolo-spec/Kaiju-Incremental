"""neckshot.py: head/neck skin at one frame, y8 vs y9 slam_stop (Cascadeur weights), flipped tris red."""
import sys; sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_young/skinfix")
import numpy as np, matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d.art3d import Poly3DCollection
from cascflip import cload, cskin
F = int(sys.argv[1]) if len(sys.argv) > 1 else 37
def nrm(X, T): n = np.cross(X[T[:, 1]] - X[T[:, 0]], X[T[:, 2]] - X[T[:, 0]]); return n
fig = plt.figure(figsize=(16, 14), dpi=110)
for c, tag in enumerate(["ado_y8_slam", "ado_y9_slam"]):
    sk = cload(tag); X, Pb = cskin(sk, sk["G"][F]); T = sk["T"]
    J = [sk["names"].index(n) for n in sk["names"] if n.startswith(("neck", "head", "jaw", "lid"))]
    keep = sk["W"][T][:, :, J].sum(2).max(1) > 0.3
    # the neck bar's own test (regions.measure): flip = posed normal vs the dominant joint's rigid turn of the rest
    # normal, dot < 0; collapsed = area < 0.10 x rest; only tris dominated by neck0/neck1/neck2/head/jaw/lids count
    from regions import polar
    bind = np.array([np.linalg.inv(I) for I in sk["IB"]]); Pb = cskin(sk, bind)[1]
    n0, n1 = nrm(Pb, T), nrm(X, T); a0 = np.linalg.norm(n0, axis=1); a1 = np.linalg.norm(n1, axis=1)
    dom = sk["W"][T].sum(1).argmax(1); G = sk["G"][F]
    R = np.array([polar((G[j] @ sk["IB"][j])[:3, :3]) for j in range(len(sk["names"]))])
    ref = np.einsum("tij,tj->ti", R[dom], n0); okt = a0 > 1e-6 * a0.max()
    bad = okt & np.isin(dom, J) & ~np.isin(dom, [sk["names"].index("neck2")] if False else []) & (((ref * n1).sum(1) < 0) | (a1 < 0.10 * a0))
    Tk = T[keep]; bk = bad[keep]; N = n1[keep] / (np.linalg.norm(n1[keep], axis=1, keepdims=True) + 1e-12)
    for r, (el, az) in enumerate([(10, -90), (25, -40)]):
        ax = fig.add_subplot(2, 2, 1 + c + 2 * r, projection="3d")
        L = np.array([np.cos(np.radians(el)) * np.cos(np.radians(az)), np.cos(np.radians(el)) * np.sin(np.radians(az)), np.sin(np.radians(el))])
        sh = 0.35 + 0.65 * np.abs(N @ L); col = np.c_[sh * 0.55, sh * 0.62, sh * 0.5, np.ones(len(sh))]; col[bk] = [0.9, 0.1, 0.1, 1]
        ax.add_collection3d(Poly3DCollection(X[Tk], facecolors=col, edgecolors=(0, 0, 0, 0.08), linewidths=0.2))
        P = X[np.unique(Tk)]; m, M = P.min(0), P.max(0); ctr = (m + M) / 2; h = (M - m).max() / 2
        ax.set_xlim(ctr[0] - h, ctr[0] + h); ax.set_ylim(ctr[1] - h, ctr[1] + h); ax.set_zlim(ctr[2] - h, ctr[2] + h)
        ax.view_init(el, az); ax.set_axis_off(); ax.set_box_aspect((1, 1, 1), zoom=1.9)
        ax.set_title("%s f%d  bad tris (red): %d" % ("y8 (before)" if c == 0 else "y9 (neck fix)", F, bk.sum()), fontsize=11)
plt.subplots_adjust(0, 0, 1, 0.96, 0, 0.05); out = "C:/kt/ado_neck_exp/shots/neck_y8_y9_f%d.png" % F; plt.savefig(out); print(out)
