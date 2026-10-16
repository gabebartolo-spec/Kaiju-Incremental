class_name CityView
extends Node3D
## The voxel city and its effects: sky and light, ground, buildings (BuildingView: voxels by
## structural chunk), falling sections, physics debris, fires, dust and sparks (Fx), rings,
## flames and floating text. Draws only; RampageSim decides what breaks and what falls.

const MAX_DEBRIS := 600
const DEBRIS_PER_CHUNK := 8
const DEBRIS_PER_LANDING := 160
const MAX_FIRES := 30

var sim: RampageSim
var fx: Fx
var _rng: RandomNumberGenerator
var _views: Array[BuildingView] = []
var _falling: Dictionary = {}
var _ruin_tasks: Array[int] = []
var _flame_mesh: BoxMesh
var _flame_color := Color.BLACK
var _decor: CityDecor
var _fires: Array[Fire] = []
var _debris: DebrisField

var _with_decor := true


## with_decor false: an empty stage (no streets, cars or trees), e.g. a model line-up.
func _init(p_sim: RampageSim, rng: RandomNumberGenerator, with_decor: bool = true) -> void:
	sim = p_sim
	_rng = rng
	_with_decor = with_decor


func _ready() -> void:
	_build_environment()
	_build_ground()
	var party := BuildingView.party_walls(sim.buildings)
	for i: int in sim.buildings.size():
		var b := sim.buildings[i]
		var sides: Array[Vector2i] = []
		sides.assign(party[i])
		var view := BuildingView.new(b, _base_color(b), sides)
		add_child(view)
		_views.append(view)
	fx = Fx.new()
	add_child(fx)
	_debris = DebrisField.new(_rng, MAX_DEBRIS)
	add_child(_debris)
	_prewarm_fire()
	if _with_decor:
		_decor = CityDecor.new(sim, Seeds.make("decor", 0))
		add_child(_decor)


## Cars, trees and lights under a stomp go flat.
func crush(at: Vector3, radius: float) -> void:
	if _decor != null:
		_decor.crush(at, radius)


func _process(delta: float) -> void:
	_animate_falls(delta)


func _build_environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Look.color("sky_top")
	sky_mat.sky_horizon_color = Look.color("sky_horizon")
	sky_mat.ground_horizon_color = Look.color("sky_horizon")
	sky_mat.ground_bottom_color = Look.color("sky_horizon")
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	if Content.look().has("ambient_color"):
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Look.color("ambient_color")
	env.ambient_light_energy = Look.value("ambient")
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	env.ssao_intensity = 2.5
	env.ssao_radius = 1.5
	env.fog_enabled = Look.value("fog_density") > 0.0
	env.fog_light_color = Look.color("fog_color")
	env.fog_density = Look.value("fog_density")
	env.glow_enabled = Look.value("glow") > 0.0
	env.glow_intensity = Look.value("glow")
	env.glow_hdr_threshold = 1.1
	# Light bounces: lamps, fires and the sun colour the streets and walls around them
	# (screen-space; full SDFGI cost about a tenth of the frame for little gain here).
	env.ssil_enabled = true
	env.adjustment_enabled = true
	env.adjustment_saturation = Look.value("saturation")
	env.adjustment_contrast = Look.value("contrast")
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(Look.value("sun_pitch"), -35, 0)
	sun.light_energy = Look.value("sun_energy")
	sun.light_color = Look.color("sun_color")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160.0
	sun.shadow_blur = 1.5
	sun.light_angular_distance = 1.0
	add_child(sun)


## The street plan's ground and, round a real city, the outskirts, the bay and the skyline.
func _build_ground() -> void:
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(800.0, 1.0, 800.0)
	shape.shape = box_shape
	shape.position.y = -0.5
	ground.add_child(shape)
	add_child(ground)
	var streets := CityGround.new(sim.city)
	add_child(streets)
	if _with_decor:
		add_child(CitySkyline.new(streets, Seeds.make("skyline", 0)))


func slab(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	add_child(mi)
	return mi


func _base_color(b: RampageSim.Building) -> Color:
	var styles := Look.styles()
	return styles[posmod(b.style + roundi(b.x * 3.0 + b.z), styles.size())]


## The first fire compiles its particle shaders; do it now, out of sight, not mid-rampage.
func _prewarm_fire() -> void:
	var f := Fire.new(0.5, 0.0)
	f.position = Vector3(0, -60, 0)
	add_child(f)
	get_tree().create_timer(1.0).timeout.connect(f.queue_free)


## Chunks broke: their voxels vanish, some fly off as physics debris, dust puffs out.
func chunks_broken(index: int, cells: Array[Vector3i], kaiju_at: Vector3) -> void:
	var view := _views[index]
	var parts := view.hide_chunks(cells)
	parts.append_array(view.chip(cells, _rng))
	var b := sim.buildings[index]
	var centre := Vector3(b.x, 0, b.z)
	var away := (centre - Vector3(kaiju_at.x, 0, kaiju_at.z)).normalized()
	var budget := mini(parts.size(), cells.size() * DEBRIS_PER_CHUNK)
	for n: int in budget:
		var part: Dictionary = parts[_rng.randi_range(0, parts.size() - 1)]
		var pos: Vector3 = part["pos"]
		var color: Color = part["color"]
		debris(pos, color, away)
	var mid := Vector3.ZERO
	for c: Vector3i in cells:
		mid += b.chunk_world(c)
	if cells.size() >= 4:  # only a real collapse throws up a dust cloud
		fx.dust(mid / maxi(1, cells.size()), 0.5 + cells.size() * 0.05)
	if _rng.randf() < 0.18:  # broken floors sometimes catch fire
		fire(mid / maxi(1, cells.size()), 0.35)
	_ruin_if_gone(index)


## A section starts to fall: lift its voxels into a piece that topples or drops.
func fall_start(event: Dictionary) -> void:
	var index := Num.i(event["building"])
	var cells: Array[Vector3i] = event["cells"]
	var pivot: Vector3 = event["pivot"]
	var piece := _views[index].lift_piece(cells, pivot)
	add_child(piece)
	_falling[Num.i(event["id"])] = {
		"node": piece,
		"kind": str(event["kind"]),
		"dir": event["dir"],
		"drop": Num.f(event["drop"]),
		"duration": maxf(0.05, Num.f(event["duration"])),
		"t": 0.0,
	}
	fx.dust(pivot + Vector3(0, 0.5, 0), 1.0)
	_ruin_if_gone(index)


## Gravity drives it: the angle (topple) or the drop grows with the square of time.
func _animate_falls(delta: float) -> void:
	for id: int in _falling:
		var f: Dictionary = _falling[id]
		var node: Node3D = f["node"]
		f["t"] = Num.f(f["t"]) + delta
		var k := clampf(Num.f(f["t"]) / Num.f(f["duration"]), 0.0, 1.0)
		if str(f["kind"]) == "topple":
			var dir: Vector2 = f["dir"]
			var axis := Vector3(dir.y, 0, -dir.x).normalized()
			node.basis = Basis(axis, PI * 0.5 * k * k)
		else:
			node.position.y = (
				node.position.y - (Num.f(f["drop"]) * k * k - Num.f(f.get("dropped", 0.0)))
			)
			f["dropped"] = Num.f(f["drop"]) * k * k


## A section hit the ground (or what was below it): it bursts into debris and dust.
func fall_land(event: Dictionary) -> void:
	var id := Num.i(event["id"])
	if not _falling.has(id):
		return
	var f: Dictionary = _falling[id]
	_falling.erase(id)
	var node: Node3D = f["node"]
	var parts: Array = node.get_meta("parts", [])
	var landed: Array[Vector3] = []
	for n: int in mini(parts.size(), DEBRIS_PER_LANDING):
		var part: Dictionary = parts[_rng.randi_range(0, parts.size() - 1)]
		var pos: Vector3 = part["pos"]
		var pivot: Vector3 = node.get_meta("pivot")
		var at := node.global_transform * (pos - pivot)
		landed.append(at)
		var color: Color = part["color"]
		debris(at, color, Vector3.UP)
	node.queue_free()
	if str(event["kind"]) == "topple":
		var from: Vector2 = event["from"]
		var to: Vector2 = event["to"]
		var width := Num.f(event["width"])
		var a := Vector3(from.x, 0, from.y)
		var b := Vector3(to.x, 0, to.y)
		fx.dust_line(a, b, width)
		_rubble_strip(Num.i(event["building"]), a, b, width)
		var steps := maxi(1, ceili(a.distance_to(b) / 1.5))
		for i: int in steps + 1:
			crush(a.lerp(b, float(i) / steps), width * 0.6)
	elif not landed.is_empty():
		fx.dust(landed[0], 1.5)


## A rubble pile where a tower came down across the street, built on a worker thread (a tall
## tower's strip is thousands of voxels) and added when ready.
func _rubble_strip(building: int, a: Vector3, b: Vector3, width: float) -> void:
	var voxels := _views[building].voxels
	var task := WorkerThreadPool.add_task(
		func() -> void:
			var mmi := Ruin.strip(voxels, a, b, width)
			_attach_ruin.call_deferred(mmi)
	)
	_ruin_tasks.append(task)


## Builds the ruin on a worker thread (it is thousands of voxels) and adds it when ready.
func _add_ruin(index: int) -> void:
	var voxels := _views[index].voxels
	var rng := Seeds.make("ruin", index)
	var task := WorkerThreadPool.add_task(
		func() -> void:
			var mmi := Ruin.build(voxels, rng)
			_attach_ruin.call_deferred(mmi)
	)
	_ruin_tasks.append(task)


func _attach_ruin(mmi: MultiMeshInstance3D) -> void:
	if is_inside_tree():
		add_child(mmi)
	else:
		mmi.free()


## Never leave the scene while a ruin is still being built on another thread.
func _exit_tree() -> void:
	for task: int in _ruin_tasks:
		WorkerThreadPool.wait_for_task_completion(task)
	_ruin_tasks.clear()


func _ruin_if_gone(index: int) -> void:
	var b := sim.buildings[index]
	if b.frame.alive_count == 0 and not _views[index].has_meta("ruined"):
		_views[index].set_meta("ruined", true)
		var size := clampf(b.w * b.d / 9.0, 0.6, 2.5)
		var heap_top := 2.4 + 0.9 * b.tier  # flames sit on top of the rubble heap
		fire(Vector3(b.x, heap_top, b.z), size)
		fire(Vector3(b.x + b.w * 0.3, heap_top * 0.6, b.z - b.d * 0.25), size * 0.6)
		_add_ruin(index)


func debris(pos: Vector3, color: Color, away: Vector3) -> void:
	_debris.spawn(pos, color, away)


## A fire that keeps burning (ruins, wrecks); the oldest goes out past the cap.
func fire(at: Vector3, size: float) -> void:
	var f := Fire.new(size, _rng.randf() * 10.0)
	f.position = at
	add_child(f)
	_fires.append(f)
	if _fires.size() > MAX_FIRES:
		var old: Fire = _fires.pop_front()
		old.queue_free()


## A short burst of real light (muzzle flash, explosion, breath).
func flash(at: Vector3, color: Color, energy: float, seconds: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 3.0 + energy
	light.position = at
	add_child(light)
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, seconds)
	tween.tween_callback(light.queue_free)


## A burst of glowing voxels from `from` over a cone along `span` (direction times reach).
func flame_cone(from: Vector3, ground_at: Vector3, span: Vector3, color: Color) -> void:
	for _n: int in 40:
		var spread := span.rotated(Vector3.UP, _rng.randf_range(-0.5, 0.5))
		var target := ground_at + spread * _rng.randf_range(0.4, 1.0) + Vector3(0, 0.5, 0)
		_flame_voxel(from, target, color)


func _flame_voxel(from: Vector3, to: Vector3, color: Color) -> void:
	if _flame_mesh == null or _flame_mesh.material != null and _flame_color != color:
		_flame_color = color
		_flame_mesh = BoxMesh.new()
		_flame_mesh.material = glow(color, 3.0)
	var mi := MeshInstance3D.new()
	mi.mesh = _flame_mesh
	mi.scale = Vector3.ONE * _rng.randf_range(0.5, 1.1)
	mi.position = from
	add_child(mi)
	var tween := mi.create_tween()
	tween.tween_property(mi, "position", to, _rng.randf_range(0.18, 0.35))
	tween.tween_property(mi, "scale", Vector3.ONE * 0.01, 0.2)
	tween.tween_callback(mi.queue_free)


static func glow(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat


## An expanding, fading ring on the ground around `centre`.
func ring(centre: Vector3, radius: float, color: Color, seconds: float) -> void:
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	torus.material = mat
	mi.mesh = torus
	mi.position = Vector3(centre.x, 0.3, centre.z)
	mi.scale = Vector3(0.2, 0.3, 0.2)
	add_child(mi)
	var tween := mi.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mi, "scale", Vector3(radius, 0.3, radius), seconds)
	tween.tween_property(mat, "albedo_color:a", 0.0, seconds)
	tween.chain().tween_callback(mi.queue_free)


func float_text(text: String, pos: Vector3, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 96
	l.outline_size = 24
	l.modulate = color
	l.no_depth_test = true
	l.position = pos
	add_child(l)
	var tween := l.create_tween()
	tween.set_parallel(true)
	tween.tween_property(l, "position", pos + Vector3(0, 3, 0), 1.0)
	tween.tween_property(l, "modulate:a", 0.0, 1.0).set_delay(0.4)
	tween.chain().tween_callback(l.queue_free)
