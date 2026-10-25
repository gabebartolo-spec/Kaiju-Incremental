class_name IntroWater
extends Node3D
## The water before the kaiju breaks it (director 2026-10-20 #11: "zoomed in on the water which
## begins to ripple and fount before our kaiju emerges"): rings spreading from over its head
## while it holds under, a column of spray (cube droplets, like the city's voxels) rising and
## building until the head breaks the surface, then a burst of spray with the break. Paced by
## the sim's own rise (Emergence progress), never the clock; presentation only, tuning
## "intro" "water". RiverView keeps its splash rings at the start, the break and the step out.

var _sim: RampageSim
var _fx: Fx
var _cfg: Dictionary
var _rings := 0
var _fount: GPUParticles3D
var _burst: GPUParticles3D
var _burst_done := false
var _break := 0.0  # seconds into the rise the head's top breaks the water


func _init(sim: RampageSim, fx: Fx) -> void:
	_sim = sim
	_fx = fx
	_cfg = Content.section("intro")["water"]


func _ready() -> void:
	if not _sim.emerge.active:
		return
	_break = _sim.emerge.break_at(_sim)
	var s := _sim.body_scale()
	var ahead := _sim.facing * Num.f(Content.section("intro")["aim_ahead"]) * s
	var water := -Num.f(_sim.city.get("river_depth", 0.0))
	position = Vector3(_sim.kaiju_pos.x + ahead.x, water + 0.05, _sim.kaiju_pos.y + ahead.y)
	_fount = _spray(Num.i(_cfg["fount_amount"]), Num.f(_cfg["fount_speed"]) * s, false)
	_burst = _spray(Num.i(_cfg["burst_amount"]), Num.f(_cfg["burst_speed"]) * s, true)
	_fount.emitting = true  # built and compiled now, under the loading screen; hidden until due
	_fount.visible = false


func _process(_delta: float) -> void:
	var emerge := _sim.emerge
	if _fount == null:
		return
	var t := emerge.progress() * emerge.total()
	var every := Num.f(_cfg["ripple_seconds"])
	if emerge.active and not emerge.surfaced and t >= _rings * every:
		_rings += 1  # one ring a frame at most, so a fast-forward never stacks them
		var grow := 1.0 + Num.f(_cfg["ripple_grow"]) * t
		var radius := Num.f(_cfg["ripple_radius"]) * _sim.body_scale() * grow
		_fx.shockwave(global_position, radius, false, false, foam(_cfg))
	# It builds to its peak as the head breaks and plays on while the head clears the water.
	var from := Num.f(_cfg["fount_from_seconds"])
	var due := emerge.active and t >= from and t < _break + Num.f(_cfg["fount_after_seconds"])
	var build := clampf((t - from) / maxf(0.001, _break - from), 0.0, 1.0)
	_fount.amount_ratio = lerpf(Num.f(_cfg["fount_start"]), 1.0, build)
	_fount.visible = due
	_fount.emitting = due
	if emerge.surfaced and not _burst_done:
		_burst_done = true
		_burst.restart()
		_burst.emitting = true


## Cube droplets thrown up from the water: a steady column (one_shot false) or one burst.
func _spray(amount: int, speed: float, one_shot: bool) -> GPUParticles3D:
	var s := _sim.body_scale()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = Num.f(_cfg["width"]) * s
	mat.direction = Vector3.UP
	mat.spread = Num.f(_cfg["burst_spread" if one_shot else "fount_spread"])
	mat.initial_velocity_min = speed * 0.6
	mat.initial_velocity_max = speed
	mat.gravity = Vector3(0, -Num.f(_cfg["gravity"]) * s, 0)
	# Cubes from small droplets to "drop", each born one of the water's tones (white foam to
	# blue-grey), fading out at the end of its life.
	mat.scale_min = Num.f(_cfg["drop_min"])
	mat.scale_max = 1.0
	var tones: Array = _cfg["colors"]
	mat.color_initial_ramp = _tones(tones, false)
	mat.color_ramp = _tones(["ffffffff", "ffffff00"], true)
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * Num.f(_cfg["drop"]) * s
	var look := StandardMaterial3D.new()  # lit: the cubes take the scene's light and shade
	look.vertex_color_use_as_albedo = true
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.roughness = 0.35
	cube.material = look
	var p := GPUParticles3D.new()
	p.process_material = mat
	p.draw_pass_1 = cube
	p.amount = amount
	p.lifetime = Num.f(_cfg["life"])
	p.one_shot = one_shot
	p.explosiveness = 0.95 if one_shot else 0.0
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-20, -2, -20) * s, Vector3(40, 30, 40) * s)
	add_child(p)
	return p


## The ripples' tone on the water: the spray's middle tone (tuning intro.water.colors).
static func foam(cfg: Dictionary) -> Color:
	var tones: Array = cfg["colors"]
	return Color(str(tones[1]))


## A texture of `colors` (hex strings): a smooth ramp over a life, or hard steps to pick one from.
static func _tones(colors: Array, smooth: bool) -> GradientTexture1D:
	var ramp := Gradient.new()
	var picked := PackedColorArray()
	for hex: Variant in colors:
		picked.append(Color(str(hex)))
	ramp.colors = picked
	var offsets := PackedFloat32Array()
	for i: int in picked.size():
		offsets.append(float(i) / maxf(1.0, picked.size() - 1.0))
	ramp.offsets = offsets
	if not smooth:
		ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	return tex
