"""Flips per leg in Cascadeur's own deformer data vs offline LBS (croc-young-casc skinfix, 10-28).
Cascadeur skin of a draft: x = sum_j w_j G_j(f) IB_j BS p, from cdump_<tag>.npz (its mesh, weights, inverse binds,
bindShape, joint global_matrix per frame). 'after' = r12m.casc's mesh/weights/binds with the draft's joint matrices.
Cascadeur's vertex order permuted onto the rig's (nearest rest vert, exact) and measured with skin_check.measure (same zone, same flip rule).
python cascflip.py tag [tag...]"""
import sys, numpy as np, lib
sc = lib.sc; D = "C:/Users/DANTE/cascadeur_bridge/croc_young/skinfix/"
def cload(tag):
    z = np.load(D + "cd/cdump_%s.npz" % tag); n = [str(x) for x in z["names"]]
    W = np.zeros((len(z["P"]), len(n))); W[z["wi"], z["wj"]] = z["ww"]
    return dict(P=z["P"], T=z["C"].reshape(-1, 3), W=W, IB=z["IB"], BS=z["BS"], names=n, G=z["G"], POS=z["POS"], ROT=z["ROT"])
def cskin(sk, G):
    Pb = (sk["BS"] @ sk["P"].T).T[:, :3] if sk["P"].shape[1] == 4 else (sk["BS"][:3, :3] @ sk["P"].T).T + sk["BS"][:3, 3]
    Ph = np.c_[Pb, np.ones(len(Pb))]; X = np.zeros((len(Pb), 3))
    for j in range(len(sk["names"])):
        w = sk["W"][:, j]
        if w.any(): X += w[:, None] * (Ph @ (G[j] @ sk["IB"][j]).T)[:, :3]
    return X, Pb
def run(tag, afters):
    st = "ado" if tag.startswith("ado") else "ad"; rig = sc.rigs[st]; dr = cload(tag)
    J = {"rot": {n: dr["ROT"][:, k] for k, n in enumerate(dr["names"])}, "pos": {n: dr["POS"][:, k] for k, n in enumerate(dr["names"])}}
    skins = {"before": dr}; skins.update({k: cload(v) for k, v in afters.items()})
    out = {}
    for lab, sk in skins.items():
        X0, Pb = cskin(sk, dr["G"][0] * 0 + np.array([np.linalg.inv(I) for I in sk["IB"]]))   # bind pose: must give Pb back
        from scipy.spatial import cKDTree
        dd, perm = cKDTree(Pb).query(rig["V"]); assert len(set(perm)) == len(perm); res = max(dd.max(), np.abs(X0 - Pb).max())
        crig = dict(rig)   # same frame (Cascadeur cm), Cascadeur's vertex order permuted onto the rig's: rig V/T, Cascadeur weights
        crig["W"] = sk["W"][perm][:, [sk["names"].index(g) for g in rig["gn"]]]
        worst = {s_: (0, -1) for s_ in "lr"}
        for f in range(0, len(dr["G"]), 3):
            M = sc.pose_mats(rig, J, f, "cols"); X = cskin(sk, dr["G"][f])[0][perm]
            for side in "lr":
                fl = sc.measure(crig, M, X, side, {}, False)["flips"]
                if fl > worst[side][0]: worst[side] = (fl, f)
        vol = {}
        for side in "lr":
            f = max(worst[side][1], 0); M = sc.pose_mats(rig, J, f, "cols"); X = cskin(sk, dr["G"][f])[0][perm]
            vol[side] = sc.measure(crig, M, X, side, {}, True)["vol"]
        # offline LBS, same poses, the npz skin (r12l / ya7 for before, r12m for after)
        ow = rig["W"] if lab == "before" else lib.W_of(sys_after[lab]); off = {s_: 0 for s_ in "lr"}
        keep = rig["W"]; rig["W"] = ow
        for f in range(0, len(dr["G"]), 3):
            M = sc.pose_mats(rig, J, f, "cols"); X = sc.skin(rig, M)
            for side in "lr": off[side] = max(off[side], sc.measure(rig, M, X, side, {}, False)["flips"])
        rig["W"] = keep
        out[lab] = (worst, vol, off)
        print("CASC %-10s %-6s bind residual %.4f cm | Cascadeur flips l %d@f%d r %d@f%d vol l %.3f r %.3f | offline flips l %d r %d" % (
            tag, lab, res, worst["l"][0], worst["l"][1], worst["r"][0], worst["r"][1], vol["l"], vol["r"], off["l"], off["r"]), flush=True)
    return out
def W_of(npz):
    z = np.load(npz); gn = [str(g) for g in z["groups"]]; rig = sc.rigs["ad"]
    W = np.zeros((len(z["V"]), len(gn))); W[z["wi"], z["wg"]] = z["ww"]; W /= W.sum(1, keepdims=True); return W[:, [gn.index(g) for g in rig["gn"]]]
lib.W_of = W_of
sys_after = {"after": D + "skin_r12m.npz"}
if __name__ == "__main__":
    for tag in sys.argv[1:]:
        run(tag, {} if tag.startswith("ado") else {"after": "r12m"})
