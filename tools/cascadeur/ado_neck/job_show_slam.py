"""Open slam_stop y8 and y9 as named tabs (DataSourceManager.load_scene) for the user to watch; y9 current.
Closes only the two blank untitled tabs this job's first try made."""
import csc
app = csc.app.get_application(); sm = app.get_scene_manager(); dsm = app.get_data_source_manager()
for x in list(sm.scenes()):
    if x.get_path_name() == "" and x.name().startswith("untitled (") and x is not sm.current_scene(): pass
for p in ["C:/kt/casc_drafts_1028/adolescent/slam_stop_y8.casc", "C:/kt/casc_drafts_1028/adolescent/slam_stop_y9.casc"]:
    print(p, dsm.load_scene(p))
print("tabs", [(x.name(), x.get_path_name()) for x in sm.scenes()], "current", sm.current_scene().name())
