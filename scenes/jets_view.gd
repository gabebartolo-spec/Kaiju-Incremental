class_name JetsView
extends Node3D
## The jets (D-072), presentation only: each pass the sim calls in (StrikeWing) drawn as its
## Blender jet (JetModel) flying its line at its altitude; its warning as a row of hot marks along
## the ground where the rounds will land, blinking until the pass has gone through, and the roar of
## its fly-by building as it comes; each round a tracer from the nose to the kaiju's hide (sparks)
## or the street (dust), the cannon's burst on the first. A downed jet falls as debris and fire.
## Reads sim events and state; decides nothing. Part of PowersView.

const TRACER := Color("ffd27a")
## Hot, so the warning reads on tan streets and dark roofs alike.
const WARN := Color("ff4a2a")
const MARK := Vector3(0.9, 0.06, 0.45)
const MARK_BLINKS := 3
const TRACER_SECONDS := 0.08
const HIT_HEIGHT := 2.0  # a round strikes the hide this high (per body scale)
const WRECK := Color("ff8a3a")

var sim: RampageSim
var _city: CityView
var _sfx: Sfx
var _jets: Dictionary = {}
var _firing: Dictionary = {}  # jets whose burst has been heard
var _warn_mat: StandardMaterial3D
var _tracer_mat: StandardMaterial3D


func _init(p_sim: RampageSim, city: CityView, sfx: Sfx) -> void:
	sim = p_sim
	_city = city
	_sfx = sfx
	_warn_mat = CityView.glow(WARN, 3.0)
	_tracer_mat = CityView.glow(TRACER, 3.0)


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
			var from: Vector2 = event["from"]
			var to: Vector2 = event["to"]
			_warn_line(from, to, Num.f(event["lead"]))
			_sfx.play("jet_flyby")
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


## The rounds' line on the ground: hot marks that blink until the pass has gone through.
func _warn_line(from: Vector2, to: Vector2, lead: float) -> void:
	var cfg := sim.strike.cfg
	var marks := Num.i(cfg["rounds"])
	var lasts := lead + from.distance_to(to) / Num.f(cfg["speed"])
	var blink := lasts / (2.0 * MARK_BLINKS)
	for k: int in marks:
		var p := from.lerp(to, k / maxf(1.0, marks - 1.0))
		var mark := _box(MARK, _warn_mat)
		add_child(mark)
		mark.position = Vector3(p.x, MARK.y, p.y)
		mark.rotation.y = atan2(-(to - from).x, -(to - from).y)
		var tween := mark.create_tween().set_loops(MARK_BLINKS)
		tween.tween_property(mark, "scale", Vector3.ONE * 1.4, blink)
		tween.tween_property(mark, "scale", Vector3.ONE, blink)
		tween.finished.connect(mark.queue_free)


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
