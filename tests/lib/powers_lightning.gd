extends RefCounted
## The lightning look (D-357), on the real croc rig at every growth step: the Lightning Breath's
## and the Thunder Beam's bolt starts deep in the mouth (inside the wedge between the jaws, behind
## the teeth) on every frame it is lit, never above or in front of the head; and between the press
## and the strike the charge-up arcs jump spine to spine from the tail tip to the head, the last
## one ending as the strike lands, for every strike delay (D-166: 0.8 / 1.1 / 1.4 s, the beam's).

const DT := 1.0 / 60.0
const HALF := deg_to_rad(36.0)
const REACH := 14.0
## How close to the strike the charge's last arc must end (s).
const LAST_SLACK := 0.1
## How far forward of the hinge the bolt may start: this share of the way to the snout's tip.
const DEEP := 0.5
## How far to one side of the head's middle the bolt may start: this share of the mouth's length.
const SIDE := 0.1
## Share of the charge's frames (first hop to strike) that must show an arc.
const SHOWN := 0.9

var _suite: Object
var _check: Callable
var _tree: SceneTree


func _init(suite: SceneTree, check: Callable) -> void:
	_suite = suite
	_check = check
	_tree = suite


func run() -> void:
	var delays: Array = Content.section("strike")["breath"]
	for tier: int in delays.size():
		var stage := KaijuModel.stage_for(tier + 1)
		var kaiju := await _croc(stage)
		_breath(kaiju, stage)
		_thunder(kaiju, stage)
		_charge(kaiju, stage, Strikes.BREATH, Num.f(delays[tier]))
		if tier == delays.size() - 1:
			_charge(kaiju, stage, Strikes.BEAM, Num.f(Content.section("strike")["beam"]))
		kaiju.free()


func _croc(stage: String) -> KaijuModel:
	var def: Dictionary = Content.species_def("reptilian")
	var colors: Dictionary = def["colors"]
	var kaiju := KaijuModel.new("reptilian", colors, stage)
	kaiju.process_mode = Node.PROCESS_MODE_DISABLED
	_tree.root.add_child(kaiju)
	await _tree.process_frame
	_step(kaiju, 10)
	return kaiju


func _step(kaiju: KaijuModel, frames: int) -> void:
	for i: int in frames:
		kaiju.animate(DT, 0.0)


static func _rig(kaiju: Node3D) -> KaijuRig:
	return kaiju.find_children("*", "KaijuRig", true, false)[0] as KaijuRig


## Whether `p` lies in the mouth now: in the head's own space, inside the triangle of the jaw's
## hinge, the upper jaw's tip and the lower jaw's tip, no further forward than DEEP of the way
## to the tip, and no more than SIDE of the mouth's length off the middle.
static func in_mouth(rig: KaijuRig, p: Vector3) -> bool:
	var inv := rig.bone("head1").global_transform.affine_inverse()
	var jaw := rig.bone("jaw").global_transform
	var hinge := inv * jaw.origin
	var low := inv * (jaw * rig.dir_of("jaw"))
	var high := rig.dir_of("head1")
	var q := inv * p
	var tip := minf(high.z, low.z)  # the head looks down -z
	var length := hinge.z - tip
	var share := (hinge.z - q.z) / length
	var flat := Vector2(q.z, q.y)
	var inside := Geometry2D.point_is_inside_triangle(
		flat, Vector2(hinge.z, hinge.y), Vector2(high.z, high.y), Vector2(low.z, low.y)
	)
	return inside and share <= DEEP and absf(q.x) <= SIDE * length


## The breath fired as the game does (from BreathBeam.mouth_of), the jaw dropping just before it.
func _breath(kaiju: KaijuModel, stage: String) -> void:
	var fx := Content.section("fx")
	var bolt: Dictionary = fx["bolt"]
	var charge: Dictionary = bolt.get("charge", {})
	kaiju.jaw_open(true)
	_step(kaiju, roundi(Num.f(charge.get("jaw_before", 0.0)) / DT))
	var beam := BreathBeam.new(Color.WHITE, 1.0, fx)
	beam.process_mode = Node.PROCESS_MODE_DISABLED
	beam.follow = kaiju
	beam.rng = Seeds.make("lightning_test", 1)
	_tree.root.add_child(beam)
	var mouth := BreathBeam.mouth_of(kaiju, Vector3.ZERO)
	var hit := Vector3(0, 0.5, -REACH)
	beam.cone_origin = Vector3(0, 0, -3)
	beam.fire(mouth, hit, hit - mouth, HALF)
	var seen := _lit_frames(kaiju, beam.rig, func() -> void: beam._process(DT))
	_check.call(
		seen.x > 0 and seen.y == seen.x,
		(
			"%s: the Lightning Breath starts deep in the mouth on every lit frame (%d of %d)"
			% [stage, seen.y, seen.x]
		)
	)
	beam.free()
	kaiju.jaw_open(false)
	_step(kaiju, 30)


## The Thunder Beam started as the game does (the sim's beam_start), held for 2 s.
func _thunder(kaiju: KaijuModel, stage: String) -> void:
	var line: Array[Dictionary] = [_suite.call("_b", 0, -12, Vector3i(3, 3, 6))]
	var sim: RampageSim = _suite.call("_sim", "reptilian", {"r_beam": 1}, line, Vector2.ZERO)
	var beam := ThunderBeam.new(sim, kaiju, Color.WHITE, 0)
	beam.process_mode = Node.PROCESS_MODE_DISABLED
	_tree.root.add_child(beam)
	kaiju.jaw_open(true)
	beam.start(2.0, Vector3.ZERO)
	var seen := _lit_frames(kaiju, beam.rig, func() -> void: beam.update(Vector3.ZERO))
	_check.call(
		seen.x > 0 and seen.y == seen.x,
		(
			"%s: the Thunder Beam starts deep in the mouth on every lit frame (%d of %d)"
			% [stage, seen.y, seen.x]
		)
	)
	beam.free()
	kaiju.jaw_open(false)
	_step(kaiju, 30)


## Steps the body and the bolt until it goes out; (frames lit, frames whose bolt starts in the
## mouth).
func _lit_frames(kaiju: KaijuModel, rig: BoltRig, follow: Callable) -> Vector2i:
	rig.process_mode = Node.PROCESS_MODE_DISABLED
	var seen := Vector2i.ZERO
	for i: int in roundi(3.0 / DT):
		kaiju.animate(DT, 0.0)
		follow.call()
		rig._process(DT)
		if not rig.live:
			break
		if rig.drawn_main.size() < 2:
			continue
		seen.x += 1
		if in_mouth(_rig(kaiju), rig.drawn_main[0]):
			seen.y += 1
	return seen


## The press (the sim's strike_windup) through the beam's view: the charge runs tail to head and
## its last arc ends as the strike lands.
func _charge(kaiju: KaijuModel, stage: String, kind: String, strike_in: float) -> void:
	var line: Array[Dictionary] = []
	var sim: RampageSim = _suite.call("_sim", "reptilian", {"r_beam": 1}, line, Vector2.ZERO)
	var beam := ThunderBeam.new(sim, kaiju, Color.WHITE, 0)
	beam.process_mode = Node.PROCESS_MODE_DISABLED
	_tree.root.add_child(beam)
	var label := "%s %s %.1f s" % [stage, kind, strike_in]
	var charge: Node3D = beam.get("charge") if beam.has_method("on_event") else null
	if charge == null:
		_check.call(false, "%s: the press starts a spine charge-up (the view has none)" % label)
		beam.free()
		return
	charge.process_mode = Node.PROCESS_MODE_DISABLED
	var press := {"type": "strike_windup", "kind": kind, "strike_in": strike_in}
	beam.call("on_event", press, Vector3.ZERO)
	var hops: Array[Dictionary] = charge.get("hops")
	_check.call(
		_tail_to_head(kaiju, charge, hops),
		"%s: the arcs jump spine to spine, tail tip to head" % label
	)
	var last := Num.f(hops[-1]["end"]) if not hops.is_empty() else INF
	_check.call(
		absf(last - strike_in) <= LAST_SLACK,
		"%s: the last arc ends within %.1f s of the strike (%.3f)" % [label, LAST_SLACK, last]
	)
	var shown := _shown(kaiju, charge, hops, strike_in)
	_check.call(
		shown.x >= SHOWN and absf(shown.y - strike_in) <= DT * 1.5,
		(
			"%s: arcs show on %.0f%% of the charge's frames and go out at the strike (%.3f s)"
			% [label, shown.x * 100.0, shown.y]
		)
	)
	beam.free()
	kaiju.jaw_open(false)
	_step(kaiju, 30)


## Hop k runs from ridge point k to k+1, in time order, and the ridge walks from the tail's tip to
## the head (each point nearer the snout than the one before).
static func _tail_to_head(kaiju: Node3D, charge: Node3D, hops: Array[Dictionary]) -> bool:
	var points := Num.i(charge.call("ridge_size"))
	if points < 8 or hops.size() != points - 1:
		return false
	var body := _rig(kaiju)
	var head := body.bone("head1").global_transform * body.dir_of("head1")  # the snout
	var before := INF
	for k: int in points:
		var at: Vector3 = charge.call("ridge_point", k)
		var near := at.distance_to(head)
		if near >= before:
			return false
		before = near
	for k: int in hops.size():
		if Num.i(hops[k]["from"]) != k:
			return false
		if k > 0 and Num.f(hops[k]["start"]) <= Num.f(hops[k - 1]["start"]):
			return false
	return true


## Steps the charge to past the strike: (share of frames from the first hop to the strike that
## show an arc, the time the arcs went out).
func _shown(
	kaiju: KaijuModel, charge: Node3D, hops: Array[Dictionary], strike_in: float
) -> Vector2:
	var first := Num.f(hops[0]["start"]) if not hops.is_empty() else 0.0
	var frames := 0
	var lit := 0
	var out := -1.0
	var t := 0.0
	for i: int in roundi((strike_in + 0.3) / DT):
		kaiju.animate(DT, 0.0)
		charge.call("_process", DT)
		t += DT
		var drawn: Array = charge.get("lines")
		if t >= first and t < strike_in - DT * 0.5:
			frames += 1
			lit += 1 if not drawn.is_empty() else 0
		var live: bool = charge.get("live")
		if out < 0.0 and t > first and drawn.is_empty() and not live:
			out = t
	return Vector2(float(lit) / maxf(1.0, frames), out)
