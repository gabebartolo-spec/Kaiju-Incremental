extends SceneTree
## How long quitting takes from the title screen (b2-29: "quitting the game freezes the screen for
## 2-3 seconds"). Loads the real Main scene, waits on the title, prints the unix time just before
## quit(); the caller compares it with the time the process ended.
##
##   godot --path . --resolution 3840x2160 --windowed --script tools/capture/bench_quit.gd


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	_run.call_deferred()


func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main: Node = packed.instantiate()
	root.add_child(main)
	for _i: int in 60:
		await process_frame
	print("QUIT at unix %.3f" % Time.get_unix_time_from_system())
	quit()
