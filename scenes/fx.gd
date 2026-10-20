class_name Fx
extends Node3D
## Particle and shader effects, presentation only: dust clouds from breaking floors and landing
## towers, a puff at each footfall, sparks from shell hits, embers, and the stomp shockwave.
## Every effect is built once at start (prewarm) so its shaders compile before play instead of
## freezing the first time.

const SHOCKWAVE := preload("res://scenes/shockwave.gdshader")
## A tail slam's puffs (shockwave(tail), lead review PR #54): one at the tip and SLAM_PUFFS around
## it, each SLAM_SIZE x the ring radius it was given; they live SLAM_SECONDS, grow from 0.4 to full
## over the first SLAM_GROW of it with their alpha rising from 0 to its peak at SLAM_PEAK, stop
## growing by SLAM_HOLD and fade to nothing by the end (not the step puff's pop and slow climb).
const SLAM_PUFFS := 3
const SLAM_SIZE := 0.6
const SLAM_SECONDS := 0.85
const SLAM_GROW := 0.15
const SLAM_PEAK := 0.18
const SLAM_HOLD := 0.4
const SMOKE := preload("res://scenes/smoke.gdshader")
const TREE_PUFF := Color(0.7, 0.6, 0.46)  # dusty earth, unlit: it reads the same in any light
## A crushed tree's dust (lead, #55 r14): at its peak by frame 3, held to frame 5, then fading
## evenly to nothing by frame 29 (30 fps).
const PUFF_RISE := 0.1
const PUFF_HOLD := 0.07
const PUFF_FADE := 0.8

## Footfall puffs still in the air (at most tuning "fx" "footfall_dust" "max_live").
var steps_live: Array[GPUParticles3D] = []

var _dust_mat: ParticleProcessMaterial
var _dust_mesh: Mesh
var _puff_mesh: Mesh
var _step_mat: ParticleProcessMaterial
var _step_mesh: Mesh
var _step_cfg: Dictionary
var _slam_mat: ParticleProcessMaterial
var _spark_mat: ParticleProcessMaterial
var _tree_puff_mat := _soft_sprite()
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
	_slam_mat = _slam_puff_mat(_step_mat, alpha)
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
## into a haze that greys out the ground (greenery review). Skipped while max_live are still up,
## unless uncapped (a tail slam's puffs, shockwave(tail)).
func footfall(at: Vector3, size: float, capped := true) -> void:
	var alive: Array[GPUParticles3D] = []
	for puff: Variant in steps_live:  # a finished puff is freed: check before using it
		if is_instance_valid(puff):
			alive.append(puff)
	steps_live = alive
	if capped and steps_live.size() >= Num.i(_step_cfg["max_live"]):
		return
	var amount := roundi(6 * clampf(size, 0.5, 3.0))
	var p := _burst(_step_mat, _step_mesh, amount, Num.f(_step_cfg["seconds"]))
	p.position = at
	var mat: ParticleProcessMaterial = p.process_material
	mat.emission_box_extents = Vector3(size * 0.6, 0.2, size * 0.6)
	mat.scale_min = 0.4 * size  # as wide as the foot that threw it
	mat.scale_max = 0.8 * size
	steps_live.append(p)


## A soft dust puff over a crushed tree's stump: one round camera-facing sprite, its alpha
## falling off smoothly from the middle, that comes up to `peak` in PUFF_RISE, holds, and is
## gone in under a second (lead, #55 r13: the footfall puffs vanish in the smoke shader's
## screen-centre clearing, right where the kaiju walks).
func tree_puff(at: Vector3, size: float, peak: float) -> void:
	var mat := _tree_puff_mat.duplicate() as StandardMaterial3D
	var quad := MeshInstance3D.new()
	var plane := QuadMesh.new()
	plane.size = Vector2.ONE * size
	plane.material = mat
	quad.mesh = plane
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad.position = at + Vector3(0, size * 0.35, 0)
	add_child(quad)
	mat.albedo_color = Color(TREE_PUFF, 0.0)
	var tween := quad.create_tween().set_parallel()
	tween.tween_property(mat, "albedo_color:a", peak, PUFF_RISE)
	tween.tween_property(quad, "scale", Vector3.ONE * 1.35, PUFF_RISE + PUFF_HOLD + PUFF_FADE)
	var fade := tween.tween_property(mat, "albedo_color:a", 0.0, PUFF_FADE)
	fade.set_delay(PUFF_RISE + PUFF_HOLD)
	tween.chain().tween_callback(quad.queue_free)


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


## A soft ripple of dust that runs out across the ground from a landing (no glow, no tint: a ring
## with no visible impact behind it is not drawn by the callers). Size, life and opacity are
## tuning "fx" "shockwave": small and faint so it reads as dust kicked off the street.
## A tail slam (tail) draws no ring: a few footfall puffs thrown out around the tip instead
## (lead review PR #54: three custom rings in a row popped; the step puff of #62 reads right).
func shockwave(at: Vector3, radius: float, tail := false) -> void:
	if tail:
		_slam_puff(at + Vector3(0, 0.2, 0), radius * SLAM_SIZE)
		for k: int in SLAM_PUFFS:
			var a := TAU * k / SLAM_PUFFS
			_slam_puff(at + Vector3(cos(a), 0.4, sin(a)) * radius * 0.35, radius * SLAM_SIZE * 0.8)
		return
	var cfg: Dictionary = Content.section("fx")["shockwave"]
	var quad := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * radius * Num.f(cfg["radius_scale"]) * 2.4
	var mat := ShaderMaterial.new()
	mat.shader = SHOCKWAVE
	mat.set_shader_parameter("peak", Num.f(cfg["alpha"]))
	mat.set_shader_parameter("soft", Num.f(cfg["soft"]))
	plane.material = mat
	quad.mesh = plane
	quad.position = at + Vector3(0, 0.15, 0)
	add_child(quad)
	var tween := quad.create_tween()
	tween.tween_method(
		func(v: float) -> void: mat.set_shader_parameter("progress", v),
		0.0,
		1.0,
		Num.f(cfg["seconds"])
	)
	tween.tween_callback(quad.queue_free)


func _slam_puff(at: Vector3, size: float) -> void:
	var p := _burst(_slam_mat, _step_mesh, roundi(6 * clampf(size, 0.5, 3.0)), SLAM_SECONDS)
	p.position = at
	var mat: ParticleProcessMaterial = p.process_material
	mat.emission_box_extents = Vector3(size * 0.6, 0.2, size * 0.6)
	mat.scale_min = 0.4 * size
	mat.scale_max = 0.8 * size


## The step puff's material with the slam's life curves (see SLAM_SECONDS).
func _slam_puff_mat(step: ParticleProcessMaterial, alpha: float) -> ParticleProcessMaterial:
	var mat: ParticleProcessMaterial = step.duplicate()
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.4))
	curve.add_point(Vector2(SLAM_GROW, 1.0))
	curve.add_point(Vector2(SLAM_HOLD, 1.05))
	curve.add_point(Vector2(1.0, 1.05))
	var curve_tex := CurveTexture.new()
	curve_tex.curve = curve
	mat.scale_curve = curve_tex
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, SLAM_PEAK, 1.0])
	var c := Color(0.24, 0.25, 0.26)
	ramp.colors = PackedColorArray([Color(c, 0.0), Color(c, alpha), Color(c, 0.0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	mat.color_ramp = ramp_tex
	return mat


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


## Unlit, camera-facing, alpha from a smooth radial falloff (no flat disc, no hard rim).
static func _soft_sprite() -> StandardMaterial3D:
	var falloff := Gradient.new()
	falloff.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
	falloff.colors = PackedColorArray(
		[Color(1, 1, 1, 1), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0.2), Color(1, 1, 1, 0)]
	)
	var tex := GradientTexture2D.new()
	tex.gradient = falloff
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var draw := StandardMaterial3D.new()
	draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	draw.albedo_texture = tex
	draw.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	draw.proximity_fade_enabled = true  # where it meets the ground: soft, never a cut line
	draw.proximity_fade_distance = 0.6
	return draw


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
