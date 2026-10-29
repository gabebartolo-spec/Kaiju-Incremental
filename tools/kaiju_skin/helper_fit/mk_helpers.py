"""mk_helpers.py out.json spec_l.json spec_r.json [TOPK=3]: D-374 helper joints -> the Colossus export's helper file
(tools/blender/croc_adult3_helpers.json): "helpers" in skin.json space (game metres) and "verts" rows (rig vertex
index -> {bone or helper: w}) for every vertex whose weights change. Cascadeur -> skin.json is the similarity fitted
from the 37 shared joint heads (reflection allowed). Also checks the conversion: the game formula with converted
numbers equals the Cascadeur helper conjugated into skin space on every frame of ad_walk + f1_charge."""
import sys, os, json, numpy as np
from pathlib import Path
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools/kaiju_skin"))
sys.path.insert(1, os.environ.get("KAIJU_FIT_DATA", "C:/Users/DANTE/cascadeur_bridge/croc_young/skinfix"))   # lib.py: the rig mesh data (outside git)
import skin_helpers, helpers2, lib
from cascflip import cload
from scipy.spatial import cKDTree
SK = str(ROOT / "assets/kaiju/test/croc_adult3.skin.json")
out, sl, sr = sys.argv[1:4]; K = int(os.environ.get("TOPK", "3"))
meta = json.load(open(SK)); heads = {b["name"]: np.array(b["head"]) for b in meta["bones"]}; game = {b["name"]: b["game"] for b in meta["bones"]}
base = cload("r12m"); n = list(base["names"]); W0 = base["W"]
cj = {nm: np.linalg.inv(base["IB"][i])[:3, 3] for i, nm in enumerate(n)}
common = [k for k in heads if k in cj]; X = np.array([cj[k] for k in common]); Y = np.array([heads[k] for k in common])
Xh = np.c_[X, np.ones(len(X))]; A = np.linalg.lstsq(Xh, Y, rcond=None)[0].T          # 3x4 affine casc -> skin
L = A[:, :3]; s = abs(np.linalg.det(L)) ** (1 / 3); Q = L / s; det = float(np.sign(np.linalg.det(Q)))
res = np.abs(Xh @ A.T - Y).max(); orth = np.abs(Q @ Q.T - np.eye(3)).max()
print("casc->skin: joints %d scale %.5f mirror %d fit max %.4f m ortho %.2e" % (len(common), s, det, res, orth)); assert res < 0.05 and orth < 1e-3
S4 = np.eye(4); S4[:3] = A; S4i = np.linalg.inv(S4)
specs = helpers2.load_specs([sl, sr])
sk = helpers2.add(dict(base), specs, W0.copy())
W = sk["W"]
if K:  # top-K over GAME bones (merged chains count once, as bake.py sees them); keep every Cascadeur bone of a kept game bone
    grp = [game.get(x, "head1" if x.startswith("lid_") else x) for x in n] + ["hlp_" + h["name"] for h in specs]; ug = sorted(set(grp)); gi = np.array([ug.index(g) for g in grp])
    Wg = np.zeros((len(W), len(ug))); np.add.at(Wg.T, gi, W.T)
    top = np.argsort(-Wg, 1)[:, :K]; mg = np.zeros_like(Wg); np.put_along_axis(mg, top, 1.0, 1); W = W * mg[:, gi]; W /= W.sum(1, keepdims=True)
names = n + [h["name"] for h in specs]; gn = [game.get(x, x) for x in n]
hel = []
for h in specs:
    hn = "hlp_%s" % h["name"]
    hel.append(dict(name=hn, a=game[h["a"]], b=game[h["b"]], frac=float(h["frac"]), grow=bool(h["pushq"]),
                    centre=(A @ np.r_[h["c"], 1]).tolist(), push=(s * Q @ h["d"]).tolist(), per_turn=(det * s * Q @ h["D1"] @ Q.T).tolist()))
# conversion check: skin-space game formula == S * casc helper * S^-1
err = 0.0
for tag in ("ad_walk", "f1_charge"):
    d = cload(tag)
    for f in range(0, len(d["G"]), 3):
        for h, g in zip(specs, hel):
            a, b = n.index(h["a"]), n.index(h["b"]); Ac = d["G"][f][a] @ base["IB"][a]; Bc = d["G"][f][b] @ base["IB"][b]
            Mc = helpers2.helper_M(Ac, Bc, h["frac"], h["c"], h["d"], h["D1"], h["pushq"])
            Mg = skin_helpers.pose(g, S4 @ Ac @ S4i, S4 @ Bc @ S4i)
            err = max(err, np.abs(Mg[:3, 3] - (S4 @ Mc @ S4i)[:3, 3]).max(), 100 * np.abs(Mg[:3, :3] - (S4 @ Mc @ S4i)[:3, :3]).max())
print("conversion check max err (m, rot x100) %.2e" % err); assert err < 1e-3
# rows in rig vertex order (Cascadeur order permuted, exact) for changed verts
rig = lib.sc.rigs["ad"]; Pb = (base["BS"] @ base["P"].T).T[:, :3]
dd, perm = cKDTree(Pb).query(rig["V"]); assert len(set(perm)) == len(perm) and dd.max() < 1e-3, dd.max()
Wr, W0r = W[perm], np.c_[W0, np.zeros((len(W0), len(specs)))][perm]
rows = {}
for i in np.nonzero(np.abs(Wr - W0r).max(1) > 1e-6)[0]:
    nz = np.nonzero(Wr[i] > 1e-6)[0]; row = {}
    for j in nz:
        key = "hlp_" + names[j] if j >= len(n) else names[j]
        row[key] = round(float(Wr[i, j]), 6)
    rows[str(int(i))] = row
print("rows", len(rows), "max influences", max(len(r) for r in rows.values()))
json.dump({"note": "D-374 Colossus corrective helper joints (croc-young-casc, opt3 torch fit, top-%d); helpers in skin.json space, verts = rig vertex index -> weights incl. helpers" % K,
           "helpers": hel, "verts": rows}, open(out, "w"), indent=0)
print("wrote", out)
# r13 Cascadeur FBX input (fbx_r13.py): full rig-order weights with helper groups, helper centres in Cascadeur frame
gcols = list(rig["gn"]) + ["hlp_" + h["name"] for h in specs]; src = [names.index(g) if not g.startswith("hlp_") else len(n) + [ "hlp_" + h["name"] for h in specs].index(g) for g in gcols]
np.savez(out.replace(".json", "_wfix13.npz"), groups=np.array(gcols), W=Wr[:, src], V=lib.np.load(lib.sc.K + "skin_r12l.npz")["V"],
         hname=np.array(["hlp_" + h["name"] for h in specs]), hparent=np.array([h["a"] for h in specs]), hc=np.array([h["c"] for h in specs]))
print("wfix13", out.replace(".json", "_wfix13.npz"))
