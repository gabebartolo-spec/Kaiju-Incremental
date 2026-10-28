class_name SpineCharge
extends Node3D
## The lightning's charge-up (D-357): between the press and the strike of the Lightning Breath or
## the Thunder Beam, short forked arcs of the game's one bolt (BoltView, VFX_STYLE family 6) jump
## from spine to spine along the croc's back ridge, tail tip to head, the last one ending as the
## strike lands; the jaw drops for the last of it, so the bolt leaves an open maw. Arcs only, never
## a steady glow (the glowing-plate run is the Godzilla charge-up D-108 steers away from). It fits
## inside the D-166 strike delay and changes nothing in the sim. Numbers: tuning "fx" "bolt"
## "charge". Presentation only.

## The charge's last arc ended (the strike lands now): its kind ("breath", "beam").
signal finished(kind: String)

## No ridge cell found (_ridge_top).
const NONE := Vector3(0.0, -INF, 0.0)

## Every hop of the charge so far, in order: {"from": ridge index, "start": s, "end": s} (a test
## reads it to prove the tail-to-head order and the timing).
var hops: Array[Dictionary] = []
## The arcs drawn now, world polylines (a capture projects them).
var lines: Array[PackedVector3Array] = []
## Charging now.
var live := false

var _cfg: Dictionary
var _view: BoltView
var _model: Node3D
var _rig: KaijuRig
var _bones: Array[String] = []
var _ridge: Array[Vector3] = []  # bone-local ridge points, in _bones order
var _rng: RandomNumberGenerator
var _kind := ""
var _t := 0.0
var _strike := 0.0
var _gap := 0.0
var _wait := 0.0
var _jaw_shut_at := INF


## model: the kaiju (a KaijuModel with a KaijuRig under it); body_scale: its size this run.
func _init(model: Node3D, eye: Color, body_scale: float, bolt: Dictionary) -> void:
	_model = model
	_cfg = bolt["charge"]
	_view = BoltView.new(Num.f(_cfg["width"]) * body_scale, eye, bolt)
	_view.arc_look(Num.f(_cfg["alpha"]), Num.f(_cfg["min_px"]))
	add_child(_view)


## Every material the charge draws with, for the shader keep.
func materials() -> Array[ShaderMaterial]:
	return _view.all_materials()


## The press: `strike_in` seconds until the strike lands; arcs drawn from `rng`.
func start(kind: String, strike_in: float, rng: RandomNumberGenerator) -> void:
	_find_ridge()
	_kind = kind
	_rng = rng
	_t = 0.0
	_wait = 0.0
	_strike = strike_in
	hops.clear()
	lines.clear()
	var count := _ridge.size() - 1
	live = count > 0 and strike_in > Num.f(_cfg["hop_life"])
	if not live:
		return
	var lead := minf(Num.f(_cfg["lead_in"]), strike_in - Num.f(_cfg["hop_life"]))
	_gap = (strike_in - lead - Num.f(_cfg["hop_life"])) / maxf(1.0, count - 1.0)
	for k: int in count:
		var start_at := lead + _gap * k
		hops.append({"from": k, "start": start_at, "end": start_at + Num.f(_cfg["hop_life"])})
	if kind == Strikes.BEAM:
		_jaw_shut_at = INF  # the beam's own end shuts it (beam_end)


## Where the ridge point `index` (tail tip 0 .. head) is in the world now.
func ridge_point(index: int) -> Vector3:
	return _rig.bone(_bones[index]).global_transform * _ridge[index]


## How many ridge points the charge runs over (0 before the first start).
func ridge_size() -> int:
	return _ridge.size()


func _process(delta: float) -> void:
	_jaw(delta)
	if not live:
		return
	_t += delta
	if _t >= _strike:
		live = false
		lines.clear()
		_view.hide_all()
		if _kind == Strikes.BREATH:
			_jaw_shut_at = Num.f(Content.section("fx")["beam_seconds"])
		finished.emit(_kind)
		return
	if _t >= _strike - Num.f(_cfg["jaw_before"]):
		_open_jaw(true)
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = Num.f(_cfg["every"])
	_draw()


## Re-rolls every hop alive now: a jagged arc from its spine to the next, and a fork or two.
func _draw() -> void:
	lines.clear()
	var fork: Array = _cfg["fork"]
	for hop: Dictionary in hops:
		if _t < Num.f(hop["start"]) or _t >= Num.f(hop["end"]):
			continue
		var k := Num.i(hop["from"])
		var a := ridge_point(k)
		var b := ridge_point(k + 1)
		var push := Num.f(_cfg["push"])
		var arc := BoltShape.place(BoltShape.channel(_rng, Num.i(_cfg["rounds"]), push), a, b)
		lines.append(arc)
		for f: int in Num.i(_cfg["forks"]):
			var from := BoltShape.at_t(arc, _rng.randf_range(0.2, 0.8))
			var away := (b - a).length() * _rng.randf_range(Num.f(fork[0]), Num.f(fork[1]))
			var way := Vector3(
				_rng.randf_range(-1, 1), _rng.randf_range(0.2, 1), _rng.randf_range(-1, 1)
			)
			var to := from + way.normalized() * away
			lines.append(BoltShape.place(BoltShape.channel(_rng, 2, push), from, to))
	_view.set_levels(0.0, 0.0, _rng.randf_range(Num.f(_cfg["level"][0]), Num.f(_cfg["level"][1])))
	_view.rebuild(PackedVector3Array(), [], lines, Vector2.ONE)


## After a breath the jaw stays open for its bolt, then shuts.
func _jaw(delta: float) -> void:
	if _jaw_shut_at == INF:
		return
	_jaw_shut_at -= delta
	if _jaw_shut_at <= 0.0:
		_jaw_shut_at = INF
		_open_jaw(false)


func _open_jaw(open: bool) -> void:
	if _model.has_method("jaw_open"):
		_model.call("jaw_open", open)


## The ridge from tail tip to head (tuning "bones"): on each bone, the highest cell of its middle
## stretch at rest, lifted a little clear of the hide. Looked up at every press: a growth stage
## rebuilds the body.
func _find_ridge() -> void:
	var found := _model.find_children("*", "KaijuRig", true, false)
	var rig: KaijuRig = found[0] if not found.is_empty() else null
	if rig == _rig and not _ridge.is_empty():
		return
	_rig = rig
	_bones.clear()
	_ridge.clear()
	if rig == null:
		return
	var lift := Num.f(_cfg["lift"]) * rig.voxel_size()
	var middle: Array = _cfg["middle"]
	for bone_name: String in _cfg["bones"]:
		var top := _ridge_top(rig, bone_name, middle) if rig.has_bone(bone_name) else NONE
		if top != NONE:
			_bones.append(bone_name)
			_ridge.append(top - rig.head_of(bone_name) + Vector3.UP * lift)


## The highest cell of `bone_name`'s middle stretch (`middle`: shares of the way along it), in the
## bone's rest space; NONE when it has no cell there.
static func _ridge_top(rig: KaijuRig, bone_name: String, middle: Array) -> Vector3:
	var cells := rig.voxels_of(bone_name)
	if cells == null:
		return NONE
	var head := rig.head_of(bone_name)
	var axis := rig.dir_of(bone_name)
	var best := NONE
	for cell: Vector3i in cells.cells:
		var p := (Vector3(cell) + Vector3(0, 0.5, 0)) * rig.voxel_size()
		var along := (p - head).dot(axis) / maxf(axis.length_squared(), 0.0001)
		if along >= Num.f(middle[0]) and along <= Num.f(middle[1]) and p.y > best.y:
			best = p
	return best
