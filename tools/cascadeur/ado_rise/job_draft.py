"""croc-claw first draft (C:/kt/casc_drafts_1028/BRIEF.md): key every frame of a frames JSON on r12l in MY OWN scene,
save <out>.casc, remove my work scene (his tabs untouched), then open the saved file in a NEW tab and make it current
(D-347, casc_view_template.py's method). Never saves or edits another tab. Config: drafts/job_cfg.json."""
import json, time
import numpy as np
import csc

CFG = json.load(open("C:/Users/DANTE/cascadeur_bridge/croc_new/claw/drafts/job_cfg.json"))
FR = json.load(open(CFG["frames"]))["frames"]; OUT = CFG["out"]; CASC = CFG["casc"]; NF = len(FR)
t0 = time.time()
sm = app.get_scene_manager()
his = sm.current_scene(); his_id = (his.name(), his.get_path_name()); n_before = len(sm.scenes())
mine = sm.create_application_scene(); mine_id = (mine.name(), mine.get_path_name())
ok = False
try:
    if sm.current_scene().name() != mine.name():
        sm.set_current_scene(mine)
    ds = mine.domain_scene()
    csc.app.ProjectLoader.load_from(CASC, ds)
    mv = ds.model_viewer(); bv = mv.behaviour_viewer(); lv = ds.layers_viewer()
    pts = {mv.get_object_name(bv.get_behaviour_owner(b)): bv.get_behaviour_owner(b) for b in bv.get_behaviours("Point")}
    keyed = [n for n in FR[0] if n in pts]
    print("POINTS casc %d keyed %d; frames not in casc %s; casc left unkeyed %s" % (
        len(pts), len(keyed), [n for n in FR[0] if n not in pts], [n for n in pts if n not in FR[0]]))
    lids = [l for l in lv.all_layer_ids() if not l.is_null()]

    def keys(model, update, su):
        le = model.layers_editor()
        for l in lids:
            for f in range(NF): le.set_fixed_interpolation_or_key_if_need(l, f, True)
        model.fit_animation_size_by_layers(); su.generate_update()
    ds.modify_update("croc-claw draft keys", keys)

    def put(model, update, su):
        nd = {n: update.get_object_by_id(pts[n]).root_group().node_deep("Position") for n in keyed}
        for f in range(NF):
            for n in keyed: nd[n].set_value(np.array(FR[f][n], float), f)
            su.run_update({x.data_id() for x in nd.values()}, f)
    ds.modify_update("croc-claw draft poses", put)
    if CFG.get("jaw"):   # D-368: jaw keyed in the same file after the body (croc-young-casc jaw_lib; copied from fix1/job_fix.py)
        JW = json.load(open(CFG["jaw"]))
        exec(open("C:/Users/DANTE/cascadeur_bridge/croc_young/jaw/jaw_lib.py", encoding="utf-8").read())
        info = jaw_key(ds, {int(f): d for f, d in JW["deg"].items()}, JW["stage"], "draft jaw")
        ang = jaw_angles(ds, list(range(NF)))
        json.dump({"info": info, "angles": [round(a, 3) for a in ang]}, open(CFG["jaw"].replace(".json", "_meas.json"), "w"))
        print("JAW %s peak %.2f end %.2f max step %.2f" % (info, max(ang), ang[-1], max(abs(ang[i + 1] - ang[i]) for i in range(NF - 1))))
    mine.save(OUT + ".casc")
    ok = True
    print("SAVED %s frames %d in %.0f s" % (OUT + ".casc", NF, time.time() - t0))
finally:
    cur = sm.current_scene()
    if (cur.name(), cur.get_path_name()) != his_id:
        sm.set_current_scene(his)
    if (mine.name(), mine.get_path_name()) != his_id:
        sm.remove_application_scene(mine); time.sleep(5)   # lead 22:44 crash: 5 s after a scene removal before any other call
if ok:   # 05:1x lead: RAM (15 GB, ~30 tabs) -> save only, open no new tab
    print("NOTOPENED %s (RAM) tabs %d -> %d" % (OUT + ".casc", n_before, len(sm.scenes())))
if False:
    vs = sm.create_application_scene()
    csc.app.ProjectLoader.load_from(OUT + ".casc", vs.domain_scene())
    sm.set_current_scene(vs)
    print("OPENED %s tabs %d -> %d current %s" % (OUT + ".casc", n_before, len(sm.scenes()), sm.current_scene().name()))
print("AFTER: his open %s" % any((x.name(), x.get_path_name()) == his_id for x in sm.scenes()))
