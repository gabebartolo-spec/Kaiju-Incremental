class_name CityPlaza
extends RefCounted
## The plaza where two diagonal avenues meet (Carthago, D-435; part of CityGen.map, split out to
## keep files small). With city.diagonal_count 2 and city.diagonal_plaza (metres) above 0, the
## grid cells round the diagonals' crossing out to that reach become one open site: the streets
## inside it are never laid (CitySites.cuts), so both diagonals end at its kerb and traffic goes
## round it, and its block is a "plaza". No inner avenue is drawn through it (CityLines) and a
## landmark site that overlaps it is dropped. Pure: the same city config always gives the same
## plaza.


## Adds the plaza site to plan["sites"] (after CitySites.find). avenues: [along x, along z],
## each {line index: true}.
static func add(plan: Dictionary, avenues: Array, cfg: Dictionary) -> void:
	var diags: Array[Dictionary] = plan["diagonals"]
	var reach := Num.f(cfg["diagonal_plaza"])
	if diags.size() < 2 or reach <= 0.0:
		return
	var at: Vector2 = diags[0]["at"]
	var xs: Array[float] = plan["xs"]
	var zs: Array[float] = plan["zs"]
	var i := _span(xs, at.x, reach)
	var j := _span(zs, at.y, reach)
	if i.x < 0 or j.x < 0:
		return
	var outer := Rect2(xs[i.x], zs[j.x], xs[i.y + 1] - xs[i.x], zs[j.y + 1] - zs[j.x])
	var av_x: Dictionary = avenues[0]
	var av_z: Dictionary = avenues[1]
	var x0 := xs[i.x] + _inset(av_x, i.x, cfg)
	var z0 := zs[j.x] + _inset(av_z, j.x, cfg)
	var x1 := xs[i.y + 1] - _inset(av_x, i.y + 1, cfg)
	var z1 := zs[j.y + 1] - _inset(av_z, j.y + 1, cfg)
	var rect := Rect2(x0, z0, x1 - x0, z1 - z0)
	var kept: Array[Dictionary] = []
	for site: Dictionary in plan["sites"]:
		var other: Rect2 = site["outer"]
		if not other.grow(-0.01).intersects(outer):
			kept.append(site)
	kept.append(_site(i, j, outer, rect, cfg))
	plan["sites"] = kept


## The plaza's site: grid spans i and j, its outer edge and its kerbed rect.
static func _site(
	i: Vector2i, j: Vector2i, outer: Rect2, rect: Rect2, cfg: Dictionary
) -> Dictionary:
	return {
		"id": "plaza",
		"plaza": true,
		"spec": {"id": "plaza"},
		"shape": {},
		"i": i,
		"j": j,
		"outer": outer,
		"rect": rect,
		"district": CityGen.district_of(rect, cfg),
	}


## True when street line k lies inside the plaza round centre (the diagonals' crossing on that
## axis): CityLines keeps the inner avenues off it.
static func swallows(lines: Array[float], k: int, centre: float, cfg: Dictionary) -> bool:
	if Num.i(cfg["diagonal_count"]) < 2:
		return false
	return absf(lines[k] - centre) < Num.f(cfg["diagonal_plaza"])


## The grid cells (first, last) the plaza takes along one axis: every line within reach of c
## lies inside it; with none, the one cell holding c. (-1, -1) when it would run off the grid.
static func _span(lines: Array[float], c: float, reach: float) -> Vector2i:
	var first := -1
	var last := -1
	for k: int in lines.size():
		if absf(lines[k] - c) < reach:
			if first < 0:
				first = k
			last = k
	if first < 0:
		for k: int in lines.size() - 1:
			if c >= lines[k] and c < lines[k + 1]:
				return Vector2i(k, k)
		return Vector2i(-1, -1)
	if first < 1 or last + 1 >= lines.size():
		return Vector2i(-1, -1)
	return Vector2i(first - 1, last)


## How far the plaza's edge sits in from street line k: half that street's (or avenue's) width.
static func _inset(avenues: Dictionary, k: int, cfg: Dictionary) -> float:
	var kind := CityGen.AVENUE if avenues.has(k) else CityGen.STREET
	return CityGen.width_of(kind, cfg) * 0.5
