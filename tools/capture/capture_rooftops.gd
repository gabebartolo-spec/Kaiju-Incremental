extends SceneTree
## Captures the rooftop defenders (D-063) at the game camera: a Behemoth croc stands in the
## Behemoth city where the most squads have it in rifle range, and they fire on it. Stills mid-
## volley, plus rooftops.json: each still's squad screen spots (for the 2x crop), every volley's
## frame, and every hit spark's screen spot with the brightness it added there (proof each spark
## shows: the frame with it against the frame before).
## Pair with --write-movie (ci_capture.sh --movie) for the clip. Needs a window and the
## no-focus override.cfg (or CI: tools/capture/ci_capture.sh).
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_rooftops.gd -- --out=<dir> [--seed=0]

const GuiInput := preload("res://tests/lib/gui_input.gd")
const FRAMES := 60 * 6
const SETTLE := 45  # frames for the camera to settle before stills count
const MAX_STILLS := 4
const MID_FLIGHT := 5  # frames after a volley a still is taken: tracers in flight
const LEVELS := {"claws": 3, "hide": 5, "rage": 3, "evolve1": 1}
const GRID := 2.0  # the stand search tries every this many units over the arena
const NEAR := 5.0  # a squad nearer than this to the stand spot does not count (point-blank)
const WINDOW := 3  # a spark's brightness is the brightest pixel within this many of its spot

var _out := "user://rooftops"
var _seed := 0
var _stills: Array[Dictionary] = []
var _volleys: Array[int] = []
var _sparks: Array[Dictionary] = []


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		if arg.begins_with("--seed="):
			_seed = arg.substr(7).to_int()
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var species := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), LEVELS, "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	var layout := CityGrowth.layout(
		Content.tuning(), Num.i(stats["size"]), Seeds.make("city", _seed)
	)
	var rampage := Rampage.new()
	rampage.setup(species, stats, layout, _seed)
	var sim := rampage.sim
	sim.kaiju_pos = _stand(sim)
	sim.facing = Vector2(0, -1)
	rampage.scripted = func(_s: RampageSim) -> Dictionary: return {"move": Vector2.ZERO}
	root.add_child(rampage)
	var roofs: RooftopView = GuiInput.find_script(rampage, RooftopView)
	var camera := root.get_viewport().get_camera_3d()
	var shots := 0
	var due := -1
	var logged := 0
	var pending: Array[Dictionary] = []
	var before: Image = null
	var size := Vector2(root.get_viewport().get_visible_rect().size)
	for i: int in FRAMES:
		await physics_frame
		# This frame's image shows the last frame drawn: the sparks logged then, against before.
		var now := root.get_viewport().get_texture().get_image()
		for spark: Dictionary in pending:
			spark["added"] = _peak(now, spark) - _peak(before, spark)
			_sparks.append(spark)
		pending = []
		while logged < roofs.spark_log.size():
			var at: Vector3 = roofs.spark_log[logged]["at"]
			var px := camera.unproject_position(at)
			var seen := (
				not camera.is_position_behind(at) and Rect2(Vector2.ZERO, size).has_point(px)
			)
			pending.append({"frame": i, "x": roundi(px.x), "y": roundi(px.y), "on_screen": seen})
			logged += 1
		before = now
		if roofs.shots > shots:
			shots = roofs.shots
			_volleys.append(i)
			if i >= SETTLE and due < 0 and _stills.size() < MAX_STILLS:
				due = i + MID_FLIGHT
		if i >= due and due >= 0 and roofs.lit.y > 0:  # tracers in the air
			due = -1
			_still(rampage, roofs, camera, i)
	var file := FileAccess.open(_out.path_join("rooftops.json"), FileAccess.WRITE)
	file.store_string(
		JSON.stringify({"stills": _stills, "volley_frames": _volleys, "sparks": _sparks}, "  ")
	)
	file.close()
	print(
		(
			"rooftops: %d squads, %d volleys drawn, %d stills, %d sparks, dimmest spark +%.2f"
			% [
				sim.army_units.squads.size(),
				roofs.shots,
				_stills.size(),
				_sparks.size(),
				_dimmest()
			]
		)
	)
	quit()


## The spot (on a GRID over the arena) where the most squads have the kaiju in rifle range,
## none of them point-blank.
func _stand(sim: RampageSim) -> Vector2:
	var reach := Num.f(sim.army["rooftop"]["range"]) * 0.95
	var best := sim.kaiju_pos
	var best_n := -1
	var steps := int(sim.arena_half * 2.0 / GRID)
	for gx: int in steps:
		for gz: int in steps:
			var at := Vector2(-sim.arena_half + gx * GRID, -sim.arena_half + gz * GRID)
			var n := 0
			for squad: Army.Squad in sim.army_units.squads:
				var d := squad.pos.distance_to(at)
				n += 1 if d > NEAR and d < reach else 0
			if n > best_n:
				best_n = n
				best = at
	print("rooftops: standing at %s, %d squads in range" % [best, best_n])
	return best


## The brightest luminance within WINDOW pixels of a spark's spot (0 without an image).
func _peak(img: Image, spark: Dictionary) -> float:
	if img == null:
		return 0.0
	var top := 0.0
	for dy: int in range(-WINDOW, WINDOW + 1):
		for dx: int in range(-WINDOW, WINDOW + 1):
			var x := Num.i(spark["x"]) + dx
			var y := Num.i(spark["y"]) + dy
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				top = maxf(top, img.get_pixel(x, y).get_luminance())
	return top


func _dimmest() -> float:
	var low := INF
	for spark: Dictionary in _sparks:
		if spark["on_screen"]:
			low = minf(low, Num.f(spark["added"]))
	return low


func _still(rampage: Rampage, roofs: RooftopView, camera: Camera3D, frame: int) -> void:
	var name := "rooftops_%04d.png" % frame
	root.get_viewport().get_texture().get_image().save_png(_out.path_join(name))
	var spots: Array[Dictionary] = []
	for squad: Army.Squad in rampage.sim.army_units.squads:
		var feet := roofs.stance(squad, 1).origin
		if camera.is_position_behind(feet):
			continue
		var at := camera.unproject_position(feet + Vector3(0, 0.4, 0))
		spots.append({"squad": squad.id, "x": roundi(at.x), "y": roundi(at.y)})
	(
		_stills
		. append(
			{
				"file": name,
				"frame": frame,
				"spots": spots,
				"volley_squad": roofs.last_squad,
				"flashes_lit": roofs.lit.x,
				"tracers_lit": roofs.lit.y,
			}
		)
	)
