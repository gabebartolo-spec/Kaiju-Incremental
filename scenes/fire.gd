class_name Fire
extends Node3D
## A burning ruin: a flickering orange light that really lights the street, voxel flames rising
## and shrinking, embers drifting up, and a thick column of dark smoke that leans with the wind.
## Presentation only.

const SMOKE_SHADER := preload("res://scenes/smoke.gdshader")
const FLAME_COLORS: Array[Color] = [
	Color("fff1a0"), Color("ffb040"), Color("e85a1c"), Color("5a2a18")
]
const WIND := Vector3(0.9, 0.0, 0.4)

var _light: OmniLight3D
var _base_energy: float
var _t := 0.0
var _seed: float


func _init(size: float, seed_value: float) -> void:
	_seed = seed_value
	_base_energy = 2.0 + size
	_light = OmniLight3D.new()
	_light.light_color = Color("ff9a4a")
	_light.omni_range = 4.0 + size * 2.0
	_light.light_energy = _base_energy
	_light.position = Vector3(0, 1.0 + size * 0.5, 0)
	add_child(_light)
	add_child(_flames(size))
	add_child(_embers(size))
	add_child(_smoke(size))


func _process(delta: float) -> void:
	_t += delta
	var flicker := 0.75 + 0.15 * sin(_t * 17.0 + _seed) + 0.1 * sin(_t * 31.0 + _seed * 2.0)
	_light.light_energy = _base_energy * flicker


func _flames(size: float) -> GPUParticles3D:
	var mat := _base(size * 0.6, 12.0, Vector3(0, 2.5, 0), Vector2(0.8, 2.0))
	_scale(mat, Vector2(0.6, 1.4), Vector2(1.0, 0.1))
	_ramp(mat, PackedColorArray(FLAME_COLORS), PackedFloat32Array([0.0, 0.3, 0.65, 1.0]))
	return _system(mat, _cube(0.25, true), roundi(40 * maxf(1.0, size)), 0.9)


func _embers(size: float) -> GPUParticles3D:
	var mat := _base(size * 0.8, 35.0, WIND * 0.6 + Vector3(0, 1.2, 0), Vector2(1.5, 4.0))
	_scale(mat, Vector2(0.4, 1.0), Vector2(1.0, 0.3))
	_ramp(mat, PackedColorArray([Color("ffe9a0"), Color("ff6a1a")]), PackedFloat32Array([0.0, 1.0]))
	return _system(mat, _cube(0.08, true), roundi(20 * maxf(1.0, size)), 2.8)


func _smoke(size: float) -> GPUParticles3D:
	var mat := _base(size * 0.7, 18.0, WIND + Vector3(0, 0.5, 0), Vector2(1.2, 2.2))
	_scale(mat, Vector2(1.6, 3.2), Vector2(0.5, 2.2))
	_ramp(
		mat,
		PackedColorArray(
			[
				Color(0.12, 0.11, 0.11, 0.0),
				Color(0.16, 0.15, 0.15, 0.85),
				Color(0.32, 0.32, 0.34, 0.0)
			]
		),
		PackedFloat32Array([0.0, 0.12, 1.0])
	)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * (1.4 + size * 0.5)
	var draw := ShaderMaterial.new()
	draw.shader = SMOKE_SHADER
	quad.material = draw
	var p := _system(mat, quad, roundi(26 * maxf(1.0, size)), 7.0)
	p.position.y = 0.8
	p.visibility_aabb = AABB(Vector3(-20, -2, -20), Vector3(40, 40, 40))
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
	p.position = Vector3(0, 0.2, 0)
	return p


func _cube(size: float, glowing: bool) -> BoxMesh:
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * size
	var draw := StandardMaterial3D.new()
	draw.vertex_color_use_as_albedo = true
	if glowing:
		draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cube.material = draw
	return cube
