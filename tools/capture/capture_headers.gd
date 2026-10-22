extends SceneTree
## Captures the title and results screens for the header centring check (the red alert strip's
## ink padding). Local GPU only:
##   godot --path . --windowed --resolution 3840x2160 --script \
##     tools/capture/capture_headers.gd -- --out=<dir>

const SETTLE := 8
const SAMPLE_RESULT := {"rubble": 150, "toppled": 5, "civilians": 12}
const SAMPLE_BEST := {"rubble": 200.0}

var _out := "user://headers"


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
	await _shot("title")
	title.queue_free()
	var results := ResultsScreen.new(SAMPLE_RESULT, SAMPLE_BEST)
	root.add_child(results)
	await _shot("results")
	quit()


func _shot(name: String) -> void:
	for _i: int in SETTLE:
		await process_frame
	root.get_texture().get_image().save_png(_out.path_join(name + ".png"))
