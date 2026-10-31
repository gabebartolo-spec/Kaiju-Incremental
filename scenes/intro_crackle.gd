class_name IntroCrackle
extends Node3D
## The kaiju's charge under the water before the rise (director 2026-10-31: "have the water's
## surface start crackling with purple electricity", replacing the spray that rose before him):
## short arcs of the game's one purple bolt (BoltView, D-357's kaiju colour) skate flat over the
## surface round where he will break it, more of them as the rise nears; when he breaks the water
## the same arcs climb the burst's column for a moment. Re-rolled every `crackle_every` seconds
## from a seeded stream; paced by IntroWater from the sim's rise. Presentation only, tuning
## "intro" "water".

var _cfg: Dictionary
var _view: BoltView
var _rng := Seeds.make("intro_crackle", 0)
var _scale := 1.0
var _wait := 0.0


## body_scale: the kaiju's size this run (reach, length and width scale with it).
func _init(cfg: Dictionary, body_scale: float) -> void:
	_cfg = cfg
	_scale = body_scale
	var bolt: Dictionary = Content.section("fx")["bolt"]
	_view = BoltView.new(Num.f(_cfg["crackle_width"]) * body_scale, Color.WHITE, bolt)
	_view.arc_look(1.0, Num.f(bolt["arc_min_px"]))
	_view.set_levels(0.0, 0.0, 1.0)
	add_child(_view)


## Advances the crackle `delta` seconds: `surface` (0..1 along crackle_arcs) arcs on the water
## and `climb` (1 at the break, falling to 0) times burst_arcs up the column standing at
## `body` (local: the sim's splash rises from his body, not from the crown's point). Nothing
## draws when both are off.
func step(delta: float, surface: float, climb: float, body: Vector3) -> void:
	_wait -= delta
	if surface <= 0.0 and climb <= 0.0:
		_view.hide_all()
		return
	if _wait > 0.0:
		return
	_wait = Num.f(_cfg["crackle_every"])
	var counts: Array = _cfg["crackle_arcs"]
	var flat := 0
	if surface > 0.0:
		flat = roundi(lerpf(Num.f(counts[0]), Num.f(counts[1]), surface))
	var arcs: Array[PackedVector3Array] = []
	for i: int in flat:
		arcs.append(_skate())
	if climb > 0.0:
		for i: int in ceili(Num.f(_cfg["burst_arcs"]) * climb):
			arcs.append(_climb(body))
	var none: Array[PackedVector3Array] = []
	_view.rebuild(PackedVector3Array(), none, arcs, Vector2.ONE)


## One arc lying on the water: from a point within crackle_reach, up to crackle_length long.
func _skate() -> PackedVector3Array:
	var at := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf() * Num.f(_cfg["crackle_reach"])
	var way := Vector2.from_angle(_rng.randf() * TAU) * Num.f(_cfg["crackle_length"])
	way *= _rng.randf_range(0.5, 1.0)
	var a := Vector3(at.x, 0.0, at.y) * _scale
	return _shape(a, a + Vector3(way.x, 0.0, way.y) * _scale)


## One arc up the burst's column: from near its middle at the water to up to burst_arc_height.
func _climb(body: Vector3) -> PackedVector3Array:
	var width := Num.f(_cfg["width"]) * _scale
	var foot := Vector2.from_angle(_rng.randf() * TAU) * width * Num.f(_cfg["burst_arc_foot"])
	var top := Vector2.from_angle(_rng.randf() * TAU) * width * Num.f(_cfg["burst_arc_top"])
	var height := Num.f(_cfg["burst_arc_height"]) * _scale * _rng.randf_range(0.5, 1.0)
	return _shape(body + Vector3(foot.x, 0.0, foot.y), body + Vector3(top.x, height, top.y))


func _shape(a: Vector3, b: Vector3) -> PackedVector3Array:
	var shape := BoltShape.channel(_rng, Num.i(_cfg["crackle_rounds"]), Num.f(_cfg["crackle_push"]))
	return BoltShape.place(shape, a, b)
