extends SceneTree
## Captures the loading overlay (the INCOMING header over the meter) for the centring check.
## Local GPU only:
##   godot --path . --windowed --resolution 3840x2160 --script \
##     tools/capture/capture_loading.gd -- --out=<dir>

const SETTLE := 8
## Stages shown as done, so the meter is part full.
const STAGES_DONE := 3

var _out := "user://loading"


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	var overlay := LoadingOverlay.new()
	root.add_child(overlay)
	for _i: int in STAGES_DONE:
		overlay.advance()
	for _i: int in SETTLE:
		await process_frame
	root.get_texture().get_image().save_png(_out.path_join("loading.png"))
	quit()
