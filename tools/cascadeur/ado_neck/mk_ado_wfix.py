"""mk_ado_wfix.py in.npz out.npz: adolescent ya7 neck/head weight fit (adow_*.npz, Cascadeur order) -> WFIX npz for
fbx_r12m.py (groups = the ya7 mesh's vertex groups, W in the ya7 mesh's vertex order, V = rest verts for the order check)."""
import sys, numpy as np, lib
from cascflip import cload
from scipy.spatial import cKDTree
src, out = sys.argv[1:3]
base = cload("ado_slam"); n = list(base["names"]); W = np.load(src)["W"]
rig = lib.sc.rigs["ado"]; gn = [str(g) for g in rig["gn"]]; Pb = (base["BS"] @ base["P"].T).T[:, :3]
dd, perm = cKDTree(Pb).query(rig["V"]); assert len(set(perm)) == len(perm) and dd.max() < 1e-3, dd.max()
miss = [g for g in gn if g not in n]; extra = [x for x in n if x not in gn and W[:, n.index(x)].max() > 0]
print("groups", len(gn), "missing in casc", miss, "casc bones with weight not in groups", extra)
Wr = W[perm][:, [n.index(g) for g in gn]]; print("row sum min %.4f max %.4f" % (Wr.sum(1).min(), Wr.sum(1).max()))
W0r = base["W"][perm][:, [n.index(g) for g in gn]]; print("verts changed", int((np.abs(Wr - W0r).max(1) > 1e-6).sum()), "plain row check %.2e" % np.abs(W0r - rig["W"]).max())
np.savez(out, groups=np.array(gn), W=Wr, V=np.load(lib.sc.K + "skin_ya7.npz")["V"])
print("wrote", out)
