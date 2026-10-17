"""Checks a motion_test.py export: python tools/blender/verify_skin.py <x.skin.json> <x.kvox>
Weights sum to 1, parents come first, the record size matches, and rig_voxel cells of the same GLB
land on the skin (kvox_cell_to_skin): median distance to the nearest skin position should be about
one voxel. Pure numpy."""
import json, struct, sys, numpy as np
j=json.load(open(sys.argv[1])); d=sys.argv[1].rsplit("/",1)[0] if "/" in sys.argv[1] else "."
b=open(d+"/"+j["weights_file"],"rb").read(); assert b[:4]==b"KSKW"
ver,n=struct.unpack_from("<II",b,4); nb,=struct.unpack_from("<H",b,12)
rec=np.frombuffer(b,dtype=[("p","<f4",3),("b","u1",4),("w","<f4",4)],count=n,offset=14)
print("version",ver,"positions",n,"bones",nb,"json bones",len(j["bones"]),"file bytes",len(b),"expected",14+32*n)
assert len(b)==14+32*n
ws=rec["w"].sum(1); print("weight sums min/max",ws.min().round(4),ws.max().round(4)," bone ids used max",rec["b"][rec["w"]>0].max())
names=[x["name"] for x in j["bones"]]; par=[x["parent"] for x in j["bones"]]
assert all(p is None or names.index(p)<i for i,p in enumerate(par)), "parents first"
P=rec["p"]; print("bbox", P.min(0).round(1), P.max(0).round(1), " height", (P[:,1].max()-P[:,1].min()).round(2))
dom=rec["b"][:,0]; import collections; c=collections.Counter(names[i] for i in dom); print("dominant bone counts (top 8)", c.most_common(8))
# kvox check
kb=open(sys.argv[2],"rb").read(); kn,=struct.unpack_from("<I",kb,14)
kv=np.frombuffer(kb,dtype=[("x","<i2"),("y","<i2"),("z","<i2"),("r","u1"),("g","u1"),("b","u1"),("f","u1")],count=kn,offset=18)
M=np.array(j["kvox_cell_to_skin"]); cells=np.c_[kv["x"],kv["y"],kv["z"],np.ones(kn)].astype(float)
q=(M@cells.T).T[:,:3]
rng=np.random.default_rng(0); sel=rng.choice(kn,4000,replace=False)
dd=np.array([np.linalg.norm(P-q[i],axis=1).min() for i in sel])
vox=np.linalg.norm(M[:3,0]); print("voxel size m",vox.round(3)," kvox->nearest skin position: median",np.median(dd).round(2),"p95",np.percentile(dd,95).round(2),"max",dd.max().round(2))
