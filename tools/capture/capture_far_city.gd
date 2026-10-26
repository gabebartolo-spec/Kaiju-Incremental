extends SceneTree
## The far city in the haze (director comment #37, 2026-10-25: "something funky going on with the
## distant city"; his screenshot: the skyline floats crisp above the haze). A real rampage (the flow
## test's city, the reptilian risen and then stood on the play area's north edge at the foot of a
## north-south street, the HUD up, no debug UI) at --time, the game camera at rest behind it above
## that street, looking north over the quay and the bay to the far skyline. Writes, in --out:
##   far_city_<time>_<tag>_4k.png  the still (the window's size: 4K with the off-screen no_focus
##                                 override.cfg)
##   <time>_<tag>_again.png        the next frame (what only animation changes)
##   <time>_<tag>_nofar.png        the far skyline hidden (towers, quay, lattice, far rampage)
##   <time>_<tag>_nobay.png        the bay's water hidden
##   <time>_<tag>.json             the share of fog along the camera's centre line, play city
##                                 edge to the far city's back row (engine depth fog from the
##                                 live environment, then the far materials' own haze and
##                                 height fog, as they are drawn)
##   <time>_<tag>_sweep_a<amount>_b<base>.png  with --sweep=amount:base,...: the far haze at each
##                                 (own haze share, height fog at the foot), for tuning city far_fog
## tools/capture/far_city_bars.py turns them into the PR's numbers. One time of day per process
## (BuildingView keeps its baked lit windows per time).
##   godot --path . --windowed --fixed-fps 60 --script tools/capture/capture_far_city.gd -- \
##     --out=<dir> --tag=after --time=night [--settle=600] [--walk=300] [--sweep=0:0,0:0.5]

const Kit := preload("res://tools/capture/capture_kit.gd")
const SPECIES := "reptilian"
const FRAMES_BETWEEN := 3  # frames after a change before a grab, so it is drawn
const ROW_STEP := 26.0  # CitySkyline._far_shore: a far row stands this much behind the last
const FAR_ROWS := 6  # ...and downtown has up to this many
const FRONT := 12.0  # the first far row stands this far behind the far shore line
const CROWN_Y := 60.0  # a tall far tower's upper floors
const FOOT_Y := 1.0

var _a := {}


func _initialize() -> void:
	_a = Kit.args(
		{"out": "", "tag": "before", "time": "night", "settle": 600, "walk": 300, "sweep": ""}
	)
	if str(_a["out"]) == "" or not Kit.window_ok():
		printerr("capture_far_city: needs --out and a window (no_focus override.cfg)")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(str(_a["out"]))
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var time := str(_a["time"])
	var rampage := Kit.rampage(SPECIES, Kit.stats(SPECIES), Content.times().find(time))
	root.add_child(rampage)
	await rampage.wait_loaded()
	await Kit.frames(self, Num.i(_a["settle"]))  # risen from the river
	var skyline: CitySkyline = rampage.find_children("*", "CitySkyline", true, false)[0]
	rampage.sim.kaiju_pos = _north_edge(skyline.ground, CityGen.half_extent(rampage.sim.city))
	await Kit.frames(self, Num.i(_a["walk"]))  # there, the camera at rest behind it
	paused = true
	await Kit.frames(self, FRAMES_BETWEEN)
	var stem := "%s_%s" % [time, str(_a["tag"])]
	Kit.still(self, str(_a["out"]), "far_city_%s_4k" % stem)
	await Kit.frames(self, FRAMES_BETWEEN)
	Kit.still(self, str(_a["out"]), stem + "_again")
	var far := _far_nodes(rampage, skyline)
	await _grab_hidden(far, stem + "_nofar")
	await _grab_hidden([_bay(skyline.ground)], stem + "_nobay")
	_write_fog(rampage, skyline, stem)
	await _sweep(skyline, stem)
	print("capture_far_city: %s done" % stem)
	quit()


## On the play area's north edge (`half` from the centre): the ring avenue at the foot of the
## north-south street nearest the centre, so the camera behind rides above the street, not a roof.
func _north_edge(ground: CityGround, half: float) -> Vector2:
	var nodes: Array[Vector2] = ground.plan["nodes"]
	var best := Vector2(INF, -half)
	for street: Dictionary in ground.plan["streets"]:
		var a := nodes[Num.i(street["from"])]
		var b := nodes[Num.i(street["to"])]
		var ring := absf(minf(a.y, b.y) + half) < 1.0 and maxf(a.y, b.y) > -half + 1.0
		if ring and absf(a.x - b.x) < 0.5 and absf(a.x) < absf(best.x):
			best = Vector2(a.x, -half)
	return best if best.x != INF else Vector2(0.0, -half)


## Hides `nodes`, grabs <stem>.png, shows them again.
func _grab_hidden(nodes: Array, shot_name: String) -> void:
	for node: Node3D in nodes:
		node.visible = false
	await Kit.frames(self, FRAMES_BETWEEN)
	Kit.still(self, str(_a["out"]), shot_name)
	for node: Node3D in nodes:
		node.visible = true
	await Kit.frames(self, FRAMES_BETWEEN)


## --sweep: the far haze at each amount:base pair in turn (FarHaze.set_haze), one still each.
func _sweep(skyline: CitySkyline, stem: String) -> void:
	for pair: String in str(_a["sweep"]).split(",", false):
		var amount := pair.get_slice(":", 0)
		var base := pair.get_slice(":", 1)
		skyline.set_far_haze(skyline.far_haze.color, amount.to_float(), base.to_float())
		await Kit.frames(self, FRAMES_BETWEEN)
		Kit.still(self, str(_a["out"]), "%s_sweep_a%s_b%s" % [stem, amount, base])


## The far skyline as drawn: its towers, the hazy plain boxes (far quay, lattice tower) and the
## far rampage (the insectoid, its fires and smoke).
func _far_nodes(rampage: Node, skyline: CitySkyline) -> Array:
	var out: Array = [skyline.far_view]
	for mmi: MultiMeshInstance3D in skyline.find_children("*", "MultiMeshInstance3D", true, false):
		var mesh := mmi.multimesh.mesh if mmi.multimesh != null else null
		var mat := mesh.surface_get_material(0) as ShaderMaterial if mesh != null else null
		if mat != null and _param(mat, "haze") > 0.0 and mmi != skyline.far_view:
			out.append(mmi)
	out.append_array(rampage.find_children("*", "SkylineRampage", true, false))
	return out


## The bay's water sheet (CityGround._water: the one sheet reaching far north of the quay).
func _bay(ground: CityGround) -> Node3D:
	for mesh: MeshInstance3D in ground.find_children("*", "MeshInstance3D", true, false):
		if (mesh.global_transform * mesh.get_aabb()).position.z < ground.coast - 500.0:
			return mesh
	return null


## The share of fog at points along the camera's centre line on the ground, nearest first.
func _write_fog(rampage: Node, skyline: CitySkyline, stem: String) -> void:
	var cam := Kit.game_camera(self)
	var env: Environment = null
	for world: WorldEnvironment in rampage.find_children("*", "WorldEnvironment", true, false):
		if world.get_viewport() == root:  # the city's, not the far beast's little world
			env = world.environment
	var density := env.fog_density if env.fog_enabled else 0.0
	var mat := skyline.far_view.multimesh.mesh.surface_get_material(0) as ShaderMaterial
	var fogged := not mat.shader.code.contains("render_mode fog_disabled")
	var shore := skyline.ground.coast - Num.f(skyline.cfg["bay_width"])
	var points := [
		["play city north edge", -Num.f(skyline.cfg["half"]), FOOT_Y, false],
		["bay near (quay +10 m)", skyline.ground.coast - 10.0, CityGround.WATER_Y, false],
		["bay mid", (skyline.ground.coast + shore) * 0.5, CityGround.WATER_Y, false],
		["bay far (far shore +10 m)", shore + 10.0, CityGround.WATER_Y, false],
		["far city front row foot", shore - FRONT, FOOT_Y, true],
		["far city front row crown", shore - FRONT, CROWN_Y, true],
		["far city back row foot", shore - FRONT - ROW_STEP * (FAR_ROWS - 1), FOOT_Y, true],
	]
	var rows: Array = []
	for p: Array in points:
		var at := Vector3(cam.global_position.x, Num.f(p[2]), Num.f(p[1]))
		var metres := cam.global_position.distance_to(at)
		var engine := 1.0 - exp(-metres * density)
		var share := engine
		if p[3] == true:
			var own := _own_haze(mat, metres, at.y)
			share = 1.0 - (1.0 - own) * (1.0 - engine) if fogged else own
		rows.append({"where": p[0], "metres": snappedf(metres, 0.1), "fog": snappedf(share, 0.001)})
	var out := {
		"time": str(_a["time"]),
		"tag": str(_a["tag"]),
		"fog_density": density,
		"far_takes_engine_fog": fogged,
		"far_shader": mat.shader.resource_path,
		"far_fog": skyline.cfg.get("far_fog", {}),
		"camera": [cam.global_position.x, cam.global_position.y, cam.global_position.z],
		"line": rows,
	}
	var file := FileAccess.open(str(_a["out"]).path_join(stem + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(out, "  "))


## The far skyline's own haze at `metres` and `height` (facade.gdshaderinc FAR_HAZE, as drawn;
## haze_base is the height fog, absent before the fix).
func _own_haze(mat: ShaderMaterial, metres: float, height: float) -> float:
	var haze := _param(mat, "haze")
	var start := _param(mat, "haze_start")
	var f := clampf(1.0 - exp(-maxf(metres - start, 0.0) * haze), 0.0, 0.94)
	var base := _param(mat, "haze_base")
	if base <= 0.0:
		return f
	var rise := _param(mat, "haze_base_height")
	var ramp := smoothstep(start * 0.5, start, metres)
	return clampf(f + (1.0 - f) * base * exp(-maxf(height, 0.0) / rise) * ramp, 0.0, 0.97)


## A uniform as drawn: the value set on `mat`, else the shader's default, else 0 (no such uniform).
func _param(mat: ShaderMaterial, uniform: String) -> float:
	var v: Variant = mat.get_shader_parameter(uniform)
	if v == null:
		v = RenderingServer.shader_get_parameter_default(mat.shader.get_rid(), uniform)
	return 0.0 if v == null else Num.f(v)
