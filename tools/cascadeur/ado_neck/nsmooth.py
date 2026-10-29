"""nsmooth.py: ado neck0/neck1 weight patch for slam_stop f35-39 (y8). Seed = verts of neck tris that flip/collapse on
TAG, grown RING rings; Laplacian-smooth their weights IT times (neighbours fixed outside the patch), top4 + renorm.
Scores ntable regions (head + neck0/neck1) on every clip in CLIPS with y8 weights vs patched. env RING IT A OUT"""
import os, sys
sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_young/skinfix")
import numpy as np, regions
from cascflip import cload, cskin
from regions import tri, polar
E = os.environ.get; RING = int(E("RING", "2")); IT = int(E("IT", "20")); A = float(E("A", "0.5"))
regions.REG = {"head": regions.REG["head"], "neck": ("neck0", "neck1")}
sk = cload("ado_y8_slam"); n = list(sk["names"]); W0 = sk["W"].copy(); T = sk["T"]
NK = [n.index(x) for x in ("chest", "neck0", "neck1", "neck2", "head")]
# seed: neck-region tris bad on any frame 30-45
bind = np.array([np.linalg.inv(I) for I in sk["IB"]]); _, Pb = cskin(sk, bind); n0, a0 = tri(Pb, T)
dom = W0[T].sum(1).argmax(1); neckt = np.isin(dom, [n.index("neck0"), n.index("neck1")]) & (a0 > 1e-6 * a0.max())
bad = np.zeros(len(T), bool)
for f in range(30, 46):
    X = cskin(sk, sk["G"][f])[0]; n1, a1 = tri(X, T)
    R = np.array([polar((sk["G"][f][j] @ sk["IB"][j])[:3, :3]) for j in range(len(n))])
    d = np.einsum("ij,ij->i", np.einsum("tij,tj->ti", R[dom], n0), n1)
    bad |= neckt & ((d < 0) | (a1 < regions.COLLAPSE * a0))
m = np.zeros(len(W0), bool); m[T[bad].ravel()] = True; print("bad tris", int(bad.sum()), "seed verts", int(m.sum()))
for _ in range(RING):
    g = m.copy(); g[T[m[T].any(1)].ravel()] = True; m = g
print("patch verts", int(m.sum()))
nb = [set() for _ in range(len(W0))]
for a, b, c in T: nb[a] |= {b, c}; nb[b] |= {a, c}; nb[c] |= {a, b}
idx = np.where(m)[0]; nbl = [np.array(sorted(nb[i])) for i in idx]
W = W0.copy()
for _ in range(IT):
    Wn = W.copy()
    for k, i in enumerate(idx): Wn[i] = (1 - A) * W[i] + A * W[nbl[k]].mean(0)
    W = Wn
# top4 + renorm
o = np.argsort(-W, 1); W[np.arange(len(W))[:, None], o[:, 4:]] = 0; W /= W.sum(1, keepdims=True)
print("max weight change %.3f" % np.abs(W - W0).max())
if E("OUT"): np.savez(E("OUT"), W=W)
for t in sys.argv[1:]:
    s = cload(t); res = []
    for Wx in (W0, W):
        o_ = regions.measure(dict(s, W=Wx), Wreg=W0); bb = np.array([[r[1] + r[2] for r in o_[k]] for k in ("head", "neck")]).sum(0)
        res.append("%d@f%d (>6:%d)" % (bb.max(), bb.argmax(), (bb > 6).sum()))
    print("%-16s y8 %s -> patched %s" % (t, res[0], res[1]), flush=True)
