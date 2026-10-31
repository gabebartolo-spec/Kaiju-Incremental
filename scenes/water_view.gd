class_name WaterView
extends Node
## Draws the sim's liquid (WaterSim): each basin's surface heights go to a float texture every
## frame and the water sheets over it (WaterSurface) lift their vertices by it and take its slope
## into their normals (scenes/water.gdshader sim_*), so the waves on screen are the sim's own; a
## dry column sits at the still water, under the sand, and the sheet is never faded: the
## waterline is wherever the sheet passes under the sand, a smooth line that climbs and slides
## back with every wave (director 2026-10-31: fading on depth left splotches). Each splash the
## sim reports (a stomp, the rise) throws a burst of spray, the intro's droplets
## (tuning intro.water), sized by the splash. Presentation only: it reads the sim, never writes.

var _sim: RampageSim
var _cfg: Dictionary
var _sim_cfg: Dictionary
var _film := 0.0
var _images: Array[Image] = []
var _textures: Array[ImageTexture] = []
var _bytes: Array[PackedFloat32Array] = []
var _was_active: Array[bool] = []


func _init(sim: RampageSim) -> void:
	_sim = sim
	_cfg = Content.section("intro")["water"]
	_sim_cfg = Content.section("water_sim")
	_film = Num.f(_sim_cfg["film"])


func _ready() -> void:
	for basin: WaterSim.Basin in _sim.water.basins:
		var heights := PackedFloat32Array()
		heights.resize(basin.nx * basin.nz * 2)  # (surface, ground) per column
		_bytes.append(heights)
		var image := Image.create_from_data(
			basin.nx, basin.nz, false, Image.FORMAT_RGF, heights.to_byte_array()
		)
		_images.append(image)
		_textures.append(ImageTexture.create_from_image(image))
	_fill(true)
	_bind.call_deferred()  # the ground's sheets are in the tree by then


## Hands each sheet over a basin that basin's texture.
func _bind() -> void:
	for node: Node in get_tree().get_nodes_in_group(WaterSurface.GROUP):
		var mi := node as MeshInstance3D
		if mi == null:
			continue
		var mat := mi.material_override as ShaderMaterial
		if mat == null and mi.mesh != null:
			mat = mi.mesh.surface_get_material(0) as ShaderMaterial
		if mat == null or mat.shader != WaterSurface.SHADER:
			continue
		var box := mi.global_transform * mi.get_aabb()
		var flat := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
		for n: int in _sim.water.basins.size():
			var basin := _sim.water.basins[n]
			if flat.intersects(Rect2(basin.origin, basin.size())):
				mat.set_shader_parameter("sim_height", _textures[n])
				mat.set_shader_parameter("sim_origin", basin.origin)
				mat.set_shader_parameter("sim_size", basin.size())
				mat.set_shader_parameter("sim_on", 1.0)
				mat.set_shader_parameter("whitecap_slope", Num.f(_sim_cfg["whitecap_slope"]))
				mat.set_shader_parameter("whitecap_lift", Num.f(_sim_cfg["whitecap_lift"]))


func _process(_delta: float) -> void:
	_fill(false)
	for splash: Dictionary in _sim.water.splashes:
		var at: Vector3 = splash["pos"]
		_spray(at, Num.f(splash["size"]))
	_sim.water.splashes = []


## Writes the moving basins' heights (all of them, the first time).
func _fill(all: bool) -> void:
	for n: int in _sim.water.basins.size():
		var basin := _sim.water.basins[n]
		if not all and not basin.active.has_area() and not _stirred(n):
			continue
		var heights := _bytes[n]
		for k: int in basin.nx * basin.nz:
			var ground := _ground(basin, k)
			heights[2 * k] = 0.0  # dry: the still water, under the sand there, so the sand hides it
			if basin.depth[k] > 0.0:  # a film never sinks into the sand under it (it reads as water)
				heights[2 * k] = maxf(basin.lift(k), ground + _film)
			elif basin.body[k] > 0.0:
				heights[2 * k] = _around(basin, k, ground)
			heights[2 * k + 1] = ground
		_images[n].set_data(basin.nx, basin.nz, false, Image.FORMAT_RGF, heights.to_byte_array())
		_textures[n].update(_images[n])


## The water round a column his body has emptied: its wet neighbours' surface (his legs hide
## the sheet there), so his path never cuts a square notch in the waterline; ground if none.
func _around(basin: WaterSim.Basin, k: int, ground: float) -> float:
	var x := k % basin.nx
	var z := k / basin.nx
	var sum := 0.0
	var wet := 0
	for dz: int in range(-2, 3):
		for dx: int in range(-2, 3):
			var nx := x + dx
			var nz := z + dz
			if nx < 0 or nz < 0 or nx >= basin.nx or nz >= basin.nz:
				continue
			var n := nz * basin.nx + nx
			if basin.depth[n] > 0.0:
				sum += basin.lift(n)
				wet += 1
	return sum / wet if wet > 0 else ground


## A column's ground over the still water (land past the basin: the street).
func _ground(basin: WaterSim.Basin, k: int) -> float:
	return basin.floor_y[k] - basin.rest if basin.floor_y[k] < WaterSim.WALL else 0.0


## True the frame after a basin went to sleep (its last, settled heights still to draw).
func _stirred(n: int) -> bool:
	while _was_active.size() <= n:
		_was_active.append(false)
	var now := _sim.water.basins[n].active.has_area()
	var was := _was_active[n]
	_was_active[n] = now
	return was and not now


## A burst of spray thrown up from `at`, `size` metres across.
func _spray(at: Vector3, size: float) -> void:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3.UP
	mat.emission_ring_radius = size * 0.5
	mat.emission_ring_inner_radius = size * 0.2
	mat.emission_ring_height = size * 0.3
	mat.direction = Vector3.UP
	mat.spread = Num.f(_cfg["burst_spread"]) * 2.0
	var speed := sqrt(size) * Num.f(_cfg["burst_speed"]) * 0.5
	mat.initial_velocity_min = speed * 0.5
	mat.initial_velocity_max = speed
	mat.gravity = Vector3(0, -Num.f(_cfg["gravity"]), 0)
	mat.scale_min = Num.f(_cfg["drop_min"])
	mat.scale_max = 1.0
	var hues: Array = _cfg["colors"]
	mat.color_initial_ramp = IntroWater.tones(hues, false)
	mat.color_ramp = IntroWater.tones(["ffffffff", "ffffff00"], true)
	var p := GPUParticles3D.new()
	p.process_material = mat
	p.draw_pass_1 = IntroWater.puff(Num.f(_cfg["drop"]) * maxf(0.5, size * 0.3))
	p.amount = clampi(roundi(size * size * 40.0), 40, roundi(Num.f(_cfg["burst_amount"])))
	p.lifetime = Num.f(_cfg["life"])
	p.one_shot = true
	p.explosiveness = 0.6  # a column that keeps pouring up for a moment, not one pop
	p.visibility_aabb = AABB(Vector3(-20, -2, -20) * size, Vector3(40, 30, 40) * size)
	p.position = at
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
