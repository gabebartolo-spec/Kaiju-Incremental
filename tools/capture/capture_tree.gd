extends SceneTree
## Captures the evolution tree screen at 1080p for the director: early (two nodes bought, the
## default zoom), later (the baby ring owned, zoomed out to the whole tree) and a buy clip
## (buy_00.png.. every 6 frames after a node is bought: motes, surge, fill). Needs a window.
##
##   APPDATA=<scratch> godot --path . --resolution 1920x1080 --windowed \
##     --script tools/capture/capture_tree.gd -- --out=<dir>

const SETTLE := 20
const CLIP_FRAMES := 8
const CLIP_STEP := 6

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
	await _clip(UpgradeTree.new(Content.upgrades(), {"claws": 1}, "reptilian"), "buy")
	quit()


## Buys the newest buyable node and saves a frame every CLIP_STEP frames while the juice plays.
func _clip(tree: UpgradeTree, name: String) -> void:
	var screen := UpgradeScreen.new()
	screen.setup(tree, 400, Content.species_def("reptilian"), Content.section("kaiju"))
	root.add_child(screen)
	await _frames(SETTLE)
	screen.node_button(screen.newest_buyable()).pressed.emit()
	for i: int in CLIP_FRAMES:
		await _frames(CLIP_STEP)
		root.get_texture().get_image().save_png(_out.path_join("%s_%02d.png" % [name, i]))
	screen.queue_free()
	await process_frame


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
