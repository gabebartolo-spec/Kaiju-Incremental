extends SceneTree
## Captures the evolution tree screen at 1080p for the director: early (two nodes bought, the
## default zoom) and later (the baby ring owned, zoomed out to the whole tree). Needs a window.
##
##   APPDATA=<scratch> godot --path . --resolution 1920x1080 --windowed \
##     --script tools/capture/capture_tree.gd -- --out=<dir>

const SETTLE := 20

var _out := "user://captures"


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	await _shoot(
		UpgradeTree.new(Content.upgrades(), {"claws": 2, "hide": 2}, "reptilian"),
		"tree_early",
		false
	)
	var full := UpgradeTree.new(Content.upgrades(), {}, "reptilian")
	var levels := {}
	for id: String in full.order:
		if full.ring(id) == 1:
			levels[id] = full.max_level(id)
	await _shoot(UpgradeTree.new(Content.upgrades(), levels, "reptilian"), "tree_later", true)
	quit()


func _shoot(tree: UpgradeTree, name: String, zoomed_out: bool) -> void:
	var screen := UpgradeScreen.new()
	screen.setup(tree, 400, Content.species_def("reptilian"), Content.section("kaiju"))
	root.add_child(screen)
	await _frames(SETTLE)
	if zoomed_out:
		var area: TreeArea = screen.get("_area")
		area.view.set_zoom(0.0)
		area.call("_place")
		await _frames(SETTLE)
	root.get_texture().get_image().save_png(_out.path_join(name + ".png"))
	screen.queue_free()
	await process_frame


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame
