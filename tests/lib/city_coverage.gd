extends RefCounted
## D-062 (director 2026-10-18: "there should never be vast empty spaces with nothing to smash
## or kill"): splits the playfield, and the band past its edge the game camera shows, into
## square cells (city.coverage_cell) and finds the cells on or beside a street that hold
## nothing. Inside the arena a cell needs something to smash (a building, a parked or moving
## car, a prop, a person); in the band past it, where the kaiju never walks, a skyline
## stand-in building or a parked car will do (dense city, never bare asphalt).


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
			into[c] = true
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
	for p: StreetLife.Person in street.people:
		mark.call(p.pos, full)
	var dressed := {}  # the band only: stand-ins count there, never inside the arena
	for box: Dictionary in skyline._near:
		var at: Vector3 = box["at"]
		var sz: Vector3 = box["size"]
		cover.call(Rect2(at.x - sz.x * 0.5, at.z - sz.z * 0.5, sz.x, sz.z), dressed)
	var coast := Num.f(cfg["coast_z"])
	var empty: Array[Vector2] = []
	var lines: PackedStringArray = []
	var checked := 0
	var arena_empty := 0
	for j: int in n:
		var line := ""
		for i: int in n:
			var c := Vector2i(i, j)
			var centre := Vector2(origin + (i + 0.5) * size, origin + (j + 0.5) * size)
			if not road.has(c) or centre.y < coast:
				line += " "
				continue
			checked += 1
			var in_arena := maxf(absf(centre.x), absf(centre.y)) <= sim.arena_half
			if full.has(c) or (not in_arena and dressed.has(c)):
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
		"map": "
".join(lines),
	}
