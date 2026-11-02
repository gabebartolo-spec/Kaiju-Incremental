class_name PowersView
extends Node3D
## Placeholder looks for the species powers and the helicopters: readable, cheap and built
## from the existing Fx / CityView helpers only. A later VFX pass replaces them. Reads sim
## events and state; decides nothing. Part of Rampage.
##
## Rig hooks (agreed with kaiju-motion, called only when the model has them):
## tail_sweep(side[, "claw"]), jaw_open(open).

const TRACER := Color("ffd27a")
const COATS_SHOWN := 4

var sim: RampageSim
## The rampage's sounds (Rampage sets it): the helicopters' gun and crash.
var sfx: Sfx
## The rooftop defenders (D-063), drawn beside the helicopters; their events come through here.
var rooftops: RooftopView
## Every power event this view has drawn, by type (read by the flow suite).
var played: Array[String] = []
## The roar on every ultimate and leap (D-145).
var roar := RoarCue.new()
var _city: CityView
var _kaiju: Node3D
var _tint: Color
var _helis: Dictionary = {}
var _vip: VipView  # the leader's escape helicopter (D-149)
var _wrecks: HeliWreck
var _thunder: ThunderBeam
var _strike: AirstrikeView  # time's up: the jet run (D-263)
var _dust_t := 0.0
var _glow_mats: Dictionary = {}


func _init(p_sim: RampageSim, city: CityView, kaiju: Node3D, tint: Color) -> void:
	sim = p_sim
	_city = city
	_kaiju = kaiju
	_tint = tint


func _ready() -> void:
	var rampage := get_parent() as Rampage
	rooftops = RooftopView.new(sim, _city, rampage.sfx, Seeds.make("rooftop_fx"))
	rooftops.body = _kaiju
	add_child(rooftops)
	_vip = VipView.new(sim, _city, rampage.sfx)
	add_child(_vip)
	_thunder = ThunderBeam.new(sim, _kaiju, _tint, rampage.run_index)
	add_child(_thunder)
	_thunder.wire(rampage, _city.fx)
	_strike = AirstrikeView.new(rampage.sfx)
	add_child(_strike)


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
	roar.on_event(event, sim.time_left, self, _kaiju)
	_vip.on_event(event)  # the leader's helicopter and its headlines (vip_*, its wreck)
	var bs := sim.body_scale()
	var kind := str(event["type"])
	# The lightning's charge-up, the Thunder Beam.
	if _strike.on_event(event):
		pass
	elif kind in ["strike_windup", "beam_start", "beam_end"]:
		if not _thunder.on_event(event, kaiju_at):
			return false
	elif not _acted(kind, event, kaiju_at, bs):
		return rooftops.on_event(event, kaiju_at)
	if not played.has(str(event["type"])):
		played.append(str(event["type"]))
	return true


## The powers PowersView plays itself (the arms' sweeps, coats, helicopters); false for any
## other event.
func _acted(kind: String, event: Dictionary, kaiju_at: Vector3, bs: float) -> bool:
	match kind:
		"tail_sweep":
			var side := Num.f(event["side"])
			_hook("tail_sweep", [side])
			_city.fx.shockwave_to(kaiju_at, Num.f(event["reach"]))  # dust out to the tail's reach
			var behind := kaiju_at - _w(sim.facing) * Num.f(event["reach"]) * 0.7
			_city.fx.dust_line(kaiju_at, behind + Vector3(0, 0.5, 0), bs * 2.0)
		"tail_windup":
			_hook("tail_sweep", [Num.f(event["side"]), "tail_windup"])
		"swipe_windup":
			_hook("tail_sweep", [Num.f(event["side"]), "claw_windup"])
		"swipe":
			_swiped(event, kaiju_at)
		"coated", "fire_burning":
			_lit(event)
		"heli_spawned":
			_helis[Num.i(event["heli"])] = HelicopterModel.added_to(self)
		"heli_fired":
			_heli_fired(Num.i(event["heli"]), kaiju_at)
		"heli_destroyed", "heli_crashed":
			_heli_down(event)
		_:
			return false
	return true


## A claw swipe crosses now: its arm's sweep, the slash, the lash sound, cars and people crushed.
func _swiped(event: Dictionary, kaiju_at: Vector3) -> void:
	var arc: Dictionary = {}
	if _kaiju.has_method("tail_sweep"):  # the rake crosses now; its arm's sweep
		arc = _kaiju.call("tail_sweep", Num.f(event["side"]), "claw")
	ClawSlash.play(_city, kaiju_at, _w(sim.facing), event, arc)
	if sfx != null:
		sfx.play("lash")
	var mid := lerpf(Num.f(event["near"]), Num.f(event["far"]), 0.5)
	_city.crush(kaiju_at + _w(sim.facing) * mid, Num.f(event["width"]))  # cars, people


func _coated(event: Dictionary) -> void:
	var b := sim.buildings[Num.i(event["building"])]
	var cells: Array[Vector3i] = event["cells"]
	for n: int in mini(COATS_SHOWN, cells.size()):
		var cell := cells[n * cells.size() / mini(COATS_SHOWN, cells.size())]
		_city.burn_chunk(Num.i(event["building"]), cell, 0.45)


## A coat (the beam's fire) on chunks, or a whole building the sim set burning.
func _lit(event: Dictionary) -> void:
	if str(event["type"]) == "coated":
		_coated(event)
	else:
		_burning(Num.i(event["building"]))


## A building the sim set burning (FireSpread): today's chunk fire (flames, embers, smoke) on its
## roof, one per roof quarter (one on a narrow roof), each on the highest standing chunk there;
## each goes out when its chunk breaks or falls, all once the building is down (#111). The glow
## before it and the fire's own look are R 26.5.
func _burning(index: int) -> void:
	var b := sim.buildings[index]
	var size := Num.f(sim.powers_cfg["fire"]["view_size"])
	var span := Num.f(sim.powers_cfg["fire"]["view_spacing"])
	var nx := 2 if b.w >= span else 1
	var nz := 2 if b.d >= span else 1
	for a: int in nx:
		for c: int in nz:
			var cell := Vector3i(floori(b.w * (2 * a + 1) / (2.0 * nx)), 0, 0)
			cell.z = floori(b.d * (2 * c + 1) / (2.0 * nz))
			cell.y = b.frame.top_below(cell.x, cell.z, b.height)
			if cell.y >= 0:
				_city.burn_chunk(index, cell, size)


func _heli_fired(id: int, kaiju_at: Vector3) -> void:
	if not _helis.has(id):
		return
	var heli: HelicopterModel = _helis[id]
	var target := kaiju_at + Vector3(0, 3.0 * sim.body_scale(), 0)
	var muzzle := heli.fire()
	_streak(muzzle, target, TRACER, 0.12)
	_city.flash(muzzle, TRACER, 3.0, 0.1)
	HideHit.land(_city.fx, _kaiju, muzzle, target)
	if sfx != null:
		sfx.play_at("heli_gun", muzzle)


## A helicopter shot down, or its wreck landing: HeliWreck draws how it goes (the sim's fate).
func _heli_down(event: Dictionary) -> void:
	if Num.i(event["heli"]) == VipHeli.ID:
		return  # the leader's wreck is VipView's
	if str(event["type"]) == "heli_crashed":
		_wreck().crashed(event)
		return
	var id := Num.i(event["heli"])
	var node: Node3D = _helis[id] if _helis.has(id) else Node3D.new()
	_helis.erase(id)
	_wreck().downed(node, event, HelicopterModel.paint_of(node))


## The wrecks' view, made on first use (so it has the rampage's sounds).
func _wreck() -> HeliWreck:
	if _wrecks == null:
		_wrecks = HeliWreck.new(_city, sim)
		add_child(_wrecks)
	_wrecks.sfx = sfx
	return _wrecks


## The helicopter nodes now in the air.
func helis() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for node: Node3D in _helis.values():
		out.append(node)
	for node: Node3D in _vip.nodes():
		out.append(node)
	return out


## Per frame: helicopters on their circles, the beam along the kaiju's facing, and momentum's
## dust trail.
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
	_thunder.update(kaiju_at)
	_dust_t -= delta
	if sim.powers.momentum > 0.5 and _dust_t <= 0.0:  # a titan's run (Momentum), always on
		_dust_t = 0.15
		_city.fx.dust(kaiju_at - _w(sim.facing) * bs + Vector3(0, 0.3, 0), bs * sim.powers.momentum)
