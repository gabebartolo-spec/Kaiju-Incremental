extends RefCounted
## The lightning bolt (BoltShape, BoltRig; VFX_STYLE family 6, b2-18): the same seed draws the same
## bolt, a breath's branches never leave the sim's cone, its strokes come 2-3 to a breath and never
## more than 3 full flashes in any second, and a held Thunder Beam keeps to the same rule.

const DT := 1.0 / 60.0
const HALF := deg_to_rad(36.0)
const REACH := 14.0
const SEEDS := 40
## A little slack on the gap between strokes (frame rounding).
const GAP_SLACK := 0.02


static func check(check: Callable) -> void:
	var cfg: Dictionary = Content.section("fx")["bolt"]
	check.call(_same_seed_same_bolt(), "the same seed gives the same channel, another does not")
	check.call(_branches_stay_in_cone(cfg), "every branch end and point lies inside the cone")
	var breath := _strokes(cfg, 0.9, 7)
	check.call(
		breath.size() >= 2 and breath.size() <= 3,
		"a breath strikes 2 or 3 times (got %d)" % [breath.size()]
	)
	var held := _strokes(cfg, 4.0, 11)
	check.call(
		held.size() >= 6, "a held Thunder Beam keeps striking (%d strokes in 4 s)" % [held.size()]
	)
	check.call(
		_max_per_second(held) <= 3,
		"never more than 3 full flashes in any second (%d)" % [_max_per_second(held)]
	)
	check.call(
		_min_gap(held) >= Num.f(cfg["stroke_gap"]) - GAP_SLACK,
		"strokes are at least stroke_gap apart (%.3f s)" % [_min_gap(held)]
	)


static func _cone() -> Dictionary:
	return {
		"origin": Vector3(0, 0, 0),
		"dir": Vector3(0, 0, -1),
		"reach": REACH,
		"half": HALF,
		"y": 0.5,
	}


static func _same_seed_same_bolt() -> bool:
	var a := BoltShape.channel(Seeds.make("bolt_test", 1), 5, 0.06)
	var b := BoltShape.channel(Seeds.make("bolt_test", 1), 5, 0.06)
	var c := BoltShape.channel(Seeds.make("bolt_test", 2), 5, 0.06)
	return a == b and a != c and a.size() == 33


static func _branches_stay_in_cone(cfg: Dictionary) -> bool:
	var cone := _cone()
	var rig := BoltRig.new("breath", Color.WHITE, 1.0, cfg)
	rig.cone = cone
	for n: int in SEEDS:
		var rng := Seeds.make("bolt_cone", n)
		for end: Vector3 in BoltShape.fan_ends(rng, cone, 5):
			if not BoltShape.inside(end, cone):
				return false
			var shape := BoltShape.channel(rng, 4, 0.5)  # a wild one: the cone must still hold
			for p: Vector3 in rig._kept(BoltShape.place(shape, Vector3(0, 3, -2.0), end)):
				if not BoltShape.inside(p, cone):
					return false
	rig.free()
	return true


## Stroke times of a BoltRig played for `seconds` (0.9: a breath; 4: the held beam).
static func _strokes(cfg: Dictionary, seconds: float, seed_index: int) -> Array[float]:
	var rig := BoltRig.new("breath", Color.WHITE, 1.0, cfg)
	rig.cone = _cone()
	rig.aim(Vector3(0, 4, 0), Vector3(0, 0.5, -REACH))
	var times: Array[float] = []
	var clock: Array[float] = [0.0]
	rig.stroked.connect(func(_n: int, _at: Vector3) -> void: times.append(clock[0]))
	rig.play(seconds, Seeds.make("bolt_rig", seed_index))
	for i: int in roundi((seconds + 0.5) / DT):
		clock[0] += DT
		rig._process(DT)
	rig.free()
	return times


static func _max_per_second(times: Array[float]) -> int:
	var most := 0
	for start: float in times:
		var n := 0
		for t: float in times:
			if t >= start and t < start + 1.0:
				n += 1
		most = maxi(most, n)
	return most


static func _min_gap(times: Array[float]) -> float:
	var gap := INF
	for i: int in range(1, times.size()):
		gap = minf(gap, times[i] - times[i - 1])
	return gap
