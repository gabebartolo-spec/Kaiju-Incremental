"""READ-ONLY (croc-young-casc skinfix): per .casc in cfg, load into MY OWN scene, dump Cascadeur's own deformer inputs:
mesh positions, triangle corners, vertex weights (joint index, weight), inverse bind matrices, linked joint names,
bindShapeMatrix, and per frame every linked joint's global_matrix (+ Transform global pos/rot, skinj format). Remove my
scene by its handle; his tab stays current (never switched). cfg: {"cascs": [[tag, path], ...], "out": dir}"""
import json, time, numpy as np, csc
CFG = json.load(open("C:/Users/DANTE/cascadeur_bridge/croc_new/claw/drafts/dump_cfg_p8.json"))
sm = app.get_scene_manager(); his = sm.current_scene(); his_id = (his.name(), his.get_path_name()); n0 = len(sm.scenes())
def rotm(v): return np.asarray(v.to_rotation_matrix(), float) if hasattr(v, "to_rotation_matrix") else np.asarray(v, float).reshape(3, 3)
for tag, path in CFG["cascs"]:
    t0 = time.time(); mine = sm.create_application_scene(); assert (mine.name(), mine.get_path_name()) != his_id
    try:
        ds = mine.domain_scene(); csc.app.ProjectLoader.load_from(path, ds)
        mv = ds.model_viewer(); bv = mv.behaviour_viewer(); am = ds.assets_manager(); dv = ds.data_viewer()
        b = bv.get_behaviours("MeshObject")[0]; m = am.at(bv.get_behaviour_asset(b, "mesh")); d = am.at(bv.get_behaviour_asset(b, "mesh_dependency"))
        P = np.array([np.asarray(p, float) for p in m.positions()]); C = np.array([v.position_index for v in m.vertices()], int)
        WI, WJ, WW = [], [], []
        for i, ws in enumerate(d.vertices_weights()):
            for w in ws: WI.append(i); WJ.append(w.index); WW.append(w.weight)
        IB = np.array([np.asarray(x, float) for x in d.inverse_bind_matrices()])
        lo = bv.get_behaviour_objects_range(b, "linked_objects"); names = [mv.get_object_name(x) for x in lo]
        BS = np.asarray(dv.get_data_value(bv.get_behaviour_data(b, "bindShapeMatrix"), 0), float)
        NF = dv.get_animation_size() if CFG.get("frames", True) else 1
        jb = {mv.get_object_name(bv.get_behaviour_owner(x)): x for x in bv.get_behaviours("Joint")}
        tb = {mv.get_object_name(bv.get_behaviour_owner(x)): x for x in bv.get_behaviours("Transform")}
        G = np.zeros((NF, len(names), 4, 4)); POS = np.zeros((NF, len(names), 3)); ROT = np.zeros((NF, len(names), 3, 3))
        for k, n in enumerate(names):
            gd = bv.get_behaviour_data(jb[n], "global_matrix"); pd = bv.get_behaviour_data(tb[n], "global_position"); rd = bv.get_behaviour_data(tb[n], "global_rotation")
            for f in range(NF):
                G[f, k] = np.asarray(dv.get_data_value(gd, f), float); POS[f, k] = np.asarray(dv.get_data_value(pd, f), float); ROT[f, k] = rotm(dv.get_data_value(rd, f))
        np.savez(CFG["out"] + "/cdump_%s.npz" % tag, P=P, C=C, wi=np.array(WI), wj=np.array(WJ), ww=np.array(WW), IB=IB, names=np.array(names), BS=BS, G=G, POS=POS, ROT=ROT)
        print("CDUMP %s NF %d verts %d corners %d weights %d joints %d in %.0f s" % (tag, NF, len(P), len(C), len(WW), len(names), time.time() - t0))
    except Exception as e:
        import traceback; print("ERR", tag, traceback.format_exc()[-600:])
    finally:
        if (mine.name(), mine.get_path_name()) != his_id: sm.remove_application_scene(mine); time.sleep(5)   # coordinator 22:44 crash: 5 s after a scene removal before any other call
        cur = sm.current_scene()
        if (cur.name(), cur.get_path_name()) != his_id and any((x.name(), x.get_path_name()) == his_id for x in sm.scenes()): sm.set_current_scene(his)
print("AFTER: tabs %d -> %d, current %s" % (n0, len(sm.scenes()), sm.current_scene().name()))
