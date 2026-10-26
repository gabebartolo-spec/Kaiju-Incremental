extends RefCounted
## What the sea bay's own ground hides of the rise (comment #27 "Nothing in the foreground hides
## the rise"): the beach and sea floor (CityHarbour.floor_at), the street round the bay, and the
## quay walls down its two flanks (HarbourView.quays), as solid ground a sight line can strike,
## for the run intro's shot (fade_spawn's check).

const STEP := 0.2
const QUAY_TOP := 0.4  # a flank quay wall's top over the street (CityGround._harbour)
## Where the head, neck and shoulders are: shares of the way from the body's centre to the head
## along its facing, and drops (share of its height) below its top.
const HEAD := [1.0, 0.0]
const NECK := [0.7, 0.15]
const SHOULDERS := [0.45, 0.3]
## A part counts once it stands this far above the water.
const SHOWS := 0.1

var _plan: Dictionary
var _cfg: Dictionary
var _quays: Array[Rect2]


func _init(sim: RampageSim) -> void:
	_cfg = sim.city
	_plan = CityGen.map(sim.city)
	_quays = HarbourView.quays(_plan)


## The points on the kaiju that must show (head, neck, shoulders) now, the ones above the water.
static func parts(sim: RampageSim) -> PackedVector3Array:
	var out := PackedVector3Array()
	var reach := sim.reach_height()
	var water := CityHarbour.sea(sim.city)
	var head := sim.facing * Num.f(Content.section("intro")["aim_ahead"]) * sim.body_scale()
	for part: Array in [HEAD, NECK, SHOULDERS]:
		var y: float = sim.stand_y + reach * (0.95 - Num.f(part[1]))
		if y > water + SHOWS:
			var at: Vector2 = sim.kaiju_pos + head * Num.f(part[0])
			out.append(Vector3(at.x, y, at.y))
	return out


## Whether ground stands on the sight line eye -> to (the last half unit before `to` excluded).
## burst_open: kept for the callers' signature (the bay has no decks to burst).
func hides(eye: Vector3, to: Vector3, _burst_open: bool) -> bool:
	var steps := maxi(1, ceili(eye.distance_to(to) / STEP))
	var reach_end := maxi(1, steps - ceili(0.5 / STEP))
	for i: int in range(0, reach_end + 1):
		if solid(eye.lerp(to, float(i) / steps)):
			return true
	return false


func solid(p: Vector3) -> bool:
	var at := Vector2(p.x, p.z)
	if p.y < CityHarbour.floor_at(_plan, _cfg, at):
		return true
	return p.y < QUAY_TOP and _quays.any(func(q: Rect2) -> bool: return q.has_point(at))
