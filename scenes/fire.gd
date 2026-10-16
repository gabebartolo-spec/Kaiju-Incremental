class_name Fire
extends Node3D
## A burning ruin: a flickering orange light that really lights the street, voxel flames
## rising and shrinking, and a column of grey smoke. Presentation only.

const FLAME_COLORS: Array[Color] = [
	Color("fff1a0"), Color("ffb040"), Color("e85a1c"), Color("5a2a18")
]

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
	add_child(_particles(size, true))
	add_child(_particles(size, false))


func _process(delta: float) -> void:
	_t += delta
	var flicker := 0.75 + 0.15 * sin(_t * 17.0 + _seed) + 0.1 * sin(_t * 31.0 + _seed * 2.0)
	_light.light_energy = _base_energy * flicker


func _particles(size: float, flames: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = roundi((40 if flames else 24) * maxf(1.0, size))
	p.lifetime = 0.9 if flames else 3.5
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(size * 0.6, 0.2, size * 0.6)
	mat.direction = Vector3.UP
	mat.spread = 12.0
	mat.gravity = Vector3(0, 2.5 if flames else 0.6, 0)
	mat.initial_velocity_min = 0.8 if flames else 1.2
	mat.initial_velocity_max = 2.0 if flames else 2.0
	mat.scale_min = 0.6
	mat.scale_max = 1.4 if flames else 2.4
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1.0 if flames else 0.5))
	shrink.add_point(Vector2(1, 0.1 if flames else 1.3))
	var shrink_tex := CurveTexture.new()
	shrink_tex.curve = shrink
	mat.scale_curve = shrink_tex
	var ramp := Gradient.new()
	if flames:
		ramp.colors = PackedColorArray(FLAME_COLORS)
		ramp.offsets = PackedFloat32Array([0.0, 0.3, 0.65, 1.0])
	else:
		ramp.colors = PackedColorArray([Color(0.35, 0.33, 0.32, 0.85), Color(0.5, 0.5, 0.5, 0.0)])
		ramp.offsets = PackedFloat32Array([0.0, 1.0])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	mat.color_ramp = ramp_tex
	p.process_material = mat
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * (0.25 if flames else 0.5)
	var draw := StandardMaterial3D.new()
	draw.vertex_color_use_as_albedo = true
	if flames:
		draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else:
		draw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cube.material = draw
	p.draw_pass_1 = cube
	p.position = Vector3(0, 0.2, 0)
	return p
