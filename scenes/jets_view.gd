class_name JetsView
extends Node3D
## The jets (D-072), presentation only: each pass the sim calls in (StrikeWing) drawn as its
## Blender jet (JetModel) flying its line at its altitude; its warning as hot marks where its
## rounds will land and hot rings round its bombs' spots, blinking until the pass has gone
## through, and the roar of its fly-by building as it comes; each round a tracer from the nose to
## the kaiju's hide (sparks) or the street (dust), the cannon's burst on the first; each bomb
## falling from under it to a flash, shockwave and fire. A downed jet falls as debris and fire.
## Reads sim events and state; decides nothing. Part of PowersView.

const TRACER := Color("ffd27a")
## Hot, so the warning reads on tan streets and dark roofs alike.
const WARN := Color("ff4a2a")
const MARK := Vector3(0.9, 0.06, 0.45)
const MARK_BLINKS := 3
const TRACER_SECONDS := 0.08
const HIT_HEIGHT := 2.0  # a round strikes the hide this high (per body scale)
const WRECK := Color("ff8a3a")
## The warning lasts this many warn_seconds: it covers the pass from the warning to its end.
const WARN_HOLD := 2.0
const BOMB := Vector3(0.35, 0.35, 1.2)  # a falling bomb, per body scale
const ORDNANCE := Color("d6cfbb")

var sim: RampageSim
var _city: CityView
var _sfx: Sfx
var _jets: Dictionary = {}
var _firing: Dictionary = {}  # jets whose burst has been heard
var _warn_mat: StandardMaterial3D
var _tracer_mat: StandardMaterial3D
var _bomb_mat: StandardMaterial3D


func _init(p_sim: RampageSim, city: CityView, sfx: Sfx) -> void:
	sim = p_sim
	_city = city
	_sfx = sfx
	_warn_mat = CityView.glow(WARN, 3.0)
	_tracer_mat = CityView.glow(TRACER, 3.0)
	_bomb_mat = StandardMaterial3D.new()
	_bomb_mat.albedo_color = ORDNANCE


## Returns true when the event was a jet's.
func on_event(event: Dictionary, kaiju_at: Vector3) -> bool:
	match str(event["type"]):
		"jet_spawned":
			var jet := JetModel.new(str(event["kind"]))
			add_child(jet)
			_jets[Num.i(event["jet"])] = jet
			var from: Vector2 = event["from"]
			var dir: Vector2 = event["dir"]
			_place(jet, from, dir)
		"jet_inbound":
			_warn(event)
			_sfx.play("jet_flyby")
		"jet_bomb_drop":
			_drop(event)
		"jet_bomb":
			_blast(event)
		"jet_strafe":
			_strafe(event, kaiju_at)
		"jet_left", "jet_destroyed":
			_gone(event)
		_:
			return false
	return true


func _process(_delta: float) -> void:
	for jet: StrikeWing.Jet in sim.strike.jets:
		if _jets.has(jet.id):
			var node: Node3D = _jets[jet.id]
			_place(node, jet.pos, jet.dir)


func _place(node: Node3D, at: Vector2, dir: Vector2) -> void:
	node.position = Vector3(at.x, sim.strike.altitude(), at.y)
	node.rotation.y = atan2(-dir.x, -dir.y)


## Where the pass will land: a hot mark on each round's spot and a hot ring round each bomb's,
## blinking until the pass has gone through.
func _warn(event: Dictionary) -> void:
	var rounds: PackedVector2Array = event["rounds"]
	var drops: PackedVector2Array = event["bombs"]
	var jet: JetModel = _jets.get(Num.i(event["jet"]))
	var heading := jet.rotation.y if jet != null else 0.0
	var lasts := Num.f(sim.strike.cfg["warn_seconds"]) * WARN_HOLD
	for p: Vector2 in rounds:
		var mark := _box(MARK, _warn_mat)
		add_child(mark)
		mark.position = Vector3(p.x, MARK.y, p.y)
		mark.rotation.y = heading
		_blink(mark, lasts)
	for p: Vector2 in drops:
		_city.ring(Vector3(p.x, MARK.y, p.y), Num.f(event["radius"]), WARN, lasts)


func _blink(node: Node3D, lasts: float) -> void:
	var blink := lasts / (2.0 * MARK_BLINKS)
	var tween := node.create_tween().set_loops(MARK_BLINKS)
	tween.tween_property(node, "scale", Vector3.ONE * 1.4, blink)
	tween.tween_property(node, "scale", Vector3.ONE, blink)
	tween.finished.connect(node.queue_free)


## A bomb leaving the jet: a pale bomb falling from under it onto its target.
func _drop(event: Dictionary) -> void:
	var from: Vector2 = event["from"]
	var at: Vector2 = event["at"]
	var bomb := _box(BOMB * sim.body_scale(), _bomb_mat)
	add_child(bomb)
	bomb.position = Vector3(from.x, sim.strike.altitude() - 0.5, from.y)
	bomb.look_at(Vector3(at.x, 0, at.y), Vector3.UP)
	var tween := bomb.create_tween()
	tween.tween_property(bomb, "position", Vector3(at.x, 0.3, at.y), Num.f(event["seconds"]))
	tween.tween_callback(bomb.queue_free)


## A bomb landing: flash, shockwave and dust over its blast, fire where it struck.
func _blast(event: Dictionary) -> void:
	var p: Vector2 = event["at"]
	var at := Vector3(p.x, 0.0, p.y)
	var radius := Num.f(event["radius"])
	_city.flash(at + Vector3(0, 1.5, 0), WRECK, 9.0, 0.45)
	_city.fx.shockwave(at, radius * 1.3)
	_city.fx.dust(at + Vector3(0, 0.4, 0), radius * 0.6)
	_city.fire(at, 0.5)
	_city.crush(at, radius)
	_sfx.play_at("jet_bomb", at)


## A round landing: a tracer from the jet's nose to the kaiju (a hit) or the street (a miss).
func _strafe(event: Dictionary, kaiju_at: Vector3) -> void:
	var jet: JetModel = _jets.get(Num.i(event["jet"]))
	if jet == null:
		return
	if not _firing.has(Num.i(event["jet"])):
		_firing[Num.i(event["jet"])] = true
		_sfx.play("jet_cannon")
	var hit: bool = event["hit"]
	var ground: Vector2 = event["at"]
	var at := Vector3(ground.x, 0.1, ground.y)
	if hit:
		at = kaiju_at + Vector3(0, HIT_HEIGHT * sim.body_scale(), 0)
	_streak(jet.nose(), at)
	if hit:
		_city.fx.sparks(at)
	else:
		_city.fx.dust(at, 0.5)


## A jet flown out of the arena, or shot down (debris and fire where it fell).
func _gone(event: Dictionary) -> void:
	var id := Num.i(event["jet"])
	if _jets.has(id):
		var jet: Node3D = _jets[id]
		jet.queue_free()
		_jets.erase(id)
		_firing.erase(id)
	if str(event["type"]) != "jet_destroyed":
		return
	var ground := Vector3(Num.f(event["x"]), 0, Num.f(event["z"]))
	var high := ground + Vector3(0, sim.strike.altitude() * 0.5, 0)
	for _n: int in 6:
		_city.debris(high, JetModel.TAN, Vector3.UP)
	_city.flash(ground + Vector3(0, 2.0, 0), WRECK, 8.0, 0.5)
	_city.fire(ground, 0.6)


func _box(size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## A glowing bar from a to b that thins out over TRACER_SECONDS.
func _streak(a: Vector3, b: Vector3) -> void:
	var width := 0.3 * sim.body_scale()
	var bar := _box(Vector3(width, width, maxf(0.1, a.distance_to(b))), _tracer_mat)
	add_child(bar)
	var up := Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT
	bar.look_at_from_position((a + b) * 0.5, b, up)
	var tween := bar.create_tween()
	tween.tween_property(bar, "scale", Vector3(0.05, 0.05, 1.0), TRACER_SECONDS)
	tween.tween_callback(bar.queue_free)
