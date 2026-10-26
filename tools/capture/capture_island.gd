extends SceneTree
## Stills of a traffic island (TrafficIsland) in the real game: the game camera with the kaiju
## beside the island's junction, and a close camera on the island. Needs a window:
##   godot --path . --script tools/capture/capture_island.gd -- --out=<dir>
##     [--map_seed=55] [--stage=2]

var _out := "user://island"
var _map_seed := 55
var _stage := 2


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--map_seed="):
			_map_seed = arg.substr(11).to_int()
		elif arg.begins_with("--stage="):
			_stage = arg.substr(8).to_int()
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var city: Dictionary = Content.tuning()["city"]
	city["map_seed"] = _map_seed  # the cached tuning: every reader sees this street plan
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades())
	)
	stats["size"] = _stage
	var rampage := Rampage.new()
	rampage.setup(
		Content.species_def("reptilian"),
		stats,
		CityGrowth.layout(Content.tuning(), _stage, Seeds.make("city", 0)),
		0
	)
	root.add_child(rampage)
	await rampage.wait_loaded()
	var decor: CityDecor = null
	for n: Node in rampage.find_children("*", "", true, false):
		if n is CityDecor:
			decor = n
	if decor == null or decor.islands.is_empty():
		print("no traffic island in map_seed %d stage %d" % [_map_seed, _stage])
		quit(1)
		return
	var at := decor.islands[0]
	for i: int in 900:  # the rise out of the river owns the kaiju's place until it ends
		if not rampage.sim.emerge.active:
			break
		await process_frame
	rampage.sim.kaiju_pos = at + Vector2(-14, -6)
	for i: int in 90:
		await process_frame
	var game := _out.path_join("island_game_m%d_s%d.png" % [_map_seed, _stage])
	root.get_texture().get_image().save_png(game)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.global_position = Vector3(at.x + 4.0, 2.4, at.y + 2.0)
	cam.look_at(Vector3(at.x, 1.1, at.y))
	cam.fov = 50.0
	cam.make_current()
	for i: int in 10:
		await process_frame
	var close := _out.path_join("island_close_m%d_s%d.png" % [_map_seed, _stage])
	root.get_texture().get_image().save_png(close)
	print("saved ", game, " and ", close, " island at ", at)
	quit()
