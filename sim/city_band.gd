class_name CityBand
extends RefCounted
## The real band past the arena's edge (director, build 2 note 6: "ALL buildings in the play
## area must be destroyable"). As far past the edge as the game camera shows (city.view_beyond),
## every block holds real, destroyable buildings, out of the kaiju's walk but not its reach; the
## painted stand-ins (CitySkyline) only start past it, where the fog takes them. Part of
## CityGen.map, split out to keep files small. Pure.


## How far from the centre real buildings stand, measured square (the arena's shape).
static func extent(cfg: Dictionary) -> float:
	return CityGen.half_extent(cfg) + Num.f(cfg["arena_margin"]) + Num.f(cfg["view_beyond"])


## How far a rect's nearest point lies from the centre, measured square.
static func near_edge(rect: Rect2) -> float:
	var dx := 0.0
	if rect.position.x * rect.end.x > 0.0:
		dx = minf(absf(rect.position.x), absf(rect.end.x))
	var dz := 0.0
	if rect.position.y * rect.end.y > 0.0:
		dz = minf(absf(rect.position.y), absf(rect.end.y))
	return maxf(dx, dz)


## True when a footprint centred on (x, z) of `size` reaches inside the square of `half`.
static func touches(x: float, z: float, size: Vector2, half: float) -> bool:
	return near_edge(Rect2(Vector2(x, z) - size * 0.5, size)) < half


## True when a block at `rect` holds real buildings at this stage: it starts inside the band.
static func real(rect: Rect2, cfg: Dictionary) -> bool:
	return near_edge(rect) < extent(cfg)


## The blocks of districts not yet in play (inner: CityGen.map's indices of every block inside
## the last district) that lie past the band become "outer" stand-ins, keeping the use they will
## have under "was", so CityGen.generate draws their lots the same at every stage and drops them.
static func hold_back(plan: Dictionary, inner: Array[int], cfg: Dictionary) -> void:
	var blocks: Array[Dictionary] = plan["blocks"]
	for n: int in inner:
		var block := blocks[n]
		var rect: Rect2 = block["rect"]
		if block.has("was") or real(rect, cfg):
			continue  # the river's blocks keep their own (CityRiver), the band stays real
		block["was"] = block["use"]
		block["use"] = "outer"
