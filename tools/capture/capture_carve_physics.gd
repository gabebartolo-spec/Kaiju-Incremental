extends SceneTree
## WP5 proof (D-094): the carving physics view (CarvePhysics) driven by WP1's sim grid
## (VoxelFrame, the spike's office block from tests/lib/destruction_paths.gd). With --markers the
## orange sphere is the blow. Saves a still every 0.5 s, a still plus a 2x crop at each island
## release and at its
## first breaks, and prints body counts, frame cost and a through-the-ground check.
##   --scene=tower   a base cut in two passes: the tower topples, follows the sim ~1 s, breaks up
##   --scene=swipe   two swipes across a facade: carved-cell debris, nothing falls
##   --scene=block   six towers cut at the base at once (drops and topples), the city-wide cap
##   --seconds=N  --out=<dir>  --markers (show the blow sphere; off by default)
##   --settle=S  at S seconds pause, draw every remesh, save one <scene>_settled.png and quit
##   (the deterministic pixel A/B; no timeline stills)  --no-shots (a speed run)
##   --off=island_merged,native_colliders (render_opt flags off: the A/B)
## CI: tools/capture/ci_capture.sh --movie capture_carve_physics.gd -- --scene=tower --out=<dir>
@warning_ignore_start("integer_division")

const PATHS := preload("res://tests/lib/destruction_paths.gd")
const VIEW_STUB := preload("res://tools/capture/carve_view_stub.gd")
const STAGE := preload("res://tools/capture/carve_stage.gd")
const RES := 8
const SHOT_EVERY := 15  # frames between timeline stills
const SETTLE_FRAMES := 12  # frames drawn, paused, before the settled still
const CROP := Vector2i(320, 180)  # crop round an event, saved at 2x
const MAX_EVENT_SHOTS := 8
const SUNK := 0.03  # a piece reaching this far below the road counts as sunk into it
const ENCLOSED := 0.5  # a piece this far inside a building's box (and off the street) is inside it

var _scene := "tower"
var _out := "user://carve_physics"
var _seconds := 0.0
var _markers := false  # --markers: show the blow sphere (a test overlay, off by default)
var _shots := true  # --no-shots: no stills (a speed run: a 4K save is a slow frame)
var _seeded := 0  # --settle: particle systems seeded so far (_pin_seed)
var _settle := 0.0  # --settle=S: the settled frame at S seconds (0: none)
var _phys: CarvePhysics
var _grids: Array[VoxelFrame] = []
var _views: Array[VIEW_STUB] = []
var _spheres: Array[MeshInstance3D] = []
var _world: Node3D
var _frame := 0
var _queue: Array[Dictionary] = []  # event shots waiting for the next drawn frame
var _event_shots := 0
var _stats := {
	"live": [],
	"all": [],
	"wall": [],
	"phys": [],
	"proc": [],
	"sim": [],
	"gpu": [],
	"break": [],
	"draws": [],
	"isl_draws": [],
	"swap": []
}
var _last_us := 0
var _last_live_t := 0.0  # the last time any live piece or island body was still moving
var _counts := {"islands": 0, "breaks": 0, "pieces": 0}
## Per island: when it last began to fall free or broke, and the gaps.
var _holds: Array[Dictionary] = []
var _enclosed: Array[int] = []  # pieces inside a building, once a second
var _front: Array[float] = []  # fracture-front height spreads of every staged break (IslandBody)


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			_scene = arg.substr(8)
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg == "--markers":
			_markers = true
		elif arg.begins_with("--seconds="):
			_seconds = arg.substr(10).to_float()
		elif arg.begins_with("--settle="):
			_settle = arg.substr(9).to_float()
			_shots = false
		elif arg == "--no-shots":
			_shots = false
		elif arg.begins_with("--off="):
			for key: String in arg.substr(6).split(","):
				Content.section("render_opt")[key] = false
	if _seconds <= 0.0:
		_seconds = {"tower": 9.0, "swipe": 6.0, "block": 10.0}.get(_scene, 9.0)
	DirAccess.make_dir_recursive_absolute(_out)
	if _settle > 0.0:  # dust is GPU particles, randomly seeded: pin each one in the order made
		node_added.connect(_pin_seed)
	_setup()
	process_frame.connect(_on_frame)


## A settled still compares across runs: every particle system gets a seed from its add order.
func _pin_seed(node: Node) -> void:
	if node is GPUParticles3D:
		var p: GPUParticles3D = node
		p.use_fixed_seed = true
		p.seed = _seeded
		_seeded += 1


func _setup() -> void:
	_world = Node3D.new()
	root.add_child(_world)
	STAGE.environment(_world)
	STAGE.ground(_world)
	var fx := Fx.new()
	_world.add_child(fx)
	_phys = CarvePhysics.new(7)
	_phys.fx = fx
	_world.add_child(_phys)
	_phys.spawned.connect(func(chunk: IslandBody) -> void: chunk.broke.connect(_on_broke))
	var layout := STAGE.layout(_scene)
	for n: int in layout.size():
		var b := layout[n]
		var units: Vector3i = b["units"]
		var at: Vector3 = b["at"]
		var site := CarveSite.new(n, at - Vector3(units.x, 0, units.z) * 0.5, units * RES, RES)
		var grid := PATHS.office(units, RES)
		site.offset = grid.offset
		_grids.append(grid)
		_phys.add_site(site, grid.cells)
		var view: VIEW_STUB = VIEW_STUB.new(site)
		_world.add_child(view)
		view.build(grid.cells)
		_views.append(view)
		_spheres.append(STAGE.sphere(_world, Num.f(b["radius"])))
	var cam := Camera3D.new()
	cam.fov = CameraTuning.fov()
	_world.add_child(cam)
	match _scene:
		"swipe":
			cam.look_at_from_position(Vector3(7, 8, -17), Vector3(0, 6.5, 0))
		"block":
			cam.look_at_from_position(Vector3(-28, 15, 34), Vector3(-2, 4, 0))
		_:
			cam.look_at_from_position(Vector3(-5, 8, 30), Vector3(-5, 5, 0))
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)


func _on_frame() -> void:
	if paused:  # the settled frame is being drawn: nothing moves
		return
	_frame += 1
	var t := _frame / 30.0
	var t0 := Time.get_ticks_usec()
	var layout := STAGE.layout(_scene)
	for n: int in layout.size():
		_blow(n, layout[n], t - Num.f(layout[n]["delay"]))
	var sim_ms := (Time.get_ticks_usec() - t0) / 1000.0
	_record(sim_ms)
	var headless := DisplayServer.get_name() == "headless"
	if _shots and not headless and (_frame % SHOT_EVERY == 0 or not _queue.is_empty()):
		await RenderingServer.frame_post_draw
		_shoot(t)
	if _settle > 0.0 and t >= _settle and not paused:
		var still := _out.path_join(_scene + "_settled.png")
		await STAGE.settled_shot(self, _phys, still, SETTLE_FRAMES)
		quit()
	elif t >= _seconds:
		_report()
		quit()


func _blow(n: int, b: Dictionary, t: float) -> void:
	var sphere := _spheres[n]
	var at: Variant = STAGE.path(_scene, b, t) if t >= 0.0 else null
	sphere.visible = _markers and at != null
	if at == null:
		return
	var centre: Vector3 = at
	sphere.position = centre
	var grid := _grids[n]
	var view := _views[n]
	var before := grid.cells
	var site := _phys.site(n)
	var local := centre - site.origin + Vector3(grid.offset) / RES
	var removed := grid.carve_sphere(local, Num.f(b["radius"]))
	if removed.is_empty():
		return
	var mats := PackedByteArray()
	mats.resize(removed.size())
	for k: int in removed.size():
		mats[k] = before[removed[k]]
	var cut := {"cells": removed, "mats": mats}
	var ahead: Variant = STAGE.path(_scene, b, t + 1.0 / 30.0)
	cut["push"] = Vector3.ZERO
	if ahead != null:
		var next: Vector3 = ahead
		cut["push"] = (next - centre).normalized()
	view.touched(grid.cells, removed)
	_phys.carved(n, grid.cells, cut)
	for event: Dictionary in grid.settle():
		var cells: PackedInt32Array = event["index"]
		view.touched(grid.cells, cells)
		var island := _phys.fell(n, grid.cells, event)
		_counts["islands"] += 1
		print("ISLAND t=%.2f building=%d kind=%s cells=%d" % [t, n, event["kind"], cells.size()])
		island.released.connect(func() -> void: _event("release", island.global_position))
		island.broke.connect(_on_broke)
		var hold := {"island": island, "t_peak": 0.0, "holds": [], "n": n, "fronts": []}
		_holds.append(hold)
		island.tree_exiting.connect(
			func() -> void: hold["fronts"] = island.front_spreads.duplicate()
		)
		island.released.connect(func() -> void: hold["t_peak"] = _frame / 30.0)
		island.broke.connect(
			func(_p: Array[Dictionary], _at: Vector3) -> void:
				var held: Array = hold["holds"]
				var now := _frame / 30.0
				held.append([Num.f(hold["t_peak"]), now])
				hold["t_peak"] = now
		)


func _on_broke(pieces: Array[Dictionary], at: Vector3) -> void:
	_counts["breaks"] += 1
	for island: IslandBody in _phys.islands():
		if island.last_break_us > 0:
			_push("break", island.last_break_us / 1000.0)
			island.last_break_us = 0
	_counts["pieces"] += pieces.size()
	_event("break", at)


func _event(kind: String, at: Vector3) -> void:
	if _event_shots >= MAX_EVENT_SHOTS:
		return
	_event_shots += 1
	_queue.append({"kind": kind, "at": at, "frame": _frame})


func _shoot(t: float) -> void:
	var shot := root.get_viewport().get_texture().get_image()
	if _frame % SHOT_EVERY == 0:
		shot.save_png(_out.path_join("%s_t%05.2f.png" % [_scene, t]))
	var cam := root.get_viewport().get_camera_3d()
	for e: Dictionary in _queue:
		var name := "%s_%s_f%04d" % [_scene, e["kind"], _frame]
		shot.save_png(_out.path_join(name + ".png"))
		var at: Vector3 = e["at"]
		# unproject_position is in the viewport's 2D space, which a stretch mode scales.
		var scale := Vector2(shot.get_size()) / root.get_viewport().get_visible_rect().size
		var p := Vector2i(cam.unproject_position(at) * scale)
		var box := Rect2i(p - CROP / 2, CROP)
		box.position = box.position.clamp(Vector2i.ZERO, shot.get_size() - CROP)
		var crop := shot.get_region(box)
		crop.resize(CROP.x * 2, CROP.y * 2, Image.INTERPOLATE_NEAREST)
		crop.save_png(_out.path_join(name + "_crop2x.png"))
		print("SHOT %s at frame %d (event frame %d)" % [name, _frame, e["frame"]])
	_queue.clear()


func _record(sim_ms: float) -> void:
	if _phys.live_bodies() > 0:
		_last_live_t = _frame / 30.0
	var vp := root.get_viewport_rid()
	_push("live", _phys.live_bodies())
	_push("all", _phys.all_bodies())
	_push("phys", Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	_push("proc", Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_push("sim", sim_ms)
	var now := Time.get_ticks_usec()
	_push("wall", (now - _last_us) / 1000.0 if _last_us > 0 else 0.0)
	_last_us = now
	_push("gpu", RenderingServer.viewport_get_measured_render_time_gpu(vp))
	STAGE.record_render(_phys, _stats)
	if _frame % 30 == 0:
		_enclosed.append(_phys.enclosed(ENCLOSED))
		print("STATE %d %s" % [_frame / 30, STAGE.state_digest(_phys)])
		print(
			(
				(
					"SEC %d live=%d all=%d rubble=%d islands=%d lowest=%.3f sunk=%d"
					+ " raised=%d/%.3f inside=%d largest=%d phys=%.1fms"
				)
				% [
					_frame / 30,
					_phys.live_bodies(),
					_phys.all_bodies(),
					_phys.rubble_pieces(),
					_phys.islands().size(),
					_phys.lowest_point(),
					_phys.sunk(SUNK),
					_phys.raised()[0],
					_phys.raised()[1],
					_enclosed[-1],
					_largest(),
					_stats["phys"][-1],
				]
			)
		)


func _largest() -> int:
	var most := 0
	for island: IslandBody in _phys.islands():
		most = maxi(most, island.cell_count())
	return most


func _push(key: String, value: float) -> void:
	var a: Array = _stats[key]
	a.append(value)


func _report() -> void:
	var size := DisplayServer.window_get_size()
	print(
		(
			"CARVE_PHYS scene=%s frames=%d window=%dx%d islands=%d breaks=%d pieces=%d"
			% [
				_scene,
				_frame,
				size.x,
				size.y,
				_counts["islands"],
				_counts["breaks"],
				_counts["pieces"],
			]
		)
	)
	print("  rubble=%d lowest=%.3f" % [_phys.rubble_pieces(), _phys.lowest_point()])
	var skid := _phys.skid()
	print(
		(
			"  SKID max %.1f widths, mean %.2f, over 5 widths %d of %d pieces"
			% [skid[0], skid[1], skid[3], skid[2]]
		)
	)
	print(
		(
			"  RUBBLE per building max %d (cap %d), dropped %d"
			% [
				_phys.rubble_max(),
				Num.i(Content.section("carve_physics").get("rubble_cap", 0)),
				_phys.rubble_dropped(),
			]
		)
	)
	var spread := 0.0
	var fronts := 0
	for h: Dictionary in _holds:
		var held_island: Variant = h["island"]
		var list: Array = h["fronts"]
		if is_instance_valid(held_island):
			var island: IslandBody = held_island
			list = island.front_spreads
		for f: float in list:
			spread += f
			fronts += 1
	print(
		(
			"  FRONT spread mean %.3f units over %d staged breaks (0 = a plane: staircase)"
			% [spread / maxi(1, fronts), fronts]
		)
	)
	print(
		(
			"  LARGEST island at end %d cells, VANISHED in one frame %d"
			% [_largest(), _phys.vanished()]
		)
	)
	print("  INSIDE buildings per second %s, culled indoors %d" % [_enclosed, _phys.culled()])
	print("  COLLIDER worst rebuild %.2f ms" % STAGE.worst_collider_ms(_phys))
	var live_speed := _phys.live_speed()
	print(
		(
			"  LIVE at end %d, fastest %.3f, last live t=%.2f"
			% [_phys.live_bodies(), live_speed, _last_live_t]
		)
	)
	STAGE.print_holds(_holds)
	STAGE.print_stats(_stats)
	var wall: Array = _stats["wall"]
	STAGE.print_slow(wall)
