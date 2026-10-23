class_name LegSink
extends RefCounted
## How far a clip-animated body sinks so no leg reaches past reach_max of its length toward its foot
## (D-177: a leg near full stretch pops its knee): eased in over sink_s, back up over rise_s, at
## most sink_max hip heights (tuning clip_motion "sink"). One rule for the leg solve that draws it
## (LegReach) and a heavy body's contact volume that rides it (HeavyFeet, D-208). Pure, no
## randomness.

static var _tune: Dictionary = {}  # tuning clip_motion "sink", read once


static func _cfg() -> Dictionary:
	if _tune.is_empty():
		_tune = Content.section("clip_motion")["sink"]
	return _tune


## The furthest any leg reaches (share of its length).
static func reach_max() -> float:
	return Num.f(_cfg()["reach_max"])


## The drop (world units) one leg needs: its hip and ankle (world), its length (world).
static func need(hip: Vector3, ankle: Vector3, length: float) -> float:
	var most := reach_max() * length
	var flat := Vector2(ankle.x - hip.x, ankle.z - hip.z).length()
	var drop := hip.y - ankle.y
	if Vector2(flat, drop).length() <= most:
		return 0.0
	return drop - sqrt(maxf(0.0, most * most - flat * flat))


## A two-bone leg's knee (world or rig axes alike): from `root` toward `end`, the bones
## `lengths` (thigh, shin) long, bending toward `pole` (KaijuGait.solve_knee draws with it).
static func knee(root: Vector3, end: Vector3, lengths: Vector2, pole: Vector3) -> Vector3:
	var l1 := lengths.x
	var l2 := lengths.y
	var d := end - root
	var dist := clampf(d.length(), absf(l1 - l2) + 0.0001, l1 + l2 - 0.0001)
	var dir := d.normalized() if d.length() > 0.0001 else Vector3.DOWN
	var cos_a := clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0)
	var p := pole - dir * pole.dot(dir)
	p = p.normalized() if p.length() > 0.0001 else dir.cross(Vector3.RIGHT).normalized()
	return root + dir * (cos_a * l1) + p * (sqrt(maxf(0.0, 1.0 - cos_a * cos_a)) * l1)


## The sink after dt, from `sink` toward the most any leg needs, capped at sink_max x `hip_height`
## (world units).
static func eased(sink: float, needed: float, hip_height: float, dt: float) -> float:
	var tune := _cfg()
	needed = clampf(needed, 0.0, Num.f(tune["sink_max"]) * hip_height)
	var ease := Num.f(tune["sink_s"]) if needed > sink else Num.f(tune["rise_s"])
	return lerpf(sink, needed, 1.0 - exp(-dt / ease))
