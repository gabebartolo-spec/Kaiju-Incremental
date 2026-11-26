extends SceneTree
## Stills of the menu screens for the Unity port's U5 side-by-side (title with no save, the slot
## list, settings, the pause menu, the stand-in mission), each built alone, no 3D behind it.
## Meant for CI (software render: layout, text and missing elements, not the look):
##   tools/capture/ci_capture.sh --resolution=1920x1080 capture_menus.gd -- --out=<dir>

const SETTLE := 30

var _out := "user://menus"


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	# The Unity smoke's state: slot 1 empty, slots 2 and 3 unreadable.
	var slots: Array[Dictionary] = [
		{"slot": 1, "taken": false, "readable": true},
		{"slot": 2, "taken": true, "readable": false},
		{"slot": 3, "taken": true, "readable": false},
	]
	var title := TitleScreen.new()
	title.setup("", slots, 1)
	title.live_city = false
	root.add_child(title)
	await _shot("title")
	title.show_slots(SlotList.Mode.NEW)
	await _shot("slots")
	title.call("_open_settings")
	await _shot("settings")
	title.queue_free()
	var pause := PauseMenu.new()
	root.add_child(pause)
	await _shot("pause")
	pause.queue_free()
	var mission := StubMission.new()
	root.add_child(mission)
	mission.start(Content.continent("ostia_minor"), tr("The rampage is over"))
	await _shot("mission")
	quit()


func _shot(name: String) -> void:
	for _i: int in SETTLE:
		await process_frame
	var path := _out.path_join(name + ".png")
	root.get_texture().get_image().save_png(path)
	print("shot ", path)
