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
	var heart := CityGen.cores(cfg)[0]
	var quiet := Num.f(cfg["park_town"])
	var by_ring: Array = []
	for k: int in rings.size():
		by_ring.append([])
	var best_plaza := -1
	var plaza_away := INF
	for n: int in inner:
		if str(blocks[n]["use"]) != "built":
			continue  # the river (CityRiver)
		var rect: Rect2 = blocks[n]["rect"]
		var ring := Num.i(blocks[n]["district"])
		var edge := maxf(absf(rect.get_center().x), absf(rect.get_center().y)) / rings[ring]
		if edge < 0.75 or ring > 0:  # a later district is one ring of blocks deep
			var list: Array = by_ring[ring]
			list.append(n)
		var away := rect.get_center().distance_to(Vector2(heart.x, heart.y))
		if away < plaza_away:
			best_plaza = n
			plaza_away = away
	var parks: Array[int] = []
	for k: int in rings.size():
		var inside := rings[k - 1] if k > 0 else 0.0
		var ground := 4.0 * (rings[k] * rings[k] - inside * inside)
		var want := maxi(1, roundi(ground / Num.f(cfg["park_every"])))
		var list: Array = by_ring[k]
		# Quiet blocks first, then the biggest.
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
		for n: int in list:
			if mine.size() >= want:
				break
			var rect: Rect2 = blocks[n]["rect"]
			var spaced := true
			for at: Vector2 in mine:
				spaced = spaced and at.distance_to(rect.get_center()) >= Num.f(cfg["park_gap"])
			if spaced:
				mine.append(rect.get_center())
				parks.append(n)
	for n: int in parks:
		blocks[n]["use"] = "park"
	if best_plaza >= 0 and not best_plaza in parks and Num.f(cfg["plaza_blocks"]) > 0.0:
		blocks[best_plaza]["use"] = "plaza"


static func _town(block: Dictionary, cfg: Dictionary) -> float:
	var rect: Rect2 = block["rect"]
	return CityLots.town_share(rect.get_center(), cfg)
