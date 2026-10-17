class_name PowersView
extends Node3D
## Placeholder looks for the species powers and the helicopters: readable, cheap and built
## from the existing Fx / CityView helpers only. A later VFX pass replaces them. Reads sim
## events and state; decides nothing. Part of Rampage.
##
## Rig hooks (agreed with kaiju-motion, called only when the model has them):
## tail_sweep(side), grab(limb, at), throw(toward), limb_tip(limb), jaw_open(open), climbing(on).

const INK := Color("7dff3a")
const EGG := Color("e8dcb8")
const YOUNG := Color("3a2a22")
const CAR := Color("8a3b2e")
const TRACER := Color("ffd27a")
const COATS_SHOWN := 4
## Shares of a throw's flight: the tentacle reaching (the rig's 0.3 s reach in 0.7 s), then
## lifting the object on its tip; the rest is the throw.
const REACH_SHARE := 0.43
const LIFT_SHARE := 0.22

var sim: RampageSim
## The rampage's sounds (Rampage sets it): the helicopters' gun and crash.
var sfx: Sfx
## Every power event this view has drawn, by type (read by the flow suite).
var played: Array[String] = []
var _city: CityView
var _kaiju: Node3D
var _tint: Color
var _helis: Dictionary = {}
var _young: Dictionary = {}
var _beam: MeshInstance3D
var _dust_t := 0.0
var _climbing := false
var _glow_mats: Dictionary = {}


func _init(p_sim: RampageSim, city: CityView, kaiju: Node3D, tint: Color) -> void:
	sim = p_sim
	_city = city
	_kaiju = kaiju
	_tint = tint


func _hook(method: String, args: Array) -> void:
	if _kaiju.has_method(method):
		_kaiju.callv(method, args)


## Ground point (a sim Vector2, typed or straight from an event) at height y.
func _w(value: Variant, y: float = 0.0) -> Vector3:
	var p: Vector2 = value
	return Vector3(p.x, y, p.y)


func _glow(color: Color, lit: bool) -> StandardMaterial3D:
	if not _glow_mats.has(color):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		_glow_mats[color] = CityView.glow(color, 3.0) if lit else mat
	var mat: StandardMaterial3D = _glow_mats[color]
	return mat


func _box(size: Vector3, color: Color, lit: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _glow(color, lit)
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## A glowing bar from a to b that fades out over `seconds`.
func _streak(a: Vector3, b: Vector3, color: Color, seconds: float) -> void:
	var width := 0.35 * sim.body_scale()
	var bar := _box(Vector3(width, width, maxf(0.1, a.distance_to(b))), color)
	add_child(bar)
	bar.look_at_from_position(
		(a + b) * 0.5, b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT
	)
	var tween := bar.create_tween()
	tween.tween_property(bar, "scale", Vector3(0.05, 0.05, 1.0), seconds)
	tween.tween_callback(bar.queue_free)


## Returns true when the event was a power's.
func on_event(event: Dictionary, kaiju_at: Vector3) -> bool:
	var bs := sim.body_scale()
	match str(event["type"]):
		"tail_sweep":
			var side := Num.f(event["side"])
			_hook("tail_sweep", [side])
			_city.ring(kaiju_at, Num.f(event["reach"]), UiKit.WARN, 0.35)
			var behind := kaiju_at - _w(sim.facing) * Num.f(event["reach"]) * 0.7
			_city.fx.dust_line(kaiju_at, behind + Vector3(0, 0.5, 0), bs * 2.0)
		"beam_start":
			_hook("jaw_open", [true])
			_beam = _box(Vector3.ONE, _tint.lightened(0.5))
			add_child(_beam)
		"beam_end":
			_hook("jaw_open", [false])
			if _beam != null:
				_beam.queue_free()
				_beam = null
		"coated":
			_coated(event)
		"glide_start":
			_city.fx.dust(kaiju_at + Vector3(0, 0.3, 0), bs * 1.5)
		"glide_land":
			_city.fx.shockwave(kaiju_at, Num.f(event["reach"]) * 1.2, _tint)
			_city.crush(kaiju_at, Num.f(event["reach"]))
		"eggs_laid":
			var eggs: Array = event["at"]
			for at: Vector2 in eggs:
				_city.fx.puff(_w(at, 0.3))
		"brood_hatched":
			_city.fx.puff(_w(event["at"], 0.4))
		"brood_bite":
			var at: Vector2 = event["at"]
			_city.crush(_w(at), 1.6)  # the young eat the people and police where they bite
			_city.fx.puff(_w(at, 0.5))
		"brood_died":
			_city.debris(_w(event["at"], 0.6), YOUNG, Vector3.UP)
		"limb":
			var to: Vector2 = event["at"]
			_streak(kaiju_at + Vector3(0, 1.5 * bs, 0), _w(to, 1.0), _tint, 0.18)
			_city.fx.dust(_w(to, 0.4), 0.6)
		"grab":
			_thrown(event, kaiju_at)
		"throw_land":
			var at := _w(event["at"])
			var radius := Num.f(event["radius"])
			_city.flash(at + Vector3(0, 1.0, 0), Color("ff8a3a"), 9.0, 0.5)
			_city.fx.shockwave(at, radius * 1.3)
			_city.fx.dust(at + Vector3(0, 0.4, 0), radius * 0.6)
			_city.fire(at, 0.6)
			_city.crush(at, radius)
		"ink":
			_city.ring(kaiju_at, Num.f(event["reach"]), INK, 0.8)
			_city.fx.shockwave(kaiju_at, Num.f(event["reach"]), INK)
		"heli_spawned":
			var heli := HelicopterModel.new()
			add_child(heli)
			_helis[Num.i(event["heli"])] = heli
		"heli_fired":
			_heli_fired(Num.i(event["heli"]), kaiju_at)
		"heli_destroyed":
			_heli_down(Num.i(event["heli"]), Vector2(Num.f(event["x"]), Num.f(event["z"])))
		_:
			return false
	if not played.has(str(event["type"])):
		played.append(str(event["type"]))
	return true


## Fire (beam) or ink glowing on a few of the newly coated chunks.
func _coated(event: Dictionary) -> void:
	var b := sim.buildings[Num.i(event["building"])]
	var cells: Array[Vector3i] = event["cells"]
	var ink := str(event["kind"]) == "ink"
	for n: int in mini(COATS_SHOWN, cells.size()):
		var at := b.chunk_world(cells[n * cells.size() / mini(COATS_SHOWN, cells.size())])
		if ink:
			var blob := _box(Vector3.ONE * 1.05, INK)
			blob.position = at
			add_child(blob)
			var tween := blob.create_tween()
			tween.tween_property(
				blob, "scale", Vector3.ONE * 0.2, Num.f(sim.powers_cfg["ink_seconds"])
			)
			tween.tween_callback(blob.queue_free)
		else:
			_city.fire(at, 0.45)


func _thrown(event: Dictionary, kaiju_at: Vector3) -> void:
	var kind := str(event["kind"])
	var from := _w(event["from"], 1.0)
	var to := _w(event["to"], 0.5)
	_hook("grab", [0, from])
	var node: Node3D
	match kind:
		"tank":
			node = TankModel.new()
		"heli":
			node = HelicopterModel.new()
		_:
			node = _box(Vector3(1.0, 0.7, 2.0), CAR, false)
	add_child(node)
	node.position = from
	# The sim's flight (throw_seconds) runs from the grab to the landing. The tentacle reaches
	# (REACH_SHARE), lifts the object on its tip (LIFT_SHARE), then throws it to land on time.
	var seconds := Num.f(sim.powers_cfg["throw_seconds"])
	var hold := kaiju_at + Vector3(0, 4.0 * sim.body_scale(), 0)
	var tween := node.create_tween()
	tween.tween_interval(seconds * REACH_SHARE)
	tween.tween_method(
		func(t: float) -> void: node.position = from.lerp(_tip(hold), t),
		0.0,
		1.0,
		seconds * LIFT_SHARE
	)
	tween.tween_callback(func() -> void: _hook("throw", [to]))
	var flight := seconds * (1.0 - REACH_SHARE - LIFT_SHARE)
	tween.tween_property(node, "position", to, flight)
	tween.parallel().tween_property(node, "rotation", Vector3(TAU, 0, PI), flight)
	tween.tween_callback(node.queue_free)
	if not _kaiju.has_method("limb_tip"):
		_streak(kaiju_at + Vector3(0, 1.5, 0), from, _tint, 0.3)


## Where the holding tentacle's tip is (the rig's limb_tip), or `fallback` without that rig.
func _tip(fallback: Vector3) -> Vector3:
	if _kaiju.has_method("limb_tip"):
		var tip: Vector3 = _kaiju.call("limb_tip", 0)
		return tip
	return fallback


func _heli_fired(id: int, kaiju_at: Vector3) -> void:
	if not _helis.has(id):
		return
	var heli: HelicopterModel = _helis[id]
	var target := kaiju_at + Vector3(0, 3.0 * sim.body_scale(), 0)
	var muzzle := heli.fire()
	_streak(muzzle, target, TRACER, 0.12)
	_city.flash(muzzle, TRACER, 3.0, 0.1)
	_city.fx.sparks(target)
	if sfx != null:
		sfx.play_at("heli_gun", muzzle)


func _heli_down(id: int, at: Vector2) -> void:
	if _helis.has(id):
		var heli: Node3D = _helis[id]
		heli.queue_free()
		_helis.erase(id)
	var ground := _w(at)
	for n: int in 6:
		_city.debris(
			ground + Vector3(0, sim.air.altitude() * 0.5, 0), HelicopterModel.TAN, Vector3.UP
		)
	_city.flash(ground + Vector3(0, 2.0, 0), Color("ff8a3a"), 8.0, 0.5)
	_city.fire(ground, 0.6)
	if sfx != null:
		sfx.play_at("heli_crash", ground)


## The helicopter nodes now in the air.
func helis() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for node: Node3D in _helis.values():
		out.append(node)
	return out


## Per frame: helicopters on their circles, the young on their hunt, the beam along the
## kaiju's facing, and momentum's dust trail.
func update(delta: float, kaiju_at: Vector3) -> void:
	var bs := sim.body_scale()
	var turn := minf(1.0, delta * Num.f(Content.section("vehicles")["heli_turn"]))
	for heli: AirWing.Heli in sim.air.helis:
		if _helis.has(heli.id):
			var node: HelicopterModel = _helis[heli.id]
			var at := _w(heli.pos, sim.air.altitude())
			var to := at - node.position
			node.position = at
			if to.length() > 0.001:  # eased, so a turn at the end of its arc is a bank, not a snap
				var heading := atan2(-to.x, -to.z)
				node.rotation.y = lerp_angle(node.rotation.y, heading, turn)
			node.aim(kaiju_at + Vector3(0, 3.0 * bs, 0))
	var seen := {}
	for y: Brood.Young in sim.brood.young:
		seen[y.id] = true
		var node: Node3D = _young.get(y.id)
		if node == null:
			node = _young_node(y.hatch > 0.0)
			_young[y.id] = node
		if y.hatch <= 0.0 and node.get_meta("egg", false):
			node.queue_free()
			node = _young_node(false)
			_young[y.id] = node
		var at := _w(y.pos)
		var to := at - node.position
		node.position = at
		if to.length() > 0.01:
			node.rotation.y = atan2(-to.x, -to.z)
	for id: int in _young.keys():
		if not seen.has(id):
			var gone: Node3D = _young[id]
			gone.queue_free()
			_young.erase(id)
	if _beam != null:
		var length := Num.f(sim.powers_cfg["beam_range"]) * bs
		var mouth := kaiju_at + Vector3(0, 5.0 * bs, 0) + _w(sim.facing) * bs
		var end := kaiju_at + _w(sim.facing) * length + Vector3(0, 0.8, 0)
		_beam.scale = Vector3(1.4 * bs, 1.4 * bs, mouth.distance_to(end))
		_beam.look_at_from_position((mouth + end) * 0.5, end, Vector3.UP)
		_city.fx.sparks(end)
	var climbing := sim.stand_y > 0.5
	if climbing != _climbing:
		_climbing = climbing
		_hook("climbing", [climbing])
	_dust_t -= delta
	if sim.stat("momentum") > 0.0 and sim.powers.momentum > 0.5 and _dust_t <= 0.0:
		_dust_t = 0.15
		_city.fx.dust(kaiju_at - _w(sim.facing) * bs + Vector3(0, 0.3, 0), bs * sim.powers.momentum)


func _young_node(egg: bool) -> Node3D:
	var node := Node3D.new()
	if egg:
		node.set_meta("egg", true)
		var shell := _box(Vector3(0.8, 1.0, 0.8), EGG, false)
		shell.position.y = 0.5
		node.add_child(shell)
	else:
		# Elephant-sized: a low body, a head and six legs, in the insectoid's dark brown.
		var body := _box(Vector3(1.4, 1.0, 2.4), YOUNG, false)
		body.position.y = 1.2
		node.add_child(body)
		var head := _box(Vector3(1.0, 0.8, 0.8), YOUNG.lightened(0.15), false)
		head.position = Vector3(0, 1.4, -1.5)
		node.add_child(head)
		for n: int in 6:
			var leg := _box(Vector3(0.25, 1.2, 0.25), YOUNG.darkened(0.3), false)
			leg.position = Vector3(0.8 if n % 2 == 0 else -0.8, 0.5, -0.8 + (n / 2) * 0.8)
			node.add_child(leg)
	add_child(node)
	return node
