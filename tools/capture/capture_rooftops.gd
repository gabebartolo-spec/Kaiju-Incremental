extends SceneTree
## Captures the rooftop defenders (D-063) at the game camera: a Behemoth croc stands in the
## Behemoth city where the most squads have it in rifle range, and they fire on it. Stills mid-
## volley, plus rooftops.json: each still's squad screen spots (for the 2x crop), every volley's
## frame and every hit spark's frame and screen spot. tools/capture/spark_gain.py then measures in
## the recorded movie how much each spark brightens its spot (the viewport image read here lags
## the sim by a frame or two, so the movie is the proof).
## Pair with --write-movie (ci_capture.sh --movie) for the clip. Needs a window and the
## no-focus override.cfg (or CI: tools/capture/ci_capture.sh).
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_rooftops.gd -- --out=<dir> [--seed=0] [--typical]
## --typical stands where a middling number of squads fire (the median of the spots where any
## do), not the most: what a rampage usually looks like (D-076).
## --rifle-ab=A,B plays 6 s with the rifle cue at A dB, then 6 s more at B dB (the mix A/B).

const GuiInput := preload("res://tests/lib/gui_input.gd")
const FRAMES := 60 * 6
const SETTLE := 45  # frames for the camera to settle before stills count
const MAX_STILLS := 4
const MID_FLIGHT := 5  # frames after a volley a still is taken: tracers in flight
const LEVELS := {"claws": 3, "hide": 5, "rage": 3, "evolve1": 1}
const GRID := 2.0  # the stand search tries every this many units over the arena
const NEAR := 5.0  # a squad nearer than this to the stand spot does not count (point-blank)
## The ground the game camera shows round the kaiju (x either way, z ahead / behind it): squads
## outside it would fire from off screen or from under the HUD.
const VIEW := Rect2(-24.0, -30.0, 48.0, 36.0)

var _out := "user://rooftops"
var _seed := 0
var _typical := false
var _rifle_ab: Array[float] = []
var _stills: Array[Dictionary] = []
var _volleys: Array[int] = []
var _sparks: Array[Dictionary] = []


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		if arg.begins_with("--seed="):
			_seed = arg.substr(7).to_int()
		if arg == "--typical":
			_typical = true
		if arg.begins_with("--rifle-ab="):
			for db: String in arg.substr(11).split(","):
				_rifle_ab.append(db.to_float())
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
	sim.kaiju_pos = _stand(sim, _typical)
	sim.facing = Vector2(0, -1)
	rampage.scripted = func(_s: RampageSim) -> Dictionary: return {"move": Vector2.ZERO}
	root.add_child(rampage)
	var roofs: RooftopView = GuiInput.find_script(rampage, RooftopView)
	var camera := root.get_viewport().get_camera_3d()
	var shots := 0
	var due := -1
	var logged := 0
	var size := Vector2(root.get_viewport().get_visible_rect().size)
	var levels: Dictionary = Content.section("sfx")["volume_db"]
	for i: int in FRAMES * maxi(1, _rifle_ab.size()):
		if not _rifle_ab.is_empty() and i % FRAMES == 0:
			levels["rifle"] = _rifle_ab[floori(i / float(FRAMES))]
			print("rooftops: frame %d rifle at %.1f dB" % [i, levels["rifle"]])
		await physics_frame
		while logged < roofs.spark_log.size():
			var at: Vector3 = roofs.spark_log[logged]["at"]
			var px := camera.unproject_position(at)
			var seen := (
				not camera.is_position_behind(at) and Rect2(Vector2.ZERO, size).has_point(px)
			)
			_sparks.append({"frame": i, "x": roundi(px.x), "y": roundi(px.y), "on_screen": seen})
			logged += 1
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
			"rooftops: %d squads, %d volleys drawn, %d stills, %d sparks"
			% [
				sim.army_units.squads.size(),
				roofs.shots,
				_stills.size(),
				_sparks.size(),
			]
		)
	)
	quit()


## The spot (on a GRID over the arena) where the most squads in the camera's VIEW have the kaiju
## in rifle range (none point-blank; range from its stomp edge, as the sim's), then where the most
## squads are in VIEW. typical: the median of the spots where any fire, instead of the most.
func _stand(sim: RampageSim, typical := false) -> Vector2:
	var reach := (Num.f(sim.army["rooftop"]["range"]) + sim.stomp_radius()) * 0.95
	var best := sim.kaiju_pos
	var best_n := -1
	var spots: Array[Vector3] = []  # x, z, score of every spot where any squad fires
	var steps := int(sim.arena_half * 2.0 / GRID)
	for gx: int in steps:
		for gz: int in steps:
			var at := Vector2(-sim.arena_half + gx * GRID, -sim.arena_half + gz * GRID)
			var firing := 0
			var seen := 0
			for squad: Army.Squad in sim.army_units.squads:
				var d := squad.pos.distance_to(at)
				var shown := VIEW.has_point(squad.pos - at)
				seen += 1 if shown else 0
				firing += 1 if d > NEAR and d < reach and shown else 0
			var n := firing * 100 + seen  # most firing on screen, then most on screen
			if firing > 0:
				spots.append(Vector3(at.x, at.y, n))
			if n > best_n:
				best_n = n
				best = at
	if typical and not spots.is_empty():
		spots.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.z < b.z)
		var mid := spots[floori(spots.size() * 0.5)]
		best = Vector2(mid.x, mid.y)
		best_n = roundi(mid.z)
	print(
		(
			"rooftops: standing at %s, %d squads firing on screen, %d on screen"
			% [best, floori(best_n / 100.0), best_n % 100]
		)
	)
	return best


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
