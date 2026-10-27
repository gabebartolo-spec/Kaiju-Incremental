extends RefCounted
## D-062 (director 2026-10-18: "there should never be vast empty spaces with nothing to smash
## or kill"): splits the playfield, and the band past its edge the game camera shows, into
## square cells (city.coverage_cell) and finds the cells on or beside a street that hold
## nothing. Inside the arena a cell needs something to smash (a building, a parked or moving
## car, a prop, a person); in the band past it, where the kaiju never walks, a skyline
## stand-in building or a parked car will do (dense city, never bare asphalt).

const EPS := 0.01  # metres: a point or a centre this close to an edge counts as on it


## {"cells", "empty": [cell centres], "arena_empty", "band_empty", "map": ('#' full,
## 'o' empty in the arena, '.' empty in the band, ' ' no street)}. decor, street and skyline
## have run _ready.
static func measure(
	sim: RampageSim, decor: CityDecor, street: StreetLife, skyline: CitySkyline
) -> Dictionary:
	var cfg := sim.city
	var size := Num.f(cfg["coverage_cell"])
	var reach := sim.arena_half + Num.f(cfg["view_beyond"])
	var n := ceili(reach * 2.0 / size)
	var origin := -n * size * 0.5
	var full := {}
	var road := {}
	var mark := func(p: Vector2, into: Dictionary) -> void:
		var c := Vector2i(floori((p.x - origin) / size), floori((p.y - origin) / size))
		if c.x >= 0 and c.y >= 0 and c.x < n and c.y < n:
			var held: Array = into.get(c, [])
			held.append(p)
			into[c] = held
	var plan := CityGen.map(cfg)
	var nodes: Array[Vector2] = plan["nodes"]
	for s: Dictionary in plan["streets"]:
		var a := nodes[Num.i(s["from"])]
		var b := nodes[Num.i(s["to"])]
		var steps := maxi(1, ceili(a.distance_to(b) / (size * 0.25)))
		for i: int in steps + 1:
			mark.call(a.lerp(b, float(i) / steps), road)
	# A footprint marks every cell it reaches: sampled a quarter cell apart, edges included.
	var cover := func(r: Rect2, into: Dictionary) -> void:
		var nx := maxi(1, ceili(r.size.x / (size * 0.25)))
		var nz := maxi(1, ceili(r.size.y / (size * 0.25)))
		for i: int in nx + 1:
			for j: int in nz + 1:
				mark.call(r.position + r.size * Vector2(float(i) / nx, float(j) / nz), into)
	for bld: RampageSim.Building in sim.buildings:
		cover.call(Rect2(bld.x - bld.w * 0.5, bld.z - bld.d * 0.5, bld.w, bld.d), full)
	for g: Dictionary in decor._props._groups:
		var at: Vector3 = g["at"]
		mark.call(Vector2(at.x, at.z), full)
	for car: Traffic.Car in street.traffic.cars:
		mark.call(car.pos, full)
	for at: Vector2 in street.pos:
		mark.call(at, full)
	var dressed := {}  # the band only: stand-ins count there, never inside the arena
	for box: Dictionary in skyline._near:
		var at: Vector3 = box["at"]
		var sz: Vector3 = box["size"]
		cover.call(Rect2(at.x - sz.x * 0.5, at.z - sz.z * 0.5, sz.x, sz.z), dressed)
	var coast := Num.f(cfg["coast_z"])
	var river: Vector2 = plan.get("river", Vector2(INF, -INF))  # water, like the bay (D-083)
	var basin := CityHarbour.bands(plan, cfg)  # the sea bay the kaiju rises in
	var empty: Array[Vector2] = []
	var lines: PackedStringArray = []
	var checked := 0
	var arena_empty := 0
	for j: int in n:
		var line := ""
		for i: int in n:
			var c := Vector2i(i, j)
			var centre := Vector2(origin + (i + 0.5) * size, origin + (j + 0.5) * size)
			var wet := CityHarbour.holds(plan, centre)
			var cell := Rect2(centre - Vector2.ONE * size * 0.5, Vector2.ONE * size)
			var dry := GroundKit.cut([cell], basin)  # the cell less the bay (all of it: no bay)
			if (
				not road.has(c)
				or centre.y < coast
				or (centre.y > river.x and centre.y < river.y)
				or wet
			):
				line += " "
				continue
			checked += 1
			var in_arena := maxf(absf(centre.x), absf(centre.y)) <= sim.arena_half
			var here: Array = full.get(c, [])
			var band: Array = dressed.get(c, [])
			if _covered(here, dry) or (not in_arena and _covered(band, dry)):
				line += "#"
			else:
				line += "o" if in_arena else "."
				empty.append(centre)
				if in_arena:
					arena_empty += 1
		lines.append(line)
	return {
		"cells": checked,
		"empty": empty,
		"arena_empty": arena_empty,
		"band_empty": empty.size() - arena_empty,
		"map": "\n".join(lines),
	}


## The bare cells without the river's bank row (the band plus half a cell each side: the cells
## touching the water). Fixtures that switch the riverside crates off use this: no alleys run on
## the banks, so that row is bare without the crates, whatever the fixture tests. The real-game
## checks (crates on) keep the row.
static func off_bank(empty: Variant, sim: RampageSim) -> Array:
	var river: Vector2 = CityGen.map(sim.city).get("river", Vector2(INF, -INF))
	var pad := Num.f(sim.city["coverage_cell"]) * 0.5
	var kept: Array = []
	var cells: Array = empty
	for at: Vector2 in cells:
		if at.y < river.x - pad or at.y > river.y + pad:
			kept.append(at)
	return kept


## Whether every separate dry part of a cell (dry: GroundKit.cut of it by the bay, its touching
## pieces taken as one part: see _regions) holds one of the points marked in it (within EPS); a
## cell the bay never reaches is its own one part.
static func _covered(points: Array, dry: Array[Rect2]) -> bool:
	for region: Array in _regions(dry):
		var held := false
		for piece: Rect2 in region:
			var near := piece.grow(EPS)
			if points.any(func(p: Vector2) -> bool: return near.has_point(p)):
				held = true
				break
		if not held:
			return false
	return not dry.is_empty()


## `dry`'s pieces grouped into the parts of ground they make: pieces that overlap or share an edge
## are one part. The bay's water is stepped bands (CityHarbour.bands), so the ground beside it
## is cut into strips a band high that are one stretch of shore, not separate places.
static func _regions(dry: Array[Rect2]) -> Array:
	var regions: Array = []
	for piece: Rect2 in dry:
		var joined: Array[Rect2] = [piece]
		var apart: Array = []
		for region: Array in regions:
			if region.any(func(r: Rect2) -> bool: return r.grow(EPS).intersects(piece)):
				joined.append_array(region)
			else:
				apart.append(region)
		apart.append(joined)
		regions = apart
	return regions


## The rule itself, on planted cells (D-062): a bare cell is bare, a mark anywhere on a cell's one
## dry part covers it, the bay's stepped edge (strips a band high) is one stretch of shore, and a
## dry part the bay cut off from the rest still needs a mark of its own.
static func check_rule(check: Callable) -> void:
	var cell := Rect2(0.0, 0.0, 10.0, 10.0)
	var whole: Array[Rect2] = [cell]
	check.call(not _covered([], whole), "a planted bare cell (no mark) is bare")
	check.call(not _covered([Vector2(11.0, 5.0)], whole), "a mark outside the cell does not count")
	check.call(_covered([Vector2(5.0, 5.0)], whole), "a mark in the cell covers it")
	check.call(_covered([Vector2(10.005, 5.0)], whole), "a mark on the cell's edge covers it")
	# The bay cuts the cell's north-east corner in three one-metre steps: three strips of dry
	# ground along the water, one stretch of shore with the cell's main body.
	var steps: Array[Rect2] = [
		Rect2(3.0, 0.0, 7.0, 1.0), Rect2(5.0, 1.0, 5.0, 1.0), Rect2(7.0, 2.0, 3.0, 1.0)
	]
	var shore := GroundKit.cut(whole, steps)
	check.call(shore.size() > 2, "the stepped bay leaves the cell in strips (%d)" % shore.size())
	check.call(_regions(shore).size() == 1, "the strips touch: one stretch of shore")
	check.call(not _covered([], shore), "a planted bare shore stretch (no mark) is bare")
	check.call(
		not _covered([Vector2(8.0, 0.5)], shore), "a mark in the bay's water does not cover it"
	)
	check.call(
		_covered([Vector2(1.0, 9.0)], shore),
		"one mark on the shore covers the stretch, strips and all"
	)
	check.call(
		_covered([Vector2(2.0, 0.5)], shore), "a mark on one thin strip covers the stretch too"
	)
	# A band right across the cell: two separate dry parts, each needs its own mark.
	var band: Array[Rect2] = [Rect2(4.0, 0.0, 2.0, 10.0)]
	var apart := GroundKit.cut(whole, band)
	check.call(_regions(apart).size() == 2, "a band across the cell leaves two separate parts")
	check.call(
		not _covered([Vector2(1.0, 5.0)], apart),
		"a mark on one part leaves the part cut off from it bare"
	)
	check.call(
		_covered([Vector2(1.0, 5.0), Vector2(9.0, 5.0)], apart), "a mark on each part covers both"
	)
