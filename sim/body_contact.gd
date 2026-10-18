class_name BodyContact
extends RefCounted
## The kaiju's body as a solid (playtest note 2): a chain of discs along the body's heading,
## sized per life stage to the drawn model (data/tuning.json "contact"), breaks every standing
## chunk it overlaps as it walks or turns, so the model never passes through an intact wall. The
## path between two steps is swept in samples, so a fast move or a quick turn of the long snout
## or tail leaves nothing standing inside the body. A building that dwarfs the kaiju (D-091) is
## chewed at bite_dps x Growth.dwarf_mult instead of broken outright, and holds the body at its
## wall until its chunks give. Part of RampageSim; pure, no randomness.

## A chunk is one sim unit across: its centre is this far from its faces.
const CHUNK_HALF := 0.5

var sim: RampageSim
var cfg: Dictionary
## Where the drawn body faces: it turns toward sim.facing at turn_rate (the model reads it).
var heading := Vector2(0, -1)
## Chunks the body itself has broken this rampage.
var broken := 0
## True on a step a wall that has not given yet held the body back.
var held := false
## The snout tip's forward offset from kaiju_pos at body scale 1, design units ("snout").
var snout := 0.0
## The discs at body scale 1, in design units: [forward offset, radius, bottom, top]; empty
## for a species without a body volume (then the body only slows in walls, as before).
var _discs: Array = []
var _last_pos := Vector2(INF, INF)
var _last_heading := Vector2(0, -1)
var _dt := 0.0


## tuning: the rampage's whole tuning; the body reads its "contact" section.
func _init(p_sim: RampageSim, tuning: Dictionary) -> void:
	sim = p_sim
	cfg = tuning["contact"]
	heading = sim.facing
	_last_heading = heading


## Picks the body volume for a species at the sim's size tier (call after setting the species).
func use_species(species_id: String) -> void:
	var bodies: Dictionary = cfg.get("bodies", {})
	var stages: Array = bodies.get(species_id, [])
	_discs = []
	if not stages.is_empty():
		var stage: Dictionary = stages[clampi(sim.size_tier() - 1, 0, stages.size() - 1)]
		_discs = stage["discs"]
		snout = Num.f(stage["snout"])


func active() -> bool:
	return not _discs.is_empty()


## The discs at body scale 1: [forward offset, radius, bottom, top] each.
func discs() -> Array:
	return _discs


## Snout to tail tip, world units.
func length() -> float:
	var front := 0.0
	var back := 0.0
	for d: Array in _discs:
		front = maxf(front, Num.f(d[0]) + Num.f(d[1]))
		back = minf(back, Num.f(d[0]) - Num.f(d[1]))
	return (front - back) * sim.body_scale()


## Turns the body toward the facing, then breaks what it moved or turned into.
func step(dt: float) -> void:
	var weight := minf(1.0, Num.f(cfg.get("turn_rate", 10.0)) * dt)
	heading = Vector2.from_angle(lerp_angle(heading.angle(), sim.facing.angle(), weight))
	if not active() or sim.airborne:
		_last_pos = Vector2(INF, INF)
		return
	var from := sim.kaiju_pos if _last_pos.x == INF else _last_pos
	var from_heading := heading if _last_pos.x == INF else _last_heading
	_dt = dt
	_sweep(from, from_heading, sim.kaiju_pos, heading)
	held = not inside(sim.kaiju_pos, heading).is_empty()
	if held:
		_hold(from, from_heading)
	_last_pos = sim.kaiju_pos
	_last_heading = heading


## A wall that has not given yet: the body slides along it if it can, else stays where it was.
func _hold(from: Vector2, from_heading: Vector2) -> void:
	var to := sim.kaiju_pos
	var poses: Array[Array] = [
		[Vector2(to.x, from.y), heading], [Vector2(from.x, to.y), heading], [from, heading]
	]
	for pose: Array in poses:
		var at: Vector2 = pose[0]
		if inside(at, heading).is_empty():
			sim.kaiju_pos = at
			return
	sim.kaiju_pos = from
	heading = from_heading


## Whether the body overlaps building `index`'s footprint now (never without a body volume).
func over(index: int) -> bool:
	var b := sim.buildings[index]
	var s := sim.body_scale()
	for d: Array in _discs:
		var c := sim.kaiju_pos + heading * Num.f(d[0]) * s
		var gap := Vector2(
			maxf(absf(c.x - b.x) - b.w * 0.5, 0.0), maxf(absf(c.y - b.z) - b.d * 0.5, 0.0)
		)
		if gap.length() < Num.f(d[1]) * s:
			return true
	return false


## Every standing chunk inside the body at a pose: {building index: {Vector3i: true}}.
func inside(pos: Vector2, facing: Vector2) -> Dictionary:
	var out: Dictionary = {}
	_collect(pos, facing, out, _near(pos, pos, _reach()))
	return out


func _sweep(from: Vector2, from_heading: Vector2, to: Vector2, to_heading: Vector2) -> void:
	var reach := _reach()
	var near := _near(from, to, reach)
	if near.is_empty():
		return
	var turn := from_heading.angle_to(to_heading)
	var travel := from.distance_to(to) + absf(turn) * reach
	var samples := maxi(1, ceili(travel / maxf(0.05, Num.f(cfg["sample"]))))
	var hits: Dictionary = {}
	for n: int in range(1, samples + 1):
		var t := float(n) / samples
		_collect(from.lerp(to, t), from_heading.rotated(turn * t), hits, near)
	for index: int in hits:
		var cells: Array[Vector3i] = []
		for c: Vector3i in hits[index]:
			cells.append(c)
		var before := sim.rubble
		var first := sim.events.size()
		var b := sim.buildings[index]
		var dwarfs := Growth.dwarf_mult(sim.size_tier(), b.tier, sim.city) < 1.0
		var n := sim.damage_chunks(index, cells, Num.f(cfg["bite_dps"]) * _dt if dwarfs else INF)
		var pay := 1.0 if dwarfs else Num.f(cfg["pay_mult"])
		if n > 0:  # what the body breaks outright pays a share (pacing); chewed and falls in full
			sim.rubble = before + (sim.rubble - before) * pay
			sim.events[first]["pay"] = pay
		broken += n


## How far the body reaches from its position, world units.
func _reach() -> float:
	var reach := 0.0
	for d: Array in _discs:
		reach = maxf(reach, absf(Num.f(d[0])) + Num.f(d[1]))
	return reach * sim.body_scale()


## Standing buildings the body can touch moving from `from` to `to`: one pass over the city.
func _near(from: Vector2, to: Vector2, reach: float) -> Array[int]:
	var lo := Vector2(minf(from.x, to.x), minf(from.y, to.y)) - Vector2.ONE * reach
	var hi := Vector2(maxf(from.x, to.x), maxf(from.y, to.y)) + Vector2.ONE * reach
	var out: Array[int] = []
	for i: int in sim.buildings.size():
		var b := sim.buildings[i]
		if b.frame.alive_count == 0:
			continue
		if b.x + b.w * 0.5 < lo.x or b.x - b.w * 0.5 > hi.x:
			continue
		if b.z + b.d * 0.5 < lo.y or b.z - b.d * 0.5 > hi.y:
			continue
		out.append(i)
	return out


func _collect(pos: Vector2, facing: Vector2, into: Dictionary, near: Array[int]) -> void:
	var s := sim.body_scale()
	var skin := Num.f(cfg["skin"])
	for d: Array in _discs:
		var centre := pos + facing * Num.f(d[0]) * s
		var r := Num.f(d[1]) * s - skin
		if r <= 0.0:
			continue
		var y_lo := sim.stand_y + Num.f(d[2]) * s + skin
		var y_hi := sim.stand_y + Num.f(d[3]) * s - skin
		for i: int in near:
			var b := sim.buildings[i]
			if absf(b.x - centre.x) > b.w * 0.5 + r or absf(b.z - centre.y) > b.d * 0.5 + r:
				continue
			# Local cell ranges the disc's square can touch.
			var x0 := maxi(0, floori(centre.x - r - (b.x - b.w * 0.5)))
			var x1 := mini(b.w - 1, floori(centre.x + r - (b.x - b.w * 0.5)))
			var z0 := maxi(0, floori(centre.y - r - (b.z - b.d * 0.5)))
			var z1 := mini(b.d - 1, floori(centre.y + r - (b.z - b.d * 0.5)))
			var y0 := maxi(0, floori(y_lo))
			var y1 := mini(b.height - 1, ceili(y_hi) - 1)
			for x: int in range(x0, x1 + 1):
				for z: int in range(z0, z1 + 1):
					var p := b.chunk_world(Vector3i(x, 0, z))
					var gap := Vector2(
						maxf(absf(p.x - centre.x) - CHUNK_HALF, 0.0),
						maxf(absf(p.z - centre.y) - CHUNK_HALF, 0.0)
					)
					if gap.length() >= r:
						continue
					for y: int in range(y0, y1 + 1):
						var c := Vector3i(x, y, z)
						if b.frame.alive(c):
							if not into.has(i):
								into[i] = {}
							var cells: Dictionary = into[i]
							cells[c] = true
