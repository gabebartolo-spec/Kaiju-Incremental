"""croc-claw: export a saved draft .casc's joints FBX for the game (lead 10-28: beam_jaw_fix2 SHIP). Loads the file into MY
OWN scene (his tabs untouched), export_joints (job_walk_r12l.py's call), removes my scene. Config drafts/job_export.json
{"casc": <file.casc>, "fbx": <out_joints.fbx>}. Run inside casc_lock keyer via cs.py. Not run yet (keep off Cascadeur
until the lead sends the verdicts)."""
import json, os, time
import csc
CFG = json.load(open("C:/Users/DANTE/cascadeur_bridge/croc_new/claw/drafts/job_export.json"))
t0 = time.time(); sm = app.get_scene_manager()
his = sm.current_scene(); his_id = (his.name(), his.get_path_name())
mine = sm.create_application_scene()
try:
    if sm.current_scene().name() != mine.name():
        sm.set_current_scene(mine)
    csc.app.ProjectLoader.load_from(CFG["casc"], mine.domain_scene())
    app.get_tools_manager().get_tool("FbxSceneLoader").get_fbx_loader(mine).export_joints(CFG["fbx"])
    print("EXPORTED %s -> %s exists %s in %.0f s" % (CFG["casc"], CFG["fbx"], os.path.exists(CFG["fbx"]), time.time() - t0))
finally:
    cur = sm.current_scene()
    if (cur.name(), cur.get_path_name()) != his_id:
        sm.set_current_scene(his)
    sm.remove_application_scene(mine); time.sleep(5)   # lead 22:44 crash: 5 s after a scene removal before any other call
print("AFTER: tabs %s current %r" % ([x.name() for x in sm.scenes()], sm.current_scene().name()))
