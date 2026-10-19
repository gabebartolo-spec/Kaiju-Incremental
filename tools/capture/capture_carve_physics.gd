extends SceneTree
## WP5 proof (D-094): the carving physics view (CarvePhysics) driven by a capture-only stub grid
## (carve_grid_stub.gd, the spike's algorithm; WP1's VoxelFrame replaces it). The orange sphere is
## the blow. Saves a still every 0.5 s, a still plus a 2x crop at each island release and at its
## first breaks, and prints body counts, frame cost and a through-the-ground check.
##   --scene=tower   a base cut in two passes: the tower topples, follows the sim ~1 s, breaks up
##   --scene=swipe   two swipes across a facade: carved-cell debris, nothing falls
##   --scene=block   six towers cut at the base at once (drops and topples), the city-wide cap
##   --seconds=N  --out=<dir>
## CI: tools/capture/ci_capture.sh --movie capture_carve_physics.gd -- --scene=tower --out=<dir>
@warning_ignore_start("integer_division")

const GRID_STUB := preload("res://tools/capture/carve_grid_stub.gd")
const VIEW_STUB := preload("res://tools/capture/carve_view_stub.gd")
const RES := 8
const SHOT_EVERY := 15  # frames between timeline stills
const CROP := Vector2i(320, 180)  # crop round an event, saved at 2x
const MAX_EVENT_SHOTS := 8
const SUNK := 0.03  # a piece reaching this far below the road counts as sunk into it

var _scene := "tower"
var _out := "user://carve_physics"
var _seconds := 0.0
var _phys: CarvePhysics
var _grids: Array[GRID_STUB] = []
var _views: Array[VIEW_STUB] = []
var _spheres: Array[MeshInstance3D] = []
var _world: Node3D
var _frame := 0
var _queue: Array[Dictionary] = []  # event shots waiting for the next drawn frame
var _event_shots := 0
var _stats := {
	"live": [], "all": [], "wall": [], "phys": [], "proc": [], "sim": [], "gpu": [], "break": []
}
var _last_us := 0
var _counts := {"islands": 0, "breaks": 0, "pieces": 0, "fires": 0}


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			_scene = arg.substr(8)
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--seconds="):
			_seconds = arg.substr(10).to_float()
	if _seconds <= 0.0:
		_seconds = {"tower": 9.0, "swipe": 6.0, "block": 10.0}.get(_scene, 9.0)
	DirAccess.make_dir_recursive_absolute(_out)
	_setup()
	process_frame.connect(_on_frame)


## Building n's footprint centre, size in units, and its blow's path (a centre at time t, or
## null when the blow is done).
func _layout() -> Array[Dictionary]:
	match _scene:
		"swipe":
			return [{"at": Vector3.ZERO, "units": Vector3i(6, 12, 6), "radius": 1.3, "delay": 0.0}]
		"block":
			var out: Array[Dictionary] = []
			for n: int in 6:
				var at := Vector3((n % 3 - 1) * 9.0, 0.0, (n / 3 - 0.5) * 10.0)
				var units := Vector3i(6, 12 + (n * 5) % 9, 6)
				out.append({"at": at, "units": units, "radius": 2.4, "delay": n * 0.3, "n": n})
			return out
	return [{"at": Vector3.ZERO, "units": Vector3i(6, 16, 6), "radius": 2.4, "delay": 0.0}]


func _path(b: Dictionary, t: float) -> Variant:
	var c: Vector3 = b["at"]
	if _scene == "swipe":
		if t < 2.0:
			return c + Vector3(lerpf(-5.0, 5.0, t / 2.0), 7.0, -3.3)
		if t < 4.0:
			var k := (t - 2.0) / 2.0
			return c + Vector3(lerpf(5.0, -5.0, k), lerpf(9.5, 4.0, k), -3.2)
		return null
	# A base cut in two passes; the second stops short on towers that should topple.
	var stop := 1.0 if _scene == "tower" or Num.i(b.get("n", 0)) % 2 == 1 else 6.0
	if t < 1.6:
		return c + Vector3(lerpf(-6.0, 1.0, t / 1.6), 1.6, -1.6)
	if t < 3.2:
		return c + Vector3(lerpf(-6.0, stop, (t - 1.6) / 1.6), 1.6, 1.6)
	return null


func _setup() -> void:
	_world = Node3D.new()
	root.add_child(_world)
	_environment()
	_ground()
	var fx := Fx.new()
	_world.add_child(fx)
	_phys = CarvePhysics.new(7)
	_phys.fx = fx
	_world.add_child(_phys)
	_phys.ignited.connect(_on_ignited)
	var layout := _layout()
	for n: int in layout.size():
		var b := layout[n]
		var units: Vector3i = b["units"]
		var at: Vector3 = b["at"]
		var site := CarveSite.new(n, at - Vector3(units.x, 0, units.z) * 0.5, units * RES, RES)
		var grid: GRID_STUB = GRID_STUB.new(site)
		_grids.append(grid)
		_phys.add_site(site, grid.cells)
		var view: VIEW_STUB = VIEW_STUB.new(site)
		_world.add_child(view)
		view.build(grid.cells)
		_views.append(view)
		_spheres.append(_sphere(Num.f(b["radius"])))
	var cam := Camera3D.new()
	cam.fov = 55.0
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
	_frame += 1
	var t := _frame / 30.0
	var t0 := Time.get_ticks_usec()
	var layout := _layout()
	for n: int in layout.size():
		_blow(n, layout[n], t - Num.f(layout[n]["delay"]))
	var sim_ms := (Time.get_ticks_usec() - t0) / 1000.0
	_record(sim_ms)
	var headless := DisplayServer.get_name() == "headless"
	if not headless and (_frame % SHOT_EVERY == 0 or not _queue.is_empty()):
		await RenderingServer.frame_post_draw
		_shoot(t)
	if t >= _seconds:
		_report()
		quit()


func _blow(n: int, b: Dictionary, t: float) -> void:
	var sphere := _spheres[n]
	var at: Variant = _path(b, t) if t >= 0.0 else null
	sphere.visible = at != null
	if at == null:
		return
	var centre: Vector3 = at
	sphere.position = centre
	var grid := _grids[n]
	var view := _views[n]
	var cut: Dictionary = grid.carve(centre, Num.f(b["radius"]))
	var removed: PackedInt32Array = cut["cells"]
	if removed.is_empty():
		return
	var ahead: Variant = _path(b, t + 1.0 / 30.0)
	cut["push"] = Vector3.ZERO
	if ahead != null:
		var next: Vector3 = ahead
		cut["push"] = (next - centre).normalized()
	view.touched(grid.cells, removed)
	_phys.carved(n, grid.cells, cut)
	for event: Dictionary in grid.settle():
		var cells: PackedInt32Array = event["cells"]
		view.touched(grid.cells, cells)
		var island := _phys.fell(n, grid.cells, event)
		_counts["islands"] += 1
		print("ISLAND t=%.2f building=%d kind=%s cells=%d" % [t, n, event["kind"], cells.size()])
		island.released.connect(func() -> void: _event("release", island.global_position))
		island.broke.connect(_on_broke)


func _on_broke(pieces: Array[Dictionary], at: Vector3) -> void:
	_counts["breaks"] += 1
	for island: IslandBody in _phys.islands():
		if island.last_break_us > 0:
			_push("break", island.last_break_us / 1000.0)
			island.last_break_us = 0
	_counts["pieces"] += pieces.size()
	_event("break", at)


func _on_ignited(at: Vector3, size: float) -> void:
	_counts["fires"] += 1
	var fire := Fire.new(size, Num.f(_counts["fires"]))
	fire.position = at
	_world.add_child(fire)


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
		var p := Vector2i(cam.unproject_position(at))
		var box := Rect2i(p - CROP / 2, CROP)
		box.position = box.position.clamp(Vector2i.ZERO, shot.get_size() - CROP)
		var crop := shot.get_region(box)
		crop.resize(CROP.x * 2, CROP.y * 2, Image.INTERPOLATE_NEAREST)
		crop.save_png(_out.path_join(name + "_crop2x.png"))
		print("SHOT %s at frame %d (event frame %d)" % [name, _frame, e["frame"]])
	_queue.clear()


func _record(sim_ms: float) -> void:
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
	if _frame % 30 == 0:
		print(
			(
				"SEC %d live=%d all=%d rubble=%d islands=%d lowest=%.3f sunk=%d phys=%.1fms"
				% [
					_frame / 30,
					_phys.live_bodies(),
					_phys.all_bodies(),
					_phys.rubble_pieces(),
					_phys.islands().size(),
					_phys.lowest_point(),
					_phys.sunk(SUNK),
					_stats["phys"][-1],
				]
			)
		)


func _push(key: String, value: float) -> void:
	var a: Array = _stats[key]
	a.append(value)


func _report() -> void:
	var size := DisplayServer.window_get_size()
	print(
		(
			"CARVE_PHYS scene=%s frames=%d window=%dx%d islands=%d breaks=%d pieces=%d fires=%d"
			% [
				_scene,
				_frame,
				size.x,
				size.y,
				_counts["islands"],
				_counts["breaks"],
				_counts["pieces"],
				_counts["fires"],
			]
		)
	)
	print("  rubble=%d lowest=%.3f" % [_phys.rubble_pieces(), _phys.lowest_point()])
	for key: String in _stats:
		var a: Array = _stats[key]
		if a.is_empty():
			continue
		var sorted := a.duplicate()
		sorted.sort()
		var total := 0.0
		for x: float in a:
			total += x
		print(
			(
				"  %-5s avg %7.2f  p95 %7.2f  max %7.2f"
				% [key, total / maxi(1, a.size()), sorted[int(sorted.size() * 0.95)], sorted[-1]]
			)
		)


func _environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	env.ssao_intensity = 2.0
	env.glow_enabled = true
	env.fog_enabled = true
	env.fog_density = 0.004
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	_world.add_child(sun)


func _ground() -> void:
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 2, 400)
	shape.shape = box
	shape.position.y = -1.0
	ground.add_child(shape)
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("4a4d50")
	plane.material = mat
	mesh.mesh = plane
	ground.add_child(mesh)
	_world.add_child(ground)


func _sphere(radius: float) -> MeshInstance3D:
	var s := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.45, 0.2, 0.3)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = mat
	s.mesh = sm
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.visible = false
	_world.add_child(s)
	return s
