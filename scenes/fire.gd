class_name Fire
extends Node3D
## A burning ruin: a flickering orange light that really lights the street, voxel flames rising
## and shrinking, embers drifting up, and a thick column of dark smoke that leans with the wind.
## Presentation only.

const SMOKE_SHADER := preload("res://scenes/smoke.gdshader")
const EMBER_SHADER := preload("res://scenes/ember.gdshader")
const FLAME_COLORS: Array[Color] = [
	Color("fff0b8"), Color("ff9a1e"), Color("e04a0c"), Color("3a1a10")
]
const WIND := Vector3(2.2, 0.0, 0.9)

var _light: PooledLight
var _base_energy: float
var _t := 0.0
var _seed: float
var _life := 0.0  # the longest particle lifetime: what is in the air when it goes out
var _out := false
## 1 for a fire in the street; more for one seen from far away (the title's burning towers): the
## same fire with every size, speed and distance multiplied by it, so it reads at that range as
## the same flames and smoke. Such a fire has no light of its own (its owner draws a glow).
var _zoom := 1.0
## How much of `_zoom` the smoke takes (the column would otherwise fill the sky).
var _smoke_zoom := 1.0
## Particle count multiplier for a zoomed fire (its picture is zoom squared bigger).
var _density := 1.0
## The wind: a zoomed fire's leans sideways only (toward the camera it would fan the columns out).
var _wind := WIND
## How much bigger a zoomed fire's smoke puffs are than its zoom alone makes them.
var _puff := 1.0


## far: {} for a fire in the street, else {"zoom", "smoke_share", "density"} (see above).
func _init(size: float, seed_value: float, far := {}) -> void:
	_seed = seed_value
	var zoom := Num.f(far["zoom"]) if not far.is_empty() else 1.0
	_zoom = zoom
	_smoke_zoom = maxf(1.0, zoom * Num.f(far["smoke_share"])) if not far.is_empty() else 1.0
	_density = Num.f(far["density"]) if not far.is_empty() else 1.0
	if not far.is_empty():
		_wind = Vector3(WIND.x * Num.f(far["wind"]), 0.0, 0.0)
		_puff = Num.f(far["puff"])
	_base_energy = 2.5 + size * 1.2
	if zoom <= 1.0:
		_light = PooledLight.new("fire")
		_light.light_color = Color("ff9a4a")
		_light.omni_range = 4.0 + size * 2.0
		_light.set_energy(_base_energy)
		_light.position = Vector3(0, 1.0 + size * 0.5, 0)
		add_child(_light)
	add_child(_flames(size))
	add_child(_embers(size))
	add_child(_smoke(size))


## The first fire compiles its particle shaders; do it now, out of sight, not mid-rampage.
static func prewarm(parent: Node) -> void:
	var f := Fire.new(0.5, 0.0)
	f.position = Vector3(0, -60, 0)
	parent.add_child(f)
	parent.get_tree().create_timer(1.0).timeout.connect(f.queue_free)


## Stops burning: the light goes off and no new flame, ember or smoke rises; what is already in the
## air finishes its life, then the node frees itself.
func go_out() -> void:
	if _out:
		return
	_out = true
	_base_energy = 0.0
	if _light != null:
		_light.set_energy(0.0)
	for child: Node in get_children():
		if child is GPUParticles3D:
			(child as GPUParticles3D).emitting = false
	if is_inside_tree():
		get_tree().create_timer(_life).timeout.connect(queue_free)
	else:
		queue_free()


func is_out() -> bool:
	return _out


func _process(delta: float) -> void:
	if _light == null:
		return
	_t += delta
	var flicker := 0.75 + 0.15 * sin(_t * 17.0 + _seed) + 0.1 * sin(_t * 31.0 + _seed * 2.0)
	_light.set_energy(_base_energy * flicker)


func _flames(size: float) -> GPUParticles3D:
	var z := _zoom
	var mat := _base(size * 0.6 * z, 12.0, Vector3(0, 2.5, 0) * z, Vector2(0.8, 2.0) * z)
	_scale(mat, Vector2(0.5, 1.2) * z, Vector2(1.0, 0.1))
	_ramp(mat, PackedColorArray(FLAME_COLORS), PackedFloat32Array([0.0, 0.1, 0.55, 1.0]))
	return _system(mat, _cube(0.18, true), roundi(130 * maxf(1.0, size) * _density), 1.0)


func _embers(size: float) -> GPUParticles3D:
	var z := _zoom
	var gravity := (_wind * 0.6 + Vector3(0, 1.2, 0)) * z
	var mat := _base(size * 0.8 * z, 35.0, gravity, Vector2(1.5, 4.0) * z)
	_scale(mat, Vector2(0.4, 1.0) * z, Vector2(1.0, 0.3))
	_ramp(mat, PackedColorArray([Color("ffe9a0"), Color("ff6a1a")]), PackedFloat32Array([0.0, 1.0]))
	return _system(mat, _cube(0.1, true), roundi(45 * maxf(1.0, size) * _density), 3.2)


## Thick charcoal smoke rising in a column and leaning with the wind; dense at the base.
func _smoke(size: float) -> GPUParticles3D:
	var z := _smoke_zoom
	var gravity := (_wind * 0.8 + Vector3(0, 2.2, 0)) * z
	var mat := _base(size * 0.5 * z, 6.0, gravity, Vector2(2.5, 4.0) * z)
	_scale(mat, Vector2(1.6, 3.0) * z * _puff, Vector2(0.7, 3.4))
	_ramp(
		mat,
		PackedColorArray(
			[
				Color(0.05, 0.05, 0.05, 0.0),
				Color(0.1, 0.1, 0.11, 0.46),
				Color(0.2, 0.2, 0.22, 0.32),
				Color(0.22, 0.23, 0.25, 0.0),
			]
		),
		PackedFloat32Array([0.0, 0.08, 0.6, 1.0])
	)
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.7) * (1.4 + size * 0.5)  # taller than wide: a rising column
	var draw := ShaderMaterial.new()
	draw.shader = SMOKE_SHADER
	if _zoom > 1.0:
		# Far away nothing is "near the camera" or "in front of the kaiju": no clearing at all.
		draw.set_shader_parameter("near_clear", 0.0)
		draw.set_shader_parameter("near_full", 0.01)
		draw.set_shader_parameter("centre_keep", 1.0)
	quad.material = draw
	var p := _system(mat, quad, roundi(70 * maxf(1.0, size) * sqrt(_density)), 10.0)
	p.position.y = 1.8 * _zoom  # smoke starts above the flames, so their light does not wash it out
	p.visibility_aabb = AABB(Vector3(-20, -2, -20) * _smoke_zoom, Vector3(40, 50, 40) * _smoke_zoom)
	return p


func _base(
	spread_box: float, spread: float, gravity: Vector3, speed: Vector2
) -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(spread_box, 0.2, spread_box)
	mat.direction = Vector3.UP
	mat.spread = spread
	mat.gravity = gravity
	mat.initial_velocity_min = speed.x
	mat.initial_velocity_max = speed.y
	return mat


func _scale(mat: ParticleProcessMaterial, span: Vector2, over_life: Vector2) -> void:
	mat.scale_min = span.x
	mat.scale_max = span.y
	var curve := Curve.new()
	curve.add_point(Vector2(0, over_life.x))
	curve.add_point(Vector2(1, over_life.y))
	var tex := CurveTexture.new()
	tex.curve = curve
	mat.scale_curve = tex


func _ramp(
	mat: ParticleProcessMaterial, colors: PackedColorArray, offsets: PackedFloat32Array
) -> void:
	var ramp := Gradient.new()
	ramp.colors = colors
	ramp.offsets = offsets
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	mat.color_ramp = tex


func _system(mat: ParticleProcessMaterial, mesh: Mesh, amount: int, life: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.process_material = mat
	p.draw_pass_1 = mesh
	p.amount = amount
	p.lifetime = life
	_life = maxf(_life, life)
	p.position = Vector3(0, 0.2 * _zoom, 0)
	return p


func _cube(size: float, glowing: bool) -> BoxMesh:
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * size
	if glowing:
		var hot := ShaderMaterial.new()
		hot.shader = EMBER_SHADER
		cube.material = hot
		return cube
	var draw := StandardMaterial3D.new()
	draw.vertex_color_use_as_albedo = true
	cube.material = draw
	return cube
