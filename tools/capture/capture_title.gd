extends SceneTree
## Captures the title screen (with a save, so CONTINUE shows) for the stripe and layout check.
## Local GPU only:
##   godot --path . --windowed --resolution 3840x2160 --script \
##     tools/capture/capture_title.gd -- --out=<dir>

const SETTLE := 8

var _out := "user://title"


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	var title := TitleScreen.new()
	title.setup("Reptilian, 3 rampages")
	root.add_child(title)
	for _i: int in SETTLE:
		await process_frame
	root.get_texture().get_image().save_png(_out.path_join("title.png"))
	quit()
