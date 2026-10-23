class_name BodyVolume
extends RefCounted
## The kaiju's body volume (BodyContact's discs) asked where it touches the city: how far it
## reaches, which standing buildings it can touch along a move, and every standing chunk inside it
## at a pose. Part of BodyContact; pure, no randomness.

## A chunk is one sim unit across: its centre is this far from its faces.
const CHUNK_HALF := 0.5

## The discs at body scale 1, in design units: [forward offset, radius, bottom, top].
var discs: Array = []
var sim: RampageSim
var cfg: Dictionary


## A move of the body between two poses: where it was and faced, where it is and faces.
class Move:
	var from: Vector2
	var from_heading: Vector2
	var to: Vector2
	var to_heading: Vector2

	func _init(p_from: Vector2, p_from_way: Vector2, p_to: Vector2, p_to_way: Vector2) -> void:
		from = p_from
		from_heading = p_from_way
		to = p_to
		to_heading = p_to_way

	## The pose a fraction `t` along the move: [position, heading]. The last sample (t = 1) is
	## exactly the end pose, the one the hold test reads, so a rounding error in the turn can never
	## leave a chunk the sweep missed but the hold sees.
	func at(t: float) -> Array:
		if t >= 1.0:
			return [to, to_heading]
		return [from.lerp(to, t), from_heading.rotated(from_heading.angle_to(to_heading) * t)]


## Seconds the sweep in hand covers (a building that dwarfs the kaiju is chewed at bite_dps x it).
var step_s := 0.0
## The standing chunks the last sweep touched, {building index: {Vector3i: true}} (for tests and
## probes: where the body broke or chewed).
var last_hits: Dictionary = {}
var _into: Dictionary = {}  # where collect() puts what it finds, and the buildings it searches
var _near: Array[int] = []


func _init(p_sim: RampageSim, p_cfg: Dictionary) -> void:
	sim = p_sim
	cfg = p_cfg


## How far the body reaches from its position, world units.
func reach() -> float:
	var reach := 0.0
	for d: Array in discs:
		reach = maxf(reach, absf(Num.f(d[0])) + Num.f(d[1]))
	return reach * sim.body_scale()


## Whether `body` discs ([forward offset, radius, ...], body scale 1) at a pose ([position,
## facing]) overlap building b's footprint.
func over(b: RampageSim.Building, body: Array, pose: Array) -> bool:
	var s := sim.body_scale()
	var pos: Vector2 = pose[0]
	var facing: Vector2 = pose[1]
	for d: Array in body:
		var c := pos + facing * Num.f(d[0]) * s
		var gap := Vector2(
			maxf(absf(c.x - b.x) - b.w * 0.5, 0.0), maxf(absf(c.y - b.z) - b.d * 0.5, 0.0)
		)
		if gap.length() < Num.f(d[1]) * s:
			return true
	return false


## Standing buildings the body can touch moving from `from` to `to`: one pass over the city.
func near(from: Vector2, to: Vector2, reach: float) -> Array[int]:
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


## Every standing chunk the body's discs overlap at a pose ([position, facing]), into {building
## index: {Vector3i: true}}; `free` adds a heavy body's own slots placed in the world
## (HeavyContact.discs: [bottom centre, radius, bottom, top, top centre, radius], the sizes at body
## scale 1).
func collect(pose: Array, into: Dictionary, near: Array[int], free: Array = []) -> void:
	var pos: Vector2 = pose[0]
	var facing: Vector2 = pose[1]
	var skin := Num.f(cfg["skin"])
	_into = into
	_near = near
	for d: Array in discs:
		_collect_disc(pos + facing * Num.f(d[0]) * sim.body_scale(), d, skin)
	for d: Array in free:  # the drawn body's own: no skin taken off
		_collect_slot(d)
	_into = {}
	_near = []


## One disc at `centre` (world), its radius, bottom and top at d[1], d[2], d[3] (body scale 1),
## each shrunk by `skin` (world units), into _into.
func _collect_disc(centre: Vector2, d: Array, skin: float) -> void:
	var into := _into
	var s := sim.body_scale()
	var r := Num.f(d[1]) * s - skin
	if r <= 0.0:
		return
	var y_lo := sim.stand_y + Num.f(d[2]) * s + skin
	var y_hi := sim.stand_y + Num.f(d[3]) * s - skin
	for i: int in _near:
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


## One of a heavy body's slots (HeavyContact.discs), the hull of a disc at its bottom and one at its
## top (a leaning, tapering column), into _into: each chunk row is tested against the slot's disc at
## the row's bottom, middle and top.
func _collect_slot(d: Array) -> void:
	var s := sim.body_scale()
	var a: Vector2 = d[0]
	var b_end: Vector2 = d[4]
	var radii := Vector2(Num.f(d[1]), Num.f(d[5])) * s
	var y_lo := sim.stand_y + Num.f(d[2]) * s
	var y_hi := sim.stand_y + Num.f(d[3]) * s
	var r := maxf(radii.x, radii.y)
	if r <= 0.0:
		return
	var first := floori(y_lo)
	var rows := PackedFloat32Array()  # laid out once a building is in reach
	var box_lo := a.min(b_end) - Vector2.ONE * r
	var box_hi := a.max(b_end) + Vector2.ONE * r
	for i: int in _near:
		var b := sim.buildings[i]
		var left := b.x - b.w * 0.5
		var back := b.z - b.d * 0.5
		var x0 := maxi(0, floori(box_lo.x - left))
		var x1 := mini(b.w - 1, floori(box_hi.x - left))
		var z0 := maxi(0, floori(box_lo.y - back))
		var z1 := mini(b.d - 1, floori(box_hi.y - back))
		var y0 := maxi(0, first)
		var y1 := mini(b.height - 1, ceili(y_hi) - 1)
		if x0 > x1 or z0 > z1 or y0 > y1:
			continue
		if rows.is_empty():
			rows = _slot_rows(PackedVector2Array([a, b_end]), radii, Vector2(y_lo, y_hi))
		for x: int in range(x0, x1 + 1):
			for z: int in range(z0, z1 + 1):
				var p := Vector2(left + x + CHUNK_HALF, back + z + CHUNK_HALF)
				if Geometry2D.get_closest_point_to_segment(p, a, b_end).distance_to(p) >= r + 0.71:
					continue  # past the column's widest reach from its axis
				for y: int in range(y0, y1 + 1):
					if _in_row(p, rows, (y - first) * 9):
						_hit(i, Vector3i(x, y, z))


## The slot's discs for each chunk row it spans (from floor(heights.x)), at the row's bottom,
## middle and top: [centre x, z, radius] x 3 per row.
## ends: the bottom and top centres; heights: lowest, highest (world).
static func _slot_rows(
	ends: PackedVector2Array, radii: Vector2, heights: Vector2
) -> PackedFloat32Array:
	var tall := maxf(heights.y - heights.x, 0.0001)
	var first := floori(heights.x)
	var out := PackedFloat32Array()
	out.resize((ceili(heights.y) - first) * 9)
	var k := 0
	for y: int in range(first, ceili(heights.y)):
		for half: int in 3:  # the row's bottom, middle and top
			var t := clampf((y + half * 0.5 - heights.x) / tall, 0.0, 1.0)
			var c := ends[0].lerp(ends[1], t)
			out[k] = c.x
			out[k + 1] = c.y
			out[k + 2] = lerpf(radii.x, radii.y, t)
			k += 3
	return out


## Whether a chunk column at `p` (its centre, world) overlaps one of the three discs from rows[k].
static func _in_row(p: Vector2, rows: PackedFloat32Array, k: int) -> bool:
	for n: int in 3:
		var at := k + n * 3
		var gap := Vector2(
			maxf(absf(p.x - rows[at]) - CHUNK_HALF, 0.0),
			maxf(absf(p.y - rows[at + 1]) - CHUNK_HALF, 0.0)
		)
		if gap.length() < rows[at + 2]:
			return true
	return false


## A standing chunk the body touches: into _into.
func _hit(i: int, c: Vector3i) -> void:
	if not sim.buildings[i].frame.alive(c):
		return
	if not _into.has(i):
		_into[i] = {}
	var cells: Dictionary = _into[i]
	cells[c] = true


## Breaks every standing chunk the body touches on `move` in `step_s` seconds (a building that
## dwarfs the kaiju is chewed at bite_dps x step_s instead of broken outright, D-091); returns the
## chunks broken. `own_from` and `own_to`: a heavy body's own discs (HeavyContact.discs) at either
## pose, the same count, swept between them disc by disc.
func sweep(move: Move, own_from: Array = [], own_to: Array = []) -> int:
	var span := reach()
	var own_moved := 0.0
	for k: int in own_to.size():
		for e: int in [0, 4]:  # the slot's bottom and top
			var a: Vector2 = own_from[k][e]
			var b: Vector2 = own_to[k][e]
			span = maxf(span, b.distance_to(move.to) + Num.f(own_to[k][e + 1]) * sim.body_scale())
			own_moved = maxf(own_moved, a.distance_to(b))
	last_hits = {}
	var close := near(move.from, move.to, span)
	if close.is_empty():
		return 0
	var turn := move.from_heading.angle_to(move.to_heading)
	var travel := maxf(move.from.distance_to(move.to) + absf(turn) * span, own_moved)
	var samples := maxi(1, ceili(travel / maxf(0.05, Num.f(cfg["sample"]))))
	var hits: Dictionary = {}
	for n: int in range(1, samples + 1):
		var t := float(n) / samples
		var own: Array = []
		for k: int in own_to.size():
			var src: Array = own_to[k]
			var d := src.duplicate()
			for e: int in [0, 4]:  # the slot's bottom and top
				var a: Vector2 = own_from[k][e]
				var b: Vector2 = src[e]
				d[e] = a.lerp(b, t)
			own.append(d)
		collect(move.at(t), hits, close, own)
	last_hits = hits
	return _break(hits)


## Breaks (or chews) the chunks swept; returns how many broke.
func _break(hits: Dictionary) -> int:
	var broken := 0
	for index: int in hits:
		var cells: Array[Vector3i] = []
		for c: Vector3i in hits[index]:
			cells.append(c)
		var before := sim.rubble
		var first := sim.events.size()
		var b := sim.buildings[index]
		var dwarfs := Growth.dwarf_mult(sim.size_tier(), b.tier, sim.city) < 1.0
		var n := sim.damage_chunks(index, cells, Num.f(cfg["bite_dps"]) * step_s if dwarfs else INF)
		var pay := 1.0 if dwarfs else Num.f(cfg["pay_mult"])
		if n > 0:  # what the body breaks outright pays a share (pacing); chewed and falls in full
			sim.rubble = before + (sim.rubble - before) * pay
			sim.events[first]["pay"] = pay
		broken += n
	return broken
