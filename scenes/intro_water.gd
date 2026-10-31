class_name IntroWater
extends Node3D
## The water before the kaiju breaks it (director 2026-10-20 #11: "zoomed in on the water which
## begins to ripple ... before our kaiju emerges"): the rings are the liquid's own (WaterSim
## ripple_seconds) while it holds under; here purple electricity crackling over the surface,
## building until the head breaks it (IntroCrackle; director 2026-10-31: no spray before him),
## then a burst of spray with the break, the same electricity climbing it. Paced by the sim's
## own rise (Emergence progress), never the clock; presentation only, tuning "intro" "water".
## RiverView keeps its splash rings at the start, the break and the step out.

var _sim: RampageSim
var _fx: Fx
var _cfg: Dictionary
var _crackle: IntroCrackle
var _burst: GPUParticles3D
var _burst_done := false
var _ahead := 0.0
var _since_burst := INF  # seconds since he broke the water (frame time: the rise clock stops)
var _break := 0.0  # seconds into the rise the head's top breaks the water


## ahead: how far the head's crown stands ahead of the hips (world units, KaijuModel.head_ahead).
func _init(sim: RampageSim, fx: Fx, ahead: float) -> void:
	_ahead = ahead
	_sim = sim
	_fx = fx
	_cfg = Content.section("intro")["water"]


func _ready() -> void:
	if not _sim.emerge.active:
		return
	_break = _sim.emerge.break_at(_sim)
	var s := _sim.body_scale()
	var ahead := _sim.facing * _ahead
	var water := _sim.emerge.water_y()
	position = Vector3(_sim.kaiju_pos.x + ahead.x, water + 0.05, _sim.kaiju_pos.y + ahead.y)
	_burst = _spray(Num.i(_cfg["burst_amount"]), Num.f(_cfg["burst_speed"]) * s)
	_crackle = IntroCrackle.new(_cfg, s)
	add_child(_crackle)


func _process(delta: float) -> void:
	var emerge := _sim.emerge
	if _crackle == null:
		return
	var t := emerge.progress() * emerge.total()
	# It builds to its peak as the head breaks, then climbs the burst for burst_arc_seconds.
	var from := Num.f(_cfg["crackle_from_seconds"])
	var build := 0.0
	if emerge.active and not emerge.surfaced and t >= from:
		build = clampf((t - from) / maxf(0.001, _break - from), 0.01, 1.0)
	var body := Vector3(_sim.kaiju_pos.x, position.y, _sim.kaiju_pos.y) - position
	if emerge.surfaced and not _burst_done:
		_burst_done = true
		_since_burst = 0.0
		_burst.position = body  # thrown up round his body, where the arcs climb
		_burst.restart()
		_burst.emitting = true
	_since_burst += delta
	var climb := 1.0 - _since_burst / Num.f(_cfg["burst_arc_seconds"])  # thins out to none
	_crackle.step(delta, build, clampf(climb, 0.0, 1.0), body)


## The burst of spray thrown up from the water as he breaks it.
func _spray(amount: int, speed: float) -> GPUParticles3D:
	var s := _sim.body_scale()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = Num.f(_cfg["width"]) * s
	mat.direction = Vector3.UP
	mat.spread = Num.f(_cfg["burst_spread"])
	mat.initial_velocity_min = speed * 0.6
	mat.initial_velocity_max = speed
	mat.gravity = Vector3(0, -Num.f(_cfg["gravity"]) * s, 0)
	# Cubes from small droplets to "drop", each born one of the water's tones (white foam to
	# blue-grey), fading out at the end of its life.
	mat.scale_min = Num.f(_cfg["drop_min"])
	mat.scale_max = 1.0
	var hues: Array = _cfg["colors"]
	mat.color_initial_ramp = tones(hues, false)
	mat.color_ramp = tones(["ffffffff", "ffffff00"], true)
	var p := GPUParticles3D.new()
	p.process_material = mat
	p.draw_pass_1 = puff(Num.f(_cfg["drop"]) * s)
	p.amount = amount
	p.lifetime = Num.f(_cfg["life"])
	p.one_shot = true
	p.explosiveness = 0.95
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-20, -2, -20) * s, Vector3(40, 30, 40) * s)
	add_child(p)
	return p


## One drop of spray: a soft round puff facing the camera, clear at its edge, so a thousand of
## them overlap into one mass of white water (director 2026-10-31: solid spheres read as balls).
static func puff(size: float) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	var soft := GradientTexture2D.new()
	soft.gradient = ramp
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(0.5, 0.0)
	var look := StandardMaterial3D.new()  # lit: the spray takes the scene's light and shade
	look.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	look.vertex_color_use_as_albedo = true
	look.albedo_texture = soft
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.roughness = 0.35
	quad.material = look
	return quad


## The ripples' tone on the water: the spray's middle tone (tuning intro.water.colors).
static func foam(cfg: Dictionary) -> Color:
	var tones: Array = cfg["colors"]
	return Color(str(tones[1]))


## A texture of `colors` (hex strings): a smooth ramp over a life, or hard steps to pick one from.
static func tones(colors: Array, smooth: bool) -> GradientTexture1D:
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
