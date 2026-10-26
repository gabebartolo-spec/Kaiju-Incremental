class_name CityAlleys
extends RefCounted
## Which grid edges of the street plan are alleys (part of CityGen.map, split out to keep files
## small). An alley carries no asphalt: the pavements of the blocks either side meet across it.
## So that every road meets other roads and pavements the way a real city's do (director
## 2026-10-26: "we need a system to ensure that roads are intersecting with other roads and
## pavements in a natural, realistic way"; his crop: the road off a river bridge running into a
## paved block and stopping), an alley never lies where a road must run on:
## - along the river's banks (CityRiver.river_row), so the far bank has one road the whole way and
##   every bridge lands on it (#12); nor across the river's row, where an alley would be a
##   footpath over open water with no deck (city audit D-265);
## - round a landmark's site, whose plaza is inset for a street on every side (CitySites);
## - where it would leave a road ending at a pavement (a dead end), or turning a corner whose
##   outside is a block's square pavement corner (an L): the alley that carries the road on is
##   laid as a street instead, until no such crossing is left.
## Pure: lines, sites and config in; the rolls are drawn whatever the rules say, so the plan does
## not shift when one changes.


## {x: Dictionary, z: Dictionary}: x-line i between zs[j] and zs[j+1] is an alley when
## x[Vector2i(i, j)]; z-line j between xs[i] and xs[i+1] when z[Vector2i(j, i)].
static func lay(
	rng: RandomNumberGenerator, plan: Dictionary, avenues: Array, cfg: Dictionary
) -> Dictionary:
	var xs: Array[float] = plan["xs"]
	var zs: Array[float] = plan["zs"]
	var av_x: Dictionary = avenues[0]
	var av_z: Dictionary = avenues[1]
	var full := CityGen.districts(cfg)[-1]
	var bank := CityRiver.river_row(zs, cfg)
	var ax := {}
	var az := {}
	for i: int in xs.size():
		for j: int in zs.size() - 1:
			var keep := (
				av_x.has(i)
				or j == bank  # across the river: a road with a bridge deck, never a footpath on water
				or _on_site(plan, Vector2(xs[i], zs[j]), Vector2(xs[i], zs[j + 1]))
			)
			if _ok(rng.randf(), [xs[i], zs[j], zs[j + 1]], full, keep, cfg):
				ax[Vector2i(i, j)] = true
	for j: int in zs.size():
		for i: int in xs.size() - 1:
			var keep: bool = (
				av_z.has(j)
				or (bank >= 0 and (j == bank or j == bank + 1))
				or _on_site(plan, Vector2(xs[i], zs[j]), Vector2(xs[i + 1], zs[j]))
			)
			if _ok(rng.randf(), [zs[j], xs[i], xs[i + 1]], full, keep, cfg):
				az[Vector2i(j, i)] = true
	var out := {"x": ax, "z": az}
	_settle(plan, out)
	return out


## An alley by its roll, inside the last district, off its ring lines, unless the line keeps
## its road (`keep`). line: [the line, one end, the other end].
static func _ok(roll: float, line: Array, full: float, keep: bool, cfg: Dictionary) -> bool:
	var at := Num.f(line[0])
	var ends := maxf(absf(Num.f(line[1])), absf(Num.f(line[2])))
	if keep or absf(at) >= full - 0.01 or ends > full + 0.01:
		return false
	return roll < Num.f(cfg["alley_chance"])


## True when the edge from a to b runs along a landmark site's edge.
static func _on_site(plan: Dictionary, a: Vector2, b: Vector2) -> bool:
	var mid := (a + b) * 0.5
	for site: Dictionary in plan.get("sites", []):
		var outer: Rect2 = site["outer"]
		if outer.grow(0.01).has_point(mid) and not outer.grow(-0.01).has_point(mid):
			return true
	return false


## Lays as streets the alleys that would leave a road ending (one road at a crossing) or turning
## an L (two at right angles): the one straight on from the road (for an L, the shorter of the two
## straight on), else for a dead end one across it. Repeats until every crossing is settled.
static func _settle(plan: Dictionary, alleys: Dictionary) -> void:
	var xs: Array[float] = plan["xs"]
	var zs: Array[float] = plan["zs"]
	var changed := true
	while changed:
		changed = false
		for i: int in xs.size():
			for j: int in zs.size():
				changed = _settle_node(plan, alleys, Vector2i(i, j)) or changed


static func _settle_node(plan: Dictionary, alleys: Dictionary, n: Vector2i) -> bool:
	var edges := _edges(plan, alleys, n)
	var road: Array[int] = []
	for k: int in 4:
		if not edges[k].is_empty() and not _is_alley(edges[k]):
			road.append(k)
	if road.size() == 1:
		var ahead := road[0] ^ 1  # north <-> south, west <-> east
		if _is_alley(edges[ahead]):
			return _lay_street(edges[ahead])
		return _lay_street(edges[(road[0] + 2) % 4]) or _lay_street(edges[(road[0] + 3) % 4])
	if road.size() == 2 and (road[0] >> 1) != (road[1] >> 1):  # an L
		var on: Array[Dictionary] = []
		for k: int in [road[0] ^ 1, road[1] ^ 1]:
			if _is_alley(edges[k]):
				on.append(edges[k])
		on.sort_custom(
			func(p: Dictionary, q: Dictionary) -> bool:
				return Num.f(p["length"]) < Num.f(q["length"])
		)
		return not on.is_empty() and _lay_street(on[0])
	return false


## The node's four edges, north, south, west, east: {alleys (that axis's dictionary), key,
## length}, or {} where no edge is laid (the grid's border, or inside a landmark's site).
static func _edges(plan: Dictionary, alleys: Dictionary, n: Vector2i) -> Array[Dictionary]:
	var xs: Array[float] = plan["xs"]
	var zs: Array[float] = plan["zs"]
	var out: Array[Dictionary] = []
	for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var m := n + d
		if m.x < 0 or m.y < 0 or m.x >= xs.size() or m.y >= zs.size():
			out.append({})
			continue
		var a := Vector2(xs[n.x], zs[n.y])
		var b := Vector2(xs[m.x], zs[m.y])
		if CitySites.cuts(plan, a, b):
			out.append({})
			continue
		var along_x := d.x == 0  # an x-line edge (running along z)
		var key := Vector2i(n.x, mini(n.y, m.y)) if along_x else Vector2i(n.y, mini(n.x, m.x))
		out.append(
			{"alleys": alleys["x" if along_x else "z"], "key": key, "length": a.distance_to(b)}
		)
	return out


static func _is_alley(edge: Dictionary) -> bool:
	if edge.is_empty():
		return false
	var alleys: Dictionary = edge["alleys"]
	return alleys.has(edge["key"])


static func _lay_street(edge: Dictionary) -> bool:
	if not _is_alley(edge):
		return false
	var alleys: Dictionary = edge["alleys"]
	alleys.erase(edge["key"])
	return true
