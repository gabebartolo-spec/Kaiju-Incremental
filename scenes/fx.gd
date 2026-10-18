class_name Fx
extends Node3D
## Particle and shader effects, presentation only: dust clouds from breaking floors and landing
## towers, a puff at each footfall, sparks from shell hits, embers, and the stomp shockwave.
## Every effect is built once at start (prewarm) so its shaders compile before play instead of
## freezing the first time.

const SHOCKWAVE := preload("res://scenes/shockwave.gdshader")
## The soft ring (tail slam, lead review PR #54 r3): seconds alive, seconds to fade in, to grow
## (eased out) and to fade out; where its front starts and ends (fractions of the radius); its look:
## a thin, smooth, dim ring that the script fades (not a filled, spiky disc).
const SOFT_SECONDS := 0.75
const SOFT_IN := 0.08
const SOFT_GROW := 0.3
const SOFT_OUT := 0.38
const SOFT_FRONT := Vector2(0.08, 0.8)
const SOFT_RING := {"width": 0.09, "edge": 0.07, "glow": 0.9, "rag": 0.0, "self_fade": 0.0}
const SMOKE := preload("res://scenes/smoke.gdshader")

## Footfall puffs still in the air (at most tuning "fx" "footfall_dust" "max_live").
var steps_live: Array[GPUParticles3D] = []

var _dust_mat: ParticleProcessMaterial
var _dust_mesh: Mesh
var _puff_mesh: Mesh
var _step_mat: ParticleProcessMaterial
var _step_mesh: Mesh
var _step_cfg: Dictionary
var _spark_mat: ParticleProcessMaterial
var _spark_mesh: BoxMesh


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
	_step_cfg = Content.section("fx")["footfall_dust"]
	var alpha := Num.f(_step_cfg["alpha"])
	_step_mat = _particle_mat(
		{
			"spread": 55.0,
			"gravity": Vector3(0, 0.2, 0),
			"vmin": 0.5,
			"vmax": Num.f(_step_cfg["rise"]),
			"smin": 0.8,
			"smax": 1.6,
			"grow": true,
			"colors": [Color(0.24, 0.25, 0.26, alpha), Color(0.22, 0.23, 0.24, 0.0)],
		}
	)
	_step_mesh = _puff(1.4)
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
	# Prewarm: one of each, out of sight, so the first real one does not stall a frame.
	dust(Vector3(0, -50, 0), 0.5)
	footfall(Vector3(0, -50, 0), 0.5)
	sparks(Vector3(0, -50, 0))
	shockwave(Vector3(0, -50, 0), 1.0)


## A billowing dust cloud; size ~ the width of what came down.
func dust(at: Vector3, size: float) -> void:
	var p := _burst(_dust_mat, _dust_mesh, roundi(12 * clampf(size, 0.5, 4.0)), 2.6)
	p.position = at
	var mat: ParticleProcessMaterial = p.process_material
	mat.emission_box_extents = Vector3(size, 0.4, size)


## A footfall's puff: short-lived and thin, so a walk leaves a puff per step instead of piling
## into a haze that greys out the ground (greenery review). Skipped while max_live are still up.
func footfall(at: Vector3, size: float) -> void:
	var alive: Array[GPUParticles3D] = []
	for puff: Variant in steps_live:  # a finished puff is freed: check before using it
		if is_instance_valid(puff):
			alive.append(puff)
	steps_live = alive
	if steps_live.size() >= Num.i(_step_cfg["max_live"]):
		return
	var amount := roundi(6 * clampf(size, 0.5, 3.0))
	var p := _burst(_step_mat, _step_mesh, amount, Num.f(_step_cfg["seconds"]))
	p.position = at
	var mat: ParticleProcessMaterial = p.process_material
	mat.emission_box_extents = Vector3(size * 0.6, 0.2, size * 0.6)
	mat.scale_min = 0.4 * size  # as wide as the foot that threw it
	mat.scale_max = 0.8 * size
	steps_live.append(p)


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


## A ring that runs out across the ground from a stomp; tint alpha 0 keeps the shader's own. A soft
## ring (the tail slam, lead review PR #54) starts small at the hit and grows over SOFT_GROW, fades
## in and out, and is thin, smooth-edged and dimmer instead of a hard white pop.
func shockwave(at: Vector3, radius: float, tint: Color = Color(0, 0, 0, 0), soft := false) -> void:
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
	if soft:
		for key: String in SOFT_RING:
			mat.set_shader_parameter(key, SOFT_RING[key])
		tween.tween_method(func(v: float) -> void: _soft_ring(mat, v), 0.0, 1.0, SOFT_SECONDS)
	else:
		tween.tween_method(
			func(v: float) -> void: mat.set_shader_parameter("progress", v), 0.0, 1.0, 0.45
		)
	tween.tween_callback(quad.queue_free)


## A soft ring at time fraction v: small at the hit, its front eases out over SOFT_GROW and then
## creeps; it fades in over SOFT_IN and out over the last SOFT_OUT.
func _soft_ring(mat: ShaderMaterial, v: float) -> void:
	var t := v * SOFT_SECONDS
	var grow := 1.0 - pow(1.0 - minf(1.0, t / SOFT_GROW), 3.0)
	var front := lerpf(SOFT_FRONT.x, SOFT_FRONT.y, 0.85 * grow + 0.15 * v)
	mat.set_shader_parameter("progress", front)
	var fade := minf(1.0, t / SOFT_IN) * minf(1.0, (SOFT_SECONDS - t) / SOFT_OUT)
	mat.set_shader_parameter("alpha", smoothstep(0.0, 1.0, fade))


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
