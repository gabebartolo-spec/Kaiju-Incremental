class_name CityParks
extends RefCounted
## The parks and the plaza of the street plan (part of CityGen.map, split out to keep files
## small). Each district gets a park for every city "park_every" m2 of its ground (at least one;
## D-065, D-075: a believable amount of green, so a district 1.5x wider keeps its share, D-254):
## its biggest blocks between the towers and its ring, quiet ones first (town share under
## "park_town"), each at least "park_gap" m from the district's other parks. One plaza: the
## block at the heart of the first tower district. Pure: the plan's blocks in, uses set.


## inner: CityGen.map's indices of every block inside the last district.
static func pick(plan: Dictionary, inner: Array[int], cfg: Dictionary) -> void:
	var blocks: Array[Dictionary] = plan["blocks"]
	var rings := CityGen.districts(cfg)
	var by_ring := _by_ring(blocks, inner, rings)
	var plaza := _plaza(blocks, inner, cfg)  # before any block turns to park
	var parks: Array[int] = []
	for k: int in rings.size():
		var inside := rings[k - 1] if k > 0 else 0.0
		var ground := 4.0 * (rings[k] * rings[k] - inside * inside)
		var want := maxi(1, roundi(ground / Num.f(cfg["park_every"])))
		var list: Array = by_ring[k]
		parks.append_array(_pick_ring(blocks, list, want, cfg))
	for n: int in parks:
		blocks[n]["use"] = "park"
	if plaza >= 0 and not plaza in parks and Num.f(cfg["plaza_blocks"]) > 0.0:
		blocks[plaza]["use"] = "plaza"


## The built blocks a district may turn to park, per district: the first district's away from
## its edge (its ring stays built), every later one's whole (a later district is one ring of
## blocks deep).
static func _by_ring(blocks: Array[Dictionary], inner: Array[int], rings: Array[float]) -> Array:
	var by_ring: Array = []
	for k: int in rings.size():
		by_ring.append([])
	for n: int in inner:
		if str(blocks[n]["use"]) != "built":
			continue  # the river (CityRiver)
		var rect: Rect2 = blocks[n]["rect"]
		var ring := Num.i(blocks[n]["district"])
		var edge := maxf(absf(rect.get_center().x), absf(rect.get_center().y)) / rings[ring]
		if edge < 0.75 or ring > 0:
			var list: Array = by_ring[ring]
			list.append(n)
	return by_ring


## Up to `want` of a district's candidate blocks: quiet ones first, then the biggest, each
## park_gap m from the ones already picked.
static func _pick_ring(
	blocks: Array[Dictionary], list: Array, want: int, cfg: Dictionary
) -> Array[int]:
	var quiet := Num.f(cfg["park_town"])
	list.sort_custom(
		func(a: int, b: int) -> bool:
			var qa := _town(blocks[a], cfg) < quiet
			var qb := _town(blocks[b], cfg) < quiet
			if qa != qb:
				return qa
			var ra: Rect2 = blocks[a]["rect"]
			var rb: Rect2 = blocks[b]["rect"]
			return ra.get_area() > rb.get_area()
	)
	var mine: Array[Vector2] = []
	var out: Array[int] = []
	for n: int in list:
		if out.size() >= want:
			break
		var rect: Rect2 = blocks[n]["rect"]
		var spaced := true
		for at: Vector2 in mine:
			spaced = spaced and at.distance_to(rect.get_center()) >= Num.f(cfg["park_gap"])
		if spaced:
			mine.append(rect.get_center())
			out.append(n)
	return out


## The built block nearest the heart of the first tower district (-1 when none).
static func _plaza(blocks: Array[Dictionary], inner: Array[int], cfg: Dictionary) -> int:
	var heart := CityGen.cores(cfg)[0]
	var best := -1
	var away := INF
	for n: int in inner:
		if str(blocks[n]["use"]) != "built":
			continue
		var rect: Rect2 = blocks[n]["rect"]
		var d := rect.get_center().distance_to(Vector2(heart.x, heart.y))
		if d < away:
			best = n
			away = d
	return best


static func _town(block: Dictionary, cfg: Dictionary) -> float:
	var rect: Rect2 = block["rect"]
	return CityLots.town_share(rect.get_center(), cfg)
