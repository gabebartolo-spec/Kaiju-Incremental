class_name Fx
extends Node3D
## Particle and shader effects, presentation only: dust clouds from breaking floors and landing
## towers, sparks from shell hits, embers, and the stomp shockwave. Every effect is built once
## at start (prewarm) so its shaders compile before play instead of freezing the first time.

const SHOCKWAVE := preload("res://scenes/shockwave.gdshader")
const SMOKE := preload("res://scenes/smoke.gdshader")

var _dust_mat: ParticleProcessMaterial
var _dust_mesh: Mesh
var _puff_mesh: Mesh
var _spark_mat: ParticleProcessMaterial
var _spark_mesh: BoxMesh
var _breath_mesh: BoxMesh


func _ready() -> void:
	_dust_mat = _particle_mat(
		{
			"spread": 70.0,
			"gravity": Vector3(0, 0.6, 0),
			"vmin": 1.5,
			"vmax": 4.0,
			"smin": 1.0,
			"smax": 2.6,
			"grow": true,
			"colors": [Color(0.22, 0.24, 0.26, 0.47), Color(0.2, 0.22, 0.24, 0.0)],
		}
	)
	_dust_mesh = _puff(2.2)
	_puff_mesh = _puff(0.5)
	_spark_mat = _particle_mat(
		{
			"spread": 60.0,
			"gravity": Vector3(0, -18, 0),
			"vmin": 6.0,
			"vmax": 12.0,
			"smin": 0.5,
			"smax": 1.0,
			"grow": false,
			"colors": [Color(1.0, 0.95, 0.7, 1.0), Color(1.0, 0.45, 0.1, 1.0)],
		}
	)
	_spark_mesh = _cube(0.12, true)
	_breath_mesh = BoxMesh.new()
	_breath_mesh.size = Vector3.ONE * 0.25
	var hot := ShaderMaterial.new()
	hot.shader = preload("res://scenes/ember.gdshader")
	hot.set_shader_parameter("heat", 3.0)  # white-hot enough for the bloom to catch
	_breath_mesh.material = hot
	# Prewarm: one of each, out of sight, so the first real one does not stall a frame.
	dust(Vector3(0, -50, 0), 0.5)
	sparks(Vector3(0, -50, 0))
	shockwave(Vector3(0, -50, 0), 1.0)
	breath(Vector3(0, -50, 0), Vector3(1, 0, 0), Color.ORANGE)


## A billowing dust cloud; size ~ the width of what came down.
func dust(at: Vector3, size: float) -> void:
	var p := _burst(_dust_mat, _dust_mesh, roundi(12 * clampf(size, 0.5, 4.0)), 2.6)
	p.position = at
	var mat: ParticleProcessMaterial = p.process_material
	mat.emission_box_extents = Vector3(size, 0.4, size)


## A small puff of dust: a person crushed underfoot.
func puff(at: Vector3) -> void:
	var p := _burst(_dust_mat, _puff_mesh, 6, 1.2)
	p.position = at
	var mat: ParticleProcessMaterial = p.process_material
	mat.emission_box_extents = Vector3(0.2, 0.1, 0.2)
	mat.initial_velocity_min = 0.4
	mat.initial_velocity_max = 1.0


## Dust along a line: where a toppled tower hits the street.
func dust_line(from: Vector3, to: Vector3, width: float) -> void:
	var steps := maxi(2, ceili(from.distance_to(to) / 2.5))
	for i: int in steps + 1:
		dust(from.lerp(to, float(i) / steps) + Vector3(0, 0.5, 0), width * 0.6)


func sparks(at: Vector3) -> void:
	var p := _burst(_spark_mat, _spark_mesh, 18, 0.5)
	p.position = at


## A cone of glowing voxels blasting along `span` (direction times reach) from `from`.
func breath(from: Vector3, span: Vector3, color: Color) -> void:
	var mat := ParticleProcessMaterial.new()
	mat.direction = span.normalized()
	mat.spread = 22.0
	mat.gravity = Vector3(0, -2.0, 0)
	mat.initial_velocity_min = span.length() / 0.45
	mat.initial_velocity_max = span.length() / 0.3
	mat.scale_min = 1.5
	mat.scale_max = 4.0
	var ramp := Gradient.new()  # white-hot at the mouth, the species colour as it cools
	ramp.colors = PackedColorArray([Color(1.0, 0.95, 0.75), color, color.darkened(0.5)])
	ramp.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	mat.color_ramp = ramp_tex
	var p := GPUParticles3D.new()
	p.process_material = mat
	p.draw_pass_1 = _breath_mesh
	p.amount = 160
	p.lifetime = 0.45
	p.one_shot = true
	p.explosiveness = 0.6
	p.emitting = true
	p.position = from
	p.visibility_aabb = AABB(Vector3(-30, -10, -30), Vector3(60, 30, 60))
	add_child(p)
	get_tree().create_timer(0.8).timeout.connect(p.queue_free)


## A ring that runs out across the ground from a stomp; tint alpha 0 keeps the shader's own.
func shockwave(at: Vector3, radius: float, tint: Color = Color(0, 0, 0, 0)) -> void:
	var quad := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * radius * 2.4
	var mat := ShaderMaterial.new()
	mat.shader = SHOCKWAVE
	if tint.a > 0.0:
		mat.set_shader_parameter("tint", tint)
	plane.material = mat
	quad.mesh = plane
	quad.position = at + Vector3(0, 0.15, 0)
	add_child(quad)
	var tween := quad.create_tween()
	tween.tween_method(
		func(v: float) -> void: mat.set_shader_parameter("progress", v), 0.0, 1.0, 0.45
	)
	tween.tween_callback(quad.queue_free)


func _burst(mat: ParticleProcessMaterial, mesh: Mesh, amount: int, life: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.process_material = mat.duplicate()
	p.draw_pass_1 = mesh
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.9
	p.emitting = true
	add_child(p)
	get_tree().create_timer(life + 0.2).timeout.connect(p.queue_free)
	return p


func _particle_mat(o: Dictionary) -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(0.5, 0.3, 0.5)
	mat.direction = Vector3.UP
	mat.spread = Num.f(o["spread"])
	mat.gravity = o["gravity"]
	mat.initial_velocity_min = Num.f(o["vmin"])
	mat.initial_velocity_max = Num.f(o["vmax"])
	mat.angular_velocity_min = -120.0
	mat.angular_velocity_max = 120.0
	mat.damping_min = 1.5
	mat.damping_max = 3.0
	mat.scale_min = Num.f(o["smin"])
	mat.scale_max = Num.f(o["smax"])
	var curve := Curve.new()
	var grow: bool = o["grow"]
	curve.add_point(Vector2(0, 0.4 if grow else 1.0))
	curve.add_point(Vector2(1, 1.6 if grow else 0.2))
	var curve_tex := CurveTexture.new()
	curve_tex.curve = curve
	mat.scale_curve = curve_tex
	var ramp := Gradient.new()
	var colors: Array = o["colors"]
	ramp.colors = PackedColorArray([colors[0], colors[1]])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	mat.color_ramp = ramp_tex
	return mat


## A soft camera-facing puff (the smoke shader), for dust clouds.
func _puff(size: float) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	var mat := ShaderMaterial.new()
	mat.shader = SMOKE
	quad.material = mat
	return quad


func _cube(size: float, bright: bool) -> BoxMesh:
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * size
	var draw := StandardMaterial3D.new()
	draw.vertex_color_use_as_albedo = true
	if bright:
		draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else:
		draw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		draw.roughness = 1.0
	cube.material = draw
	return cube
