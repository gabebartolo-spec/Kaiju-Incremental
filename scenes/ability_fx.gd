class_name AbilityFx
extends Node3D
## The look of every unlockable power, presentation only (D-026). Each signature attack has its
## own shape: Atomic Breath a plasma beam that runs out to what it hits, flares there and
## scorches the street, Leap Slam a trail through the air and a glowing crater, Tentacle Lash
## two streaks whipping round with the tentacle tips, spray, debris and gouges. Upgrades show
## too: Signature Power brightens the attack, heavy stomps crack the street molten, Signature
## Recharge pulses at the feet and lights the body, Regeneration shimmers green over the hide,
## Armoured Scales throw shells off in a spark burst and a metallic flash. Nothing here hides the
## kaiju (D-025): glows are additive and thin, marks are decals that skip the kaiju's layer.

const SWEEP := preload("res://scenes/sweep.gdshader")
const RIM := preload("res://scenes/rim.gdshader")
const FLARE := preload("res://scenes/flare.gdshader")
const STREET := Color("3a3d40")
const INK := Color("2a1620")
const MOLTEN := Color("ff7a2a")
const WATER := Color(0.85, 0.95, 1.0)
const HOT := Color(1.0, 0.92, 0.7)

## Every effect played, in order ("breath", "leap", "lash", "cracks", "ready", "deflect",
## "regen"); read by the flow suite to prove each power leaves its own mark.
var played: Array[String] = []
## Atomic Breath's half angle this run (radians).
var cone_half_angle := 0.0
var _city: CityView
var _tint: Color
var _scale: float
var _tune: Dictionary
var _trail: GPUParticles3D
var _regen: GPUParticles3D
var _glint_mesh: BoxMesh
var _overlay: ShaderMaterial
var _body: Node3D
var _overlay_on := false
var _healing := false
var _beam: BreathBeam


## tint: the species' eye colour; body_scale: the kaiju's size this run; cone: Atomic
## Breath's half angle this run (radians), so the prewarm draws the scorch texture it will use.
func _init(city: CityView, tint: Color, body_scale: float, cone: float) -> void:
	_city = city
	_tint = tint
	_scale = body_scale
	cone_half_angle = cone
	_tune = Content.section("fx")
	_beam = BreathBeam.new(tint, body_scale, _tune)
	add_child(_beam)


func _ready() -> void:
	_glint_mesh = FxParticles.glow_cube(0.22)
	var trail_life := Num.f(_tune["leap_trail_seconds"])
	_trail = _emitter(FxParticles.trail(_tint, _scale), FxParticles.glow_cube(0.3), 70, trail_life)
	var green := Color(str(_tune["regen_tint"]))
	_regen = _emitter(FxParticles.motes(green, _scale), FxParticles.glow_cube(0.14), 40, 1.5)
	_overlay = ShaderMaterial.new()
	_overlay.shader = RIM
	_overlay.set_shader_parameter("tint", Color(str(_tune["regen_tint"])))
	_overlay.set_shader_parameter("strength", 0.55)
	# Prewarm every shader and decal texture out of sight so first use does not stall a frame.
	var away := Vector3(0, -50, 0)
	breath(away, Vector3.FORWARD * 4.0, cone_half_angle, 1.0)
	leap_land(away, 2.0, 1.0)
	lash(away, 2.0, 1.0)
	stomp_cracks(away, 2.0, 3.0)
	ready_pulse(away, away)
	deflect(away, Vector3.UP)
	played.clear()


## The kaiju whose voxels take the body glows (ready flash, regeneration shimmer).
func attach_body(body: Node3D) -> void:
	_body = body


func _process(_delta: float) -> void:
	var want := _healing
	if want != _overlay_on:
		_overlay_on = want
		if not is_instance_valid(_body):
			return
		# Looked up each time: a growth stage rebuilds the body and frees its old parts.
		for node: Node in _body.find_children("*", "GeometryInstance3D", true, false):
			(node as GeometryInstance3D).material_overlay = _overlay if want else null


## How far an upgraded stat is above the species' own value, as 1..power_max.
func power(value: float, base: float) -> float:
	return clampf(value / maxf(base, 0.001), 1.0, Num.f(_tune["power_max"]))


## Atomic Breath: a white-hot core (BreathBeam) from the mouth along `span` (mouth to the
## street at full reach) that stops on the first standing wall it meets, a soft fan across the
## cone, a flare and a light on what it hits, and a scorched wedge across the street.
func breath(mouth: Vector3, span: Vector3, half_angle: float, strength: float) -> void:
	played.append("breath")
	var seconds := Num.f(_tune["beam_seconds"])
	var reach := Vector2(span.x, span.z).length()
	var hit := mouth + span * _first_hit(mouth, span)
	var dir := (hit - mouth).normalized()
	# Muzzle flash on the first frame: the jaw lights up even while the body hides the beam.
	_flare(mouth, 4.5 * _scale * strength, HOT, 0.3)
	_beam.power = strength
	_beam.fire(mouth, hit, span, half_angle)
	# The struck face: a flare, hot sparks and a light just in front of it that lights the wall.
	_flare(hit - dir * 0.6, 3.5 * _scale * strength, _tint.lightened(0.4), seconds)
	var burst := FxParticles.sparks(_tint)
	burst.direction = -dir + Vector3.UP * 0.4
	_burst(burst, roundi(50 * strength), 0.7).position = hit - dir * 0.4
	_city.flash(hit - dir * 1.5, _tint.lightened(0.3), 10.0 * strength, seconds * 1.4)
	var look := {
		"size": reach * 2.0,
		"seconds": Num.f(_tune["scorch_seconds"]),
		"half_angle": half_angle,
		"energy": 3.0 + strength,
		"tint": _tint,
	}
	var feet := Vector3(mouth.x, mouth.y + span.y - 0.5, mouth.z)
	var scorch := FxDecals.spawn(self, feet, FxDecals.Shape.WEDGE, look)
	var flat := Vector3(span.x, 0.0, span.z)
	if flat.length() > 0.01:
		scorch.basis = Basis.looking_at(flat.normalized(), Vector3.UP)


## Leap Slam lift-off: a kick of dust and a small ring where the kaiju left the ground.
func leap_takeoff(at: Vector3) -> void:
	_city.fx.dust(at + Vector3(0, 0.3, 0), 1.2 * _scale)
	_city.fx.shockwave(at, 2.5 * _scale, _tint)


## The streak behind the kaiju while it is in the air; on: false stops the trail.
func leap_trail(at: Vector3, on: bool) -> void:
	_trail.position = at
	_trail.emitting = on


## Leap Slam landing: a glowing crater with radial cracks, two shockwaves, street chunks
## thrown outward and a low ring of dust.
func leap_land(at: Vector3, reach: float, strength: float) -> void:
	played.append("leap")
	var look := {
		"size": reach * 2.2,
		"seconds": Num.f(_tune["crater_seconds"]),
		"cracks": 11,
		"energy": 3.0 + 2.0 * strength,
		"tint": _tint,
	}
	FxDecals.spawn(self, at, FxDecals.Shape.DISC, look)
	_city.fx.shockwave(at, reach * 1.3, _tint)
	_city.fx.shockwave(at, reach * 0.8)
	for n: int in 12:
		var out := Vector3.FORWARD.rotated(Vector3.UP, TAU * n / 12.0)
		_city.debris(at + out * 0.8 + Vector3(0, 0.4, 0), STREET, out + Vector3(0, 1.2, 0))
	for n: int in 6:
		var out := Vector3.FORWARD.rotated(Vector3.UP, TAU * (n + 0.5) / 6.0)
		_city.fx.dust(at + out * reach * 0.55 + Vector3(0, 0.3, 0), 0.9 * _scale)
	_city.flash(at + Vector3(0, 1.5, 0), _tint, 7.0 * strength, 0.5)


## Tentacle Lash: two streaks whipping round with the tentacle tips at shin height, ink and
## water flung off them, street chunks kicked along the arc as it passes, gouges left behind.
func lash(centre: Vector3, reach: float, strength: float) -> void:
	played.append("lash")
	var seconds := Num.f(_tune["sweep_seconds"])
	var tips := reach * 0.55
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * tips / 0.8 * 2.0
	var mat := _shader(SWEEP, strength)
	plane.material = mat
	var sweep := MeshInstance3D.new()
	sweep.mesh = plane
	sweep.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sweep.position = centre + Vector3(0, 0.7 * _scale, 0)
	add_child(sweep)
	_drive(mat, "progress", seconds, sweep)
	for color: Color in [INK, WATER]:
		var drops := _burst(FxParticles.spray(tips, color), roundi(45 * strength), 1.0)
		drops.position = centre + Vector3(0, 0.8 * _scale, 0)
	for n: int in 10:
		var phi := TAU * (n + 0.5) / 10.0 - PI
		var at := centre + Vector3(cos(phi) * tips, 0.4, sin(phi) * tips)
		var kick := Vector3(-sin(phi), 0.9, cos(phi))
		var timer := get_tree().create_timer(seconds * 0.9 * (n + 0.5) / 10.0)
		timer.timeout.connect(func() -> void: _city.debris(at, STREET, kick))
	var look := {"size": tips * 2.5, "seconds": 4.0, "energy": 0.0, "soot": 0.9}
	FxDecals.spawn(self, centre, FxDecals.Shape.SCRAPE, look)
	_city.flash(centre + Vector3(0, 2.0, 0), _tint, 5.0 * strength, 0.45)


## Heavy stomps crack the street; the cracks glow molten, brighter the heavier the stomp.
func stomp_cracks(at: Vector3, radius: float, strength: float) -> bool:
	var from := Num.f(_tune["crack_stomp_power"])
	if strength < from:
		return false
	played.append("cracks")
	var look := {
		"size": radius * 2.2,
		"seconds": Num.f(_tune["crack_seconds"]),
		"cracks": 7,
		"energy": 2.5 + 3.0 * (strength - from),
		"tint": MOLTEN,
		"soot": 0.5,
	}
	FxDecals.spawn(self, at, FxDecals.Shape.DISC, look)
	return true


## Signature ready again: one ring runs out from the feet and the eyes flare in the species
## colour (not the whole body, which read as taking damage).
func ready_pulse(feet: Vector3, head: Vector3) -> void:
	played.append("ready")
	_city.fx.shockwave(feet, 4.0 * _scale, _tint)
	_flare(head, 3.0 * _scale, _tint, 0.5)


## Regeneration: a green shimmer runs up the hide and motes drift off it while it heals.
func regen(body_centre: Vector3, healing: bool) -> void:
	_regen.position = body_centre
	if healing and not _regen.emitting:
		played.append("regen")
	_regen.emitting = healing
	_healing = healing


## Armoured Scales: a shell glances off in a burst of sparks thrown back the way it came and a
## short metallic flash on the hide.
func deflect(at: Vector3, away: Vector3) -> void:
	played.append("deflect")
	var cold := Color(str(_tune["deflect_tint"]))
	var burst := FxParticles.sparks(cold)
	burst.direction = away.normalized()
	_burst(burst, 70, 0.6).position = at
	_flare(at, 4.5 * _scale, cold, 0.22)
	_city.flash(at, cold, 6.0, 0.15)


## Fraction of `span` from `from` at which the line first meets a standing chunk (1: none).
func _first_hit(from: Vector3, span: Vector3) -> float:
	var steps := maxi(4, ceili(span.length() / 0.5))
	for i: int in range(1, steps + 1):
		var t := float(i) / steps
		var p := from + span * t
		for b: RampageSim.Building in _city.sim.buildings:
			var lx := p.x - (b.x - b.w * 0.5)
			var lz := p.z - (b.z - b.d * 0.5)
			if lx < 0.0 or lz < 0.0 or lx >= b.w or lz >= b.d:
				continue
			if b.frame.top_below(floori(lx), floori(lz), b.height) + 1 > p.y:
				return t
	return 1.0


func _flare(at: Vector3, size: float, tint: Color, seconds: float) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	var mat := ShaderMaterial.new()
	mat.shader = FLARE
	mat.set_shader_parameter("tint", tint)
	quad.material = mat
	var flare := MeshInstance3D.new()
	flare.mesh = quad
	flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flare.position = at
	add_child(flare)
	var tween := flare.create_tween()
	tween.tween_method(
		func(v: float) -> void: mat.set_shader_parameter("fade", 1.0 - v), 0.0, 1.0, seconds
	)
	tween.tween_callback(flare.queue_free)


func _shader(shader: Shader, strength: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("tint", _tint)
	mat.set_shader_parameter("power", strength)
	return mat


## Runs a shader parameter 0..1 over `seconds`, then frees `owner_node`.
func _drive(mat: ShaderMaterial, param: String, seconds: float, owner_node: Node) -> void:
	var tween := owner_node.create_tween()
	tween.tween_method(
		func(v: float) -> void: mat.set_shader_parameter(param, v), 0.0, 1.0, seconds
	)
	tween.tween_callback(owner_node.queue_free)


func _emitter(mat: ParticleProcessMaterial, mesh: Mesh, amount: int, life: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.process_material = mat
	p.draw_pass_1 = mesh
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-20, -10, -20), Vector3(40, 30, 40))
	add_child(p)
	return p


## A one-shot burst of glowing voxels.
func _burst(mat: ParticleProcessMaterial, amount: int, life: float) -> GPUParticles3D:
	var p := _emitter(mat, _glint_mesh, amount, life)
	p.one_shot = true
	p.explosiveness = 0.85
	p.emitting = true
	get_tree().create_timer(life + 0.2).timeout.connect(p.queue_free)
	return p
