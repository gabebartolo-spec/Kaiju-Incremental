extends RefCounted
## The boilerplate the capture scripts share: flags, the window check, the kaiju's stats, the flow
## test's city and rampage, a staged city, frame waits, render timings, stills and 2x crops.
## A script preloads it (`const Kit := preload("res://tools/capture/capture_kit.gd")`) and keeps
## its own flags, defaults and output names.

## Upgrades owned at each growth stage, so the kaiju has that stage's body (size and growth).
const STAGE_LEVELS: Array[Dictionary] = [
	{"claws": 2, "hide": 2},
	{"claws": 5, "hide": 5, "rage": 3, "evolve1": 1},
	{"claws": 5, "hide": 5, "rage": 5, "evolve1": 1, "tail": 3, "sig_power": 3, "evolve2": 1},
]

## Seconds place_game_camera steps the head frame, so its tilt is settled, not mid-ease.
const HEAD_SETTLE_S := 10.0

## The mid-game build the frame benchmarks run (bench_rampage, bench_heavy).
const BENCH_LEVELS := {"claws": 4, "hide": 3, "rage": 3, "quake": 2, "evolve1": 1, "sig_power": 2}


## The user args (after `--`) over `defaults`: `--name=value` takes the default's type (int,
## float, bool or String), a bare `--name` sets a bool default true. Unknown flags are ignored.
static func args(defaults: Dictionary) -> Dictionary:
	var out := defaults.duplicate()
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var cut := arg.find("=")
		var key := arg.substr(2, cut - 2) if cut >= 0 else arg.substr(2)
		if not out.has(key):
			continue
		var value := arg.substr(cut + 1) if cut >= 0 else ""
		match typeof(defaults[key]):
			TYPE_BOOL:
				out[key] = cut < 0 or value == "true"
			TYPE_INT:
				out[key] = value.to_int()
			TYPE_FLOAT:
				out[key] = value.to_float()
			_:
				out[key] = value
	return out


## False (with the reason printed) when a windowed run on this PC lacks the off-screen no_focus
## override.cfg: headless runs and CI (xvfb) pass.
static func window_ok() -> bool:
	if DisplayServer.get_name() == "headless" or OS.has_environment("CI"):
		return true
	if ProjectSettings.get_setting("display/window/size/no_focus", false):
		return true
	printerr("capture: a windowed run needs the off-screen no_focus override.cfg (or CI)")
	return false


## The kaiju's run stats for `species_id` owning `levels` (tree_species: only that species'
## branch nodes, as UpgradeTree.new takes it).
static func stats(species_id: String, levels: Dictionary = {}, tree_species := "") -> Dictionary:
	return UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def(species_id),
		UpgradeTree.new(Content.upgrades(), levels, tree_species)
	)


## The flow test's city (seed 0).
static func flow_city() -> Array[Dictionary]:
	return CityGen.generate(Seeds.make("city", 0), Content.section("city"))


## A rampage set up but not yet in the tree; layout defaults to the flow test's city.
static func rampage(
	species_id: String, p_stats: Dictionary, run: int, layout: Array[Dictionary] = []
) -> Rampage:
	var out := Rampage.new()
	out.setup(
		Content.species_def(species_id), p_stats, flow_city() if layout.is_empty() else layout, run
	)
	return out


## An autoplayed rampage, added to the tree.
static func autoplay(
	tree: SceneTree,
	species_id: String,
	p_stats: Dictionary,
	run: int,
	layout: Array[Dictionary] = []
) -> Rampage:
	var out := rampage(species_id, p_stats, run, layout)
	out.set_autoplay(true)
	tree.root.add_child(out)
	return out


## The sim of growth stage `tier` (city seed 0, army seed 0) with `tuning`.
static func stage_sim(p_stats: Dictionary, tier: int, tuning: Dictionary) -> RampageSim:
	var layout := CityGrowth.layout(Content.tuning(), tier, Seeds.make("city", 0))
	return RampageSim.new(p_stats, tuning, layout, Seeds.make("army", 0))


## A free camera under `parent`: the game's field of view, far enough for the whole city.
static func camera(parent: Node) -> Camera3D:
	var cam := Camera3D.new()
	cam.fov = CameraTuning.fov()
	cam.far = 4000.0
	parent.add_child(cam)
	return cam


## The gameplay camera of a loaded rampage: the node the player's view comes from.
static func game_camera(tree: SceneTree) -> Camera3D:
	return tree.root.get_viewport().get_camera_3d()


## Puts a hand-built `cam` where the game's camera rests on `kaiju` (in the tree, drawn): the
## rig Rampage._place_camera makes with nothing moving. The eye is the body's drawn focus plus
## CameraTuning's offset x zoom for `body_scale`; the aim is CameraFollow's, tilted up by
## HeadFrame (settled) when the head would ride too high. FOV is CameraTuning's. A rampage places
## its own camera: tools showing play instantiate Rampage and read game_camera.
## `facing` is the sim's (D-330: the game camera stays behind it); the default is the spawn facing.
static func place_game_camera(
	cam: Camera3D, kaiju: KaijuModel, body_scale: float, facing := Vector2(0.0, -1.0)
) -> void:
	var follow := CameraFollow.new(
		kaiju.focus(), CameraTuning.offset() * CameraTuning.zoom(body_scale)
	)
	follow.step_yaw(facing, 0.0, true)
	cam.fov = CameraTuning.fov()
	cam.position = follow.eye()
	cam.look_at(follow.aim(kaiju, body_scale, Vector2(cam.fov, 0.0), HEAD_SETTLE_S))


## Draws a sim's break and fall events in the city view, as a rampage does.
static func apply(city: CityView, events: Array[Dictionary], kaiju_at: Vector3) -> void:
	for event: Dictionary in events:
		match str(event["type"]):
			"chunks_broken":
				var cells: Array[Vector3i] = event["cells"]
				city.chunks_broken(Num.i(event["building"]), cells, kaiju_at)
			"fall_start":
				city.fall_start(event)
			"fall_land":
				city.fall_land(event)


static func frames(tree: SceneTree, n: int) -> void:
	for _i: int in n:
		await tree.process_frame


static func ticks(tree: SceneTree, n: int) -> void:
	for _i: int in n:
		await tree.physics_frame


## Turns on the root viewport's render timers (RenderingServer measure).
static func measure_on(tree: SceneTree) -> void:
	RenderingServer.viewport_set_measure_render_time(tree.root.get_viewport_rid(), true)


## [average GPU ms, average CPU ms] of the render over the next n frames; measure_on first.
static func render_ms(tree: SceneTree, n: int) -> PackedFloat64Array:
	var rid := tree.root.get_viewport_rid()
	var gpu := 0.0
	var cpu := 0.0
	for _i: int in n:
		await tree.process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
	return PackedFloat64Array([gpu / n, cpu / n])


## Saves the frame as <dir>/<shot_name>.png; returns the path.
static func still(tree: SceneTree, dir: String, shot_name: String) -> String:
	var path := dir.path_join(shot_name + ".png")
	tree.root.get_texture().get_image().save_png(path)
	return path


## Where `world` falls in an image of `size` grabbed from the root viewport.
static func image_point(tree: SceneTree, cam: Camera3D, world: Vector3, size: Vector2) -> Vector2:
	return cam.unproject_position(world) * size / tree.root.get_visible_rect().size


## A `crop`-sized part of `shot` round `centre` (kept inside the image), saved at 2x, nearest.
static func crop_2x(shot: Image, centre: Vector2, crop: Vector2i, path: String) -> void:
	var corner := (Vector2i(centre) - crop / 2).clamp(Vector2i.ZERO, shot.get_size() - crop)
	var part := shot.get_region(Rect2i(corner, crop))
	part.resize(crop.x * 2, crop.y * 2, Image.INTERPOLATE_NEAREST)
	part.save_png(path)
