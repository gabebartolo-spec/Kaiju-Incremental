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
## Seconds the sweep in hand covers (a building that dwarfs the kaiju is chewed at bite_dps x it).
var step_s := 0.0
## The standing chunks the last sweep touched, {building index: {Vector3i: true}} (for tests and
## probes: where the body broke or chewed).
var last_hits: Dictionary = {}


func _init(p_sim: RampageSim, p_cfg: Dictionary) -> void:
	sim = p_sim
	cfg = p_cfg


## How far the body reaches from its position, world units.
func reach() -> float:
	var reach := 0.0
	for d: Array in discs:
		reach = maxf(reach, absf(Num.f(d[0])) + Num.f(d[1]))
	return reach * sim.body_scale()


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


## Every standing chunk the body's discs overlap at a pose, into {building index: {Vector3i: true}};
## `free` adds discs placed in the world, [centre, radius, bottom, top] (a heavy body's tail,
## TailSim.discs: the sizes at body scale 1).
func collect(
	pos: Vector2, facing: Vector2, into: Dictionary, near: Array[int], free: Array = []
) -> void:
	var skin := Num.f(cfg["skin"])
	for d: Array in discs:
		_collect_disc(pos + facing * Num.f(d[0]) * sim.body_scale(), d, skin, into, near)
	for d: Array in free:  # fitted to the drawn mesh: no skin taken off
		var centre: Vector2 = d[0]
		_collect_disc(centre, d, 0.0, into, near)


## One disc at `centre` (world), its radius, bottom and top at d[1], d[2], d[3] (body scale 1),
## each shrunk by `skin` (world units).
func _collect_disc(
	centre: Vector2, d: Array, skin: float, into: Dictionary, near: Array[int]
) -> void:
	var s := sim.body_scale()
	var r := Num.f(d[1]) * s - skin
	if r <= 0.0:
		return
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


## Breaks every standing chunk the body touches moving and turning from one pose to the other in
## `step_s` seconds (a building that dwarfs the kaiju is chewed at bite_dps x step_s instead of
## broken outright, D-091); returns the chunks broken.
## `tail_from` and `tail_to`: a heavy body's own discs (its fitted body and its tail, TailSim.discs)
## at either pose, the same count, swept between them disc by disc; `still`: discs that do not sweep
## (a heavy body's planted feet), taken at the end pose only.
func sweep(
	from: Vector2,
	from_heading: Vector2,
	to: Vector2,
	to_heading: Vector2,
	tail_from: Array = [],
	tail_to: Array = [],
	still: Array = []
) -> int:
	var span := reach()
	for d: Array in still:
		var at: Vector2 = d[0]
		span = maxf(span, at.distance_to(to) + Num.f(d[1]) * sim.body_scale())
	var tail_moved := 0.0
	for k: int in tail_to.size():
		var a: Vector2 = tail_from[k][0]
		var b: Vector2 = tail_to[k][0]
		span = maxf(span, b.distance_to(to) + Num.f(tail_to[k][1]) * sim.body_scale())
		tail_moved = maxf(tail_moved, a.distance_to(b))
	last_hits = {}
	var close := near(from, to, span)
	if close.is_empty():
		return 0
	var turn := from_heading.angle_to(to_heading)
	var travel := maxf(from.distance_to(to) + absf(turn) * span, tail_moved)
	var samples := maxi(1, ceili(travel / maxf(0.05, Num.f(cfg["sample"]))))
	var hits: Dictionary = {}
	var broken := 0
	for n: int in range(1, samples + 1):
		var t := float(n) / samples
		var pose := sweep_pose(from, from_heading, to, to_heading, t)
		var at: Vector2 = pose[0]
		var facing: Vector2 = pose[1]
		var tail: Array = []
		for k: int in tail_to.size():
			var a: Vector2 = tail_from[k][0]
			var b: Vector2 = tail_to[k][0]
			var src: Array = tail_to[k]
			var d := src.duplicate()
			d[0] = a.lerp(b, t)
			tail.append(d)
		collect(at, facing, hits, close, tail)
	if not still.is_empty():
		collect(to, to_heading, hits, close, still)  # where the feet stand: no sweep
	last_hits = hits
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


## The body's pose a fraction `t` along a sweep: [position, heading]. The last sample (t = 1) is
## exactly the end pose, the one the hold test reads, so a rounding error in the turn can never
## leave a chunk the sweep missed but the hold sees.
static func sweep_pose(
	from: Vector2, from_heading: Vector2, to: Vector2, to_heading: Vector2, t: float
) -> Array:
	if t >= 1.0:
		return [to, to_heading]
	return [from.lerp(to, t), from_heading.rotated(from_heading.angle_to(to_heading) * t)]
