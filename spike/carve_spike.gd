extends SceneTree
@warning_ignore_start("unsafe_method_access", "unsafe_property_access", "unsafe_call_argument", "unsafe_cast", "untyped_declaration", "integer_division", "narrowing_conversion")
## SPIKE (throwaway). One building (or a block of six) carved by a moving sphere, Option A:
## sim CarveGrid at 30 Hz, CarveView meshes it and throws Jolt debris and islands.
##   --res=4|8          sim cells per unit (presentation today is 8)
##   --block            six buildings, one sphere each (a city block collapsing)
##   --replay           sim only, twice, compares every tick's digest (determinism)
##   --seconds=10
## Prints per-tick sim, remesh and physics times, and GPU time when a window renders.

const TICK := 1.0 / 30.0
const RADIUS := 2.4
const UNITS := Vector3i(6, 16, 6)

var _res := 8
var _block := false
var _seconds := 10.0
var _grids: Array[CarveGrid] = []
var _views: Array[CarveView] = []
var _centres: Array[Vector3] = []
var _spheres: Array[MeshInstance3D] = []
var _tick := 0
var _hold := INF  # carving stops at this many seconds; the scene keeps rendering
var _acc := 0.0
var _stats := {"sim": [], "mesh": [], "phys": [], "gpu": [], "cpu": [], "proc": [], "bodies": []}


func _initialize() -> void:
	var replay := false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--res="):
			_res = arg.substr(6).to_int()
		elif arg == "--block":
			_block = true
		elif arg.begins_with("--debris="):
			CarveView.debris_per_carve = arg.substr(9).to_int()
		elif arg.begins_with("--hold="):
			_hold = arg.substr(7).to_float()
		elif arg == "--replay":
			replay = true
		elif arg.begins_with("--seconds="):
			_seconds = arg.substr(10).to_float()
	if replay:
		_replay()
		quit()
		return
	_setup()


## The sphere's path for a building at `c`, `t` seconds after it starts: a tunnel through
## floor 9, then two low passes that cut the base through so the top is an island.
static func path(c: Vector3, t: float) -> Vector3:
	if t < 3.0:
		return c + Vector3(lerpf(-6.0, 6.0, t / 3.0), 9.0, 0.0)
	if t < 5.5:
		return c + Vector3(lerpf(6.0, -6.0, (t - 3.0) / 2.5), 1.6, -1.6)
	if t < 8.0:
		return c + Vector3(lerpf(-6.0, 6.0, (t - 5.5) / 2.5), 1.6, 1.6)
	return c + Vector3(6.0 + (t - 8.0) * 4.0, 1.6 + (t - 8.0) * 6.0, 1.6)


func _layout() -> Array[Vector3]:
	if not _block:
		return [Vector3.ZERO]
	var out: Array[Vector3] = []
	for row: int in 2:
		for col: int in 3:
			out.append(Vector3((col - 1) * 9.0, 0.0, (row - 0.5) * 10.0))
	return out


func _units(n: int) -> Vector3i:
	return UNITS if not _block else Vector3i(6, 12 + (n * 5) % 9, 6)


## Sim alone, twice: every tick's grid digest and island sizes must match.
func _replay() -> void:
	var runs: Array[PackedInt64Array] = []
	for run: int in 2:
		var trace := PackedInt64Array()
		var grids: Array[CarveGrid] = []
		var centres := _layout()
		for n: int in centres.size():
			grids.append(CarveGrid.new(_res, _units(n), centres[n] - Vector3(3, 0, 3)))
		for tick: int in roundi(_seconds / TICK):
			for n: int in grids.size():
				var islands: Array[PackedInt32Array] = []
				var t := tick * TICK - n * 0.25
				if t < 0.0:
					continue
				var removed := grids[n].carve(path(centres[n], t), RADIUS, islands)
				trace.append(grids[n].digest())
				trace.append(removed.size())
				for part: PackedInt32Array in islands:
					trace.append(part.size())
		runs.append(trace)
	var same := runs[0] == runs[1]
	print("REPLAY res=%d block=%s entries=%d identical=%s digest=%d" % [
		_res, _block, runs[0].size(), same, hash(runs[0])
	])


func _setup() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var env := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	env.ssao_intensity = 2.5
	env.ssil_enabled = true
	env.glow_enabled = true
	env.fog_enabled = true
	env.fog_density = 0.004
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160.0
	world.add_child(sun)
	var ground := StaticBody3D.new()
	var gs := CollisionShape3D.new()
	var gbox := BoxShape3D.new()
	gbox.size = Vector3(400, 1, 400)
	gs.shape = gbox
	gs.position.y = -0.5
	ground.add_child(gs)
	var gm := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color("4a4d50")
	plane.material = gmat
	gm.mesh = plane
	ground.add_child(gm)
	world.add_child(ground)
	_centres = _layout()
	for n: int in _centres.size():
		var g := CarveGrid.new(_res, _units(n), _centres[n] - Vector3(3, 0, 3))
		_grids.append(g)
		var v := CarveView.new(g, 1000 + n)
		world.add_child(v)
		_views.append(v)
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = RADIUS
		sm.height = RADIUS * 2.0
		var smat := StandardMaterial3D.new()
		smat.albedo_color = Color(1.0, 0.45, 0.2, 0.35)
		smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.material = smat
		s.mesh = sm
		world.add_child(s)
		_spheres.append(s)
	var cam := Camera3D.new()
	cam.fov = 55.0
	world.add_child(cam)
	if _block:
		cam.look_at_from_position(Vector3(-26, 14, 34), Vector3(0, 6, 0))
	else:
		cam.look_at_from_position(Vector3(-14, 7, 20), Vector3(0, 7, 0))
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	process_frame.connect(_frame)


func _frame() -> void:
	_acc += root.get_process_delta_time()
	var sim_us := 0
	var mesh_us := 0
	while _acc >= TICK:
		_acc -= TICK
		_tick += 1
		for n: int in _grids.size():
			var t := _tick * TICK - n * 0.25
			if t < 0.0 or _tick * TICK > _hold:
				continue
			var at := path(_centres[n], t)
			_spheres[n].position = at
			var islands: Array[PackedInt32Array] = []
			var t0 := Time.get_ticks_usec()
			var removed := _grids[n].carve(at, RADIUS, islands)
			sim_us += Time.get_ticks_usec() - t0
			if removed.is_empty() and islands.is_empty():
				continue
			var ahead := (path(_centres[n], t + TICK) - at).normalized()
			_views[n].carved(removed, islands, ahead)
			mesh_us += _views[n].mesh_us
			for part: PackedInt32Array in islands:
				print("ISLAND t=%.2f building=%d cells=%d" % [t, n, part.size()])
	var vp := root.get_viewport_rid()
	var bodies := 0
	for v: CarveView in _views:
		bodies += v.bodies
	_stats["sim"].append(sim_us / 1000.0)
	_stats["mesh"].append(mesh_us / 1000.0)
	_stats["phys"].append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	_stats["proc"].append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_stats["gpu"].append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
	_stats["cpu"].append(RenderingServer.viewport_get_measured_render_time_cpu(vp))
	_stats["bodies"].append(float(bodies))
	if _tick * TICK >= _seconds:
		_report()
		quit()


func _report() -> void:
	var size := DisplayServer.window_get_size()
	print("SPIKE res=%d block=%s frames=%d window=%dx%d cells0=%d" % [
		_res, _block, _stats["sim"].size(), size.x, size.y, _grids[0].w * _grids[0].d * _grids[0].h
	])
	var g: Array = _stats["gpu"]
	var line := "  gpu by second:"
	for sec: int in g.size() / 60:
		var sum := 0.0
		for k: int in range(sec * 60, sec * 60 + 60):
			sum += g[k]
		line += " %.1f(%d)" % [sum / 60.0, int(_stats["bodies"][sec * 60 + 59])]
	print(line)
	for key: String in ["sim", "mesh", "phys", "proc", "cpu", "gpu", "bodies"]:
		var a: Array = _stats[key]
		var sorted := a.duplicate()
		sorted.sort()
		var total := 0.0
		for x: float in a:
			total += x
		print("  %-6s avg %7.2f  p95 %7.2f  max %7.2f" % [
			key, total / maxi(1, a.size()), sorted[int(sorted.size() * 0.95)], sorted[-1]
		])
