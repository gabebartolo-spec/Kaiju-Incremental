class_name AbilityFx
extends Node3D
## The look of every unlockable power, presentation only (D-026). Each signature attack has its
## own shape: Lightning Breath a forked bolt that runs out to what it hits, lights the street
## there and scorches it, Leap Slam a trail through the air and a glowing crater, Tentacle Lash
## two streaks whipping round with the tentacle tips, spray, debris and gouges. Upgrades show
## too: Signature Power brightens the attack, heavy stomps crack the street molten, Signature
## Recharge pulses at the feet and lights the body, Regeneration shimmers green over the hide,
## Armoured Scales throw shells off in a spark burst and a metallic flash. Nothing here hides the
## kaiju (D-025): glows are additive and thin, marks are decals that skip the kaiju's layer.

## A stroke of the breath's bolt landed (its number, where): the camera shakes.
signal breath_stroke(index: int, at: Vector3)

const SWEEP := preload("res://scenes/sweep.gdshader")
const RIM := preload("res://scenes/rim.gdshader")
const FLARE := preload("res://scenes/flare.gdshader")
const STREET := Color("3a3d40")
const INK := Color("2a1620")
## How much the breath's strike sparks' lifetimes vary (0 = all die together).
const SPARK_LIFE_SPREAD := 0.6
const MOLTEN := Color("ff7a2a")
## How long the prewarm's bolt lives (before its first stroke, so it kicks nothing).
const PREWARM_BOLT := 0.05
const WATER := Color(0.85, 0.95, 1.0)

## Every effect played, in order ("breath", "leap", "lash", "cracks", "ready", "deflect",
## "regen"); read by the flow suite to prove each power leaves its own mark.
var played: Array[String] = []
## Atomic Breath's half angle this run (radians).
var cone_half_angle := 0.0
## The run's index (Rampage sets it): with the breath count it seeds each breath's bolt.
var seed_index := 0
## Where the next breath's hit cone starts (the kaiju's feet); set before breath().
var cone_origin := Vector3.ZERO
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
var _was_ready := true  # Signature Recharge: the ability was ready last step
var _warming := false  # the prewarm's emitters' materials are kept compiled (ShaderKeep)
var _breaths := 0  # breaths so far this run (the bolt's presentation seed)


## tint: the species' eye colour; body_scale: the kaiju's size this run; cone: Atomic
## Breath's half angle this run (radians), so the prewarm draws the scorch texture it will use.
func _init(city: CityView, tint: Color, body_scale: float, cone: float) -> void:
	_city = city
	_tint = tint
	_scale = body_scale
	cone_half_angle = cone
	_tune = Content.section("fx")
	_beam = BreathBeam.new(tint, body_scale, _tune)
	_beam.rig.stroked.connect(breath_stroke.emit)
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
	cone_origin = away
	_warming = true  # and keep each one's shader for the run (b2-3: 8-10 ms a breath otherwise)
	breath(away, Vector3.FORWARD * 4.0, cone_half_angle, 1.0)
	leap_land(away, 2.0, 1.0)
	lash(away, 2.0, 1.0)
	stomp_cracks(away, 2.0, 3.0)
	ready_pulse(away, away)
	deflect(away, Vector3.UP)
	_warming = false
	_beam.rig.play(PREWARM_BOLT, _beam.rng)  # a few frames out of sight: its shader compiles now
	_breaths = 0
	for mat: ShaderMaterial in _beam.rig.materials():
		_city.fx.keep.hold("bolt_%d" % mat.get_instance_id(), mat)
	_beam.rig.fx = _city.fx
	_beam.rig.blocker = _first_hit
	played.clear()


## The kaiju whose voxels take the body glows (ready flash, regeneration shimmer).
func attach_body(body: Node3D) -> void:
	_body = body


## Signature Recharge's ready pulse and Regeneration's motes, once a step; `at` is the kaiju.
func update_powers(sim: RampageSim, sfx: Sfx, at: Vector3) -> void:
	var charged := sim.ability_ready_in <= 0.0
	if charged and not _was_ready:
		var facing := Vector3(sim.facing.x, 0.0, sim.facing.y)
		var head := at + Vector3(0, 6.0, 0) * sim.body_scale()
		ready_pulse(at, head + facing * sim.body_scale())
		sfx.play("ready")
	_was_ready = charged
	var healing := sim.stat("regen") > 0.0 and sim.hp < sim.max_hp
	regen(at + Vector3(0, 3.0 * sim.body_scale(), 0), healing)
	sfx.regen(healing)


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


## Lightning Breath: a forked bolt (BreathBeam) from the mouth along `span` (mouth to the street
## at full reach) that stops on the first standing wall it meets, branches across the cone, two
## lights and sparks on what it hits, and a scorched wedge on the street.
func breath(mouth: Vector3, span: Vector3, half_angle: float, strength: float) -> void:
	played.append("breath")
	var hit := mouth + span * _first_hit(mouth, span)
	var dir := (hit - mouth).normalized()
	_beam.power = strength
	_beam.cone_origin = cone_origin
	_beam.follow = _body
	_beam.rng = Seeds.make("breath_bolt", seed_index * BoltRig.SEEDS_PER_RUN + _breaths)
	_breaths += 1
	_beam.fire(mouth, hit, span, half_angle)
	# The struck face: hot sparks (the bolt carries the flashes, the lights and the strokes' own).
	var burst := FxParticles.sparks(_tint)
	burst.direction = -dir + Vector3.UP * 0.4
	burst.lifetime_randomness = SPARK_LIFE_SPREAD  # die out over time, not all on one frame
	_burst(burst, roundi(50 * strength), 0.7).position = hit - dir * 0.4
	# The scorch covers the sim's hit cone: from the feet (cone_origin) out to full reach.
	var target := mouth + span
	var flat := Vector3(target.x - cone_origin.x, 0.0, target.z - cone_origin.z)
	var look := {
		"size": flat.length() * 2.0,
		"seconds": Num.f(_tune["scorch_seconds"]),
		"soot_in": Num.f(_tune["scorch_soot_in"]),
		"glow_in": Num.f(_tune["scorch_glow_in"]),
		"half_angle": half_angle,
		"energy": (3.0 + strength) * Num.f(_tune["scorch_glow_mult"]),
		"tint": _tint,
	}
	var feet := Vector3(cone_origin.x, target.y - 0.5, cone_origin.z)
	var scorch := FxDecals.spawn(self, feet, FxDecals.Shape.WEDGE, look)
	if flat.length() > 0.01:
		scorch.basis = Basis.looking_at(flat.normalized(), Vector3.UP)


## Leap Slam lift-off: a kick of dust where the kaiju left the ground.
func leap_takeoff(at: Vector3) -> void:
	_city.fx.dust(at + Vector3(0, 0.3, 0), 1.2 * _scale)


## The streak behind the kaiju while it is in the air; on: false stops the trail.
func leap_trail(at: Vector3, on: bool) -> void:
	_trail.position = at
	_trail.emitting = on


## Leap Slam landing: a glowing crater with radial cracks, one dust ripple, street chunks
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
	_city.fx.shockwave(at, reach * 1.3)  # one ripple: the crater and debris are the impact
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


## Heavy stomps crack the street; the cracks glow molten, brighter the heavier the stomp. The
## crack mark, or null when the stomp is too light.
func stomp_cracks(at: Vector3, radius: float, strength: float) -> Decal:
	var from := Num.f(_tune["crack_stomp_power"])
	if strength < from:
		return null
	played.append("cracks")
	var look := {
		"size": radius * 2.2,
		"seconds": Num.f(_tune["crack_seconds"]),
		"cracks": 7,
		"energy": 2.5 + 3.0 * (strength - from),
		"tint": MOLTEN,
		"soot": 0.5,
	}
	return FxDecals.spawn(self, at, FxDecals.Shape.DISC, look)


## Signature ready again: the eyes flare in the species colour (not the whole body, which read
## as taking damage). No ground ring: nothing hits the ground.
func ready_pulse(_feet: Vector3, head: Vector3) -> void:
	played.append("ready")
	_flare(head, 3.0 * _scale, _tint, 0.5)


## Regeneration: a green shimmer runs up the hide and motes drift off it while it heals.
func regen(body_centre: Vector3, healing: bool) -> void:
	_regen.position = body_centre
	if healing and not _regen.emitting:
		played.append("regen")
	_regen.emitting = healing
	_healing = healing


## Armoured Scales: a shell glances off the hide (HideHit, glance): a tiny pale flash on the surface
## and a few dull sparks thrown back the way it came. With the `kaiju` and the shell's origin `from`
## it lands on the real cube the shell meets; without them it is drawn at `at`.
func deflect(at: Vector3, away: Vector3, kaiju: Node3D = null, from := Vector3.ZERO) -> void:
	played.append("deflect")
	if kaiju != null:
		HideHit.land(_city.fx, kaiju, from, at, true, away)
	else:
		_city.fx.hide_hit(at, away.normalized(), 0.12 * _scale, away)


## Fraction of `span` from `from` at which the line first meets a standing chunk (1: none).
func _first_hit(from: Vector3, span: Vector3) -> float:
	var steps := maxi(4, ceili(span.length() / 0.5))
	var near := _near_line(from, from + span)  # b2-3: every building at every step was 20 ms
	for i: int in range(1, steps + 1):
		var t := float(i) / steps
		var p := from + span * t
		for b: RampageSim.Building in near:
			var lx := p.x - (b.x - b.w * 0.5)
			var lz := p.z - (b.z - b.d * 0.5)
			if lx < 0.0 or lz < 0.0 or lx >= b.w or lz >= b.d:
				continue
			if b.frame.top_below(floori(lx), floori(lz), b.height) + 1 > p.y:
				return t
	return 1.0


## The buildings whose footprint overlaps the box from `from` to `to` (ground plane).
func _near_line(from: Vector3, to: Vector3) -> Array[RampageSim.Building]:
	var near: Array[RampageSim.Building] = []
	for b: RampageSim.Building in _city.sim.buildings:
		var x0 := b.x - b.w * 0.5
		var z0 := b.z - b.d * 0.5
		if x0 <= maxf(from.x, to.x) and x0 + b.w >= minf(from.x, to.x):
			if z0 <= maxf(from.z, to.z) and z0 + b.d >= minf(from.z, to.z):
				near.append(b)
	return near


func _flare(at: Vector3, size: float, tint: Color, seconds: float) -> ShaderMaterial:
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
	return mat


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
	p.amount_ratio = GraphicsPresets.cap("particles")  # R 18.3
	p.process_material = mat
	p.draw_pass_1 = mesh
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-20, -10, -20), Vector3(40, 30, 40))
	add_child(p)
	if _warming:
		_city.fx.keep.hold("ability_%d" % mat.get_instance_id(), mat)
	return p


## A one-shot burst of glowing voxels.
func _burst(mat: ParticleProcessMaterial, amount: int, life: float) -> GPUParticles3D:
	var p := _emitter(mat, _glint_mesh, amount, life)
	p.one_shot = true
	p.explosiveness = 0.85
	p.emitting = true
	get_tree().create_timer(life + 0.2).timeout.connect(p.queue_free)
	return p
