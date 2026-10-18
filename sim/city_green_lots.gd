class_name CityGreenLots
extends RefCounted
## Green lots (D-075, director 2026-10-18: green lots at 8% of the city, answering D-065(b)):
## city.green_lot_share of the city's block area becomes parks, spread evenly so no building
## stands far from one. Part of CityGen.map, split out to keep files small.
##
## The choice reads only the street plan, never the stage's playable edge, so a block is green
## at every stage alike (an evolution never turns a park back into buildings). It starts from the
## block nearest the first tower district's heart (a Central Park) and keeps adding the block
## farthest from every green one so far until the share is met. No RNG: the same map_seed always
## greens the same blocks.


## Turns blocks green in `plan` (CityGen.map's): each keeps the use it had under "green" and
## becomes a "park", which the ground, the decor and the greenery already dress.
static func choose(plan: Dictionary, cfg: Dictionary) -> void:
	var share := Num.f(cfg.get("green_lot_share", 0.0))
	if share <= 0.0:
		return
	var blocks: Array[Dictionary] = plan["blocks"]
	var last := CityGen.districts(cfg).size()
	var thin := Num.f(cfg["depth_min"]) * 2.0  # too thin for back-to-back lots: not a block
	var picks: Array[int] = []
	var total := 0.0
	for n: int in blocks.size():
		var rect: Rect2 = blocks[n]["rect"]
		var use := str(blocks[n]["use"])
		if (use == "built" or use == "outer") and Num.i(blocks[n]["district"]) < last:
			if minf(rect.size.x, rect.size.y) >= thin:
				picks.append(n)
				total += rect.get_area()
	if picks.is_empty():
		return
	var heart := CityGen.cores(cfg)[0]
	var near := PackedFloat32Array()  # each candidate's distance to the nearest green block
	near.resize(picks.size())
	near.fill(INF)
	var next := _nearest(blocks, picks, Vector2(heart.x, heart.y))
	var green := 0.0
	while green < total * share:
		var block: Dictionary = blocks[picks[next]]
		var rect: Rect2 = block["rect"]
		block["green"] = block["use"]
		block["use"] = "park"
		green += rect.get_area()
		var far := -1.0
		for k: int in picks.size():
			var other: Rect2 = blocks[picks[k]]["rect"]
			near[k] = minf(near[k], other.get_center().distance_to(rect.get_center()))
			if near[k] > far:
				far = near[k]
				next = k
		if far <= 0.0:
			return  # every candidate is green


## The candidate (index into `picks`) whose block centre is nearest `at`.
static func _nearest(blocks: Array[Dictionary], picks: Array[int], at: Vector2) -> int:
	var best := 0
	var gap := INF
	for k: int in picks.size():
		var rect: Rect2 = blocks[picks[k]]["rect"]
		var d := rect.get_center().distance_to(at)
		if d < gap:
			gap = d
			best = k
	return best
