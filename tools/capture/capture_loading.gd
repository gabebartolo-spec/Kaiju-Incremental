extends SceneTree
## The loading screen as the player sees it (D-427): one shot per load, so --loads=N shows the
## rotation (a different still each time, never the same twice in a row).
##
##   godot --path . --resolution 1920x1080 --windowed --script tools/capture/capture_loading.gd \
##     -- --out=<dir> [--loads=3]

const Kit := preload("res://tools/capture/capture_kit.gd")


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	var a := Kit.args({"out": "user://loading", "loads": "3"})
	DirAccess.make_dir_recursive_absolute(str(a["out"]))
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred(str(a["out"]), int(str(a["loads"])))


func _run(out: String, loads: int) -> void:
	for i: int in loads:
		var overlay := LoadingOverlay.new()
		root.add_child(overlay)
		for _s: int in i + 2:
			overlay.advance()
		await Kit.frames(self, 6)
		print("LOADING %s" % Kit.still(self, out, "loading_%d" % i))
		overlay.queue_free()
		await Kit.frames(self, 2)
	quit()
