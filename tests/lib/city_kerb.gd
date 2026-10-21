extends RefCounted
## Cars stand on the street, never on a pavement (senior dev review of #115: a landmark plaza
## now runs to the kerb, and its pavement grown over the sidewalk put 22-32 parked cars on it):
## no car's footprint reaches into any block's drawn pavement (CityGen.pavement), its lot or a
## building; and a plaza's pavement is its own rect, no wider.

const WALK_STEP := 0.5  # a pavement line is sampled this often when looking for buildings
const WALK_SLACK := 0.05  # a node this close to the kerb line still counts as on the pavement


static func check(
	tier: int, map_seed: int, sim: RampageSim, decor: Node, check_fn: Callable
) -> void:
	var plan := CityGen.map(sim.city)
	var cars: Array = decor.get("cars") if decor.get("cars") is Array else []
	var on_pavement := 0
	var plaza_wider := 0
	for block: Dictionary in plan["blocks"]:
		if str(block["use"]) == "river":
			continue
		var walk := CityGen.pavement(block, sim.city)
		var rect: Rect2 = block["rect"]
		if block.has("site") and walk != rect:
			plaza_wider += 1
		var inner := walk.grow(-0.01)
		for car: Rect2 in cars:
			if car.intersects(inner):
				on_pavement += 1
	check_fn.call(
		not cars.is_empty() and on_pavement == 0 and plaza_wider == 0,
		(
			(
				"stage %d, map_seed %d: every car stands on the street (%d of %d on a pavement;"
				+ " %d plazas drawn past their kerb)"
			)
			% [tier, map_seed, on_pavement, cars.size(), plaza_wider]
		)
	)


## People walk the pavement, never the road: no walker ring node lies inside a street's
## carriageway (the rectangle from crossing to crossing, half its width either side of the centre
## line, less a little slack). Alleys have no pavement and carry people, so they are left out;
## the diagonal avenue is not (it runs through the blocks it crosses).
static func check_walkers(
	tier: int, map_seed: int, sim: RampageSim, street: StreetLife, check_fn: Callable
) -> void:
	var plan := CityGen.map(sim.city)
	var points: Array[Vector2] = plan["nodes"]
	var nodes := street.ring_nodes()
	var in_road := 0
	var first := ""
	for n: int in nodes.size():
		for road: Dictionary in plan["streets"]:
			if str(road["kind"]) == CityGen.ALLEY:
				continue
			var a: Vector2 = points[Num.i(road["from"])]
			var b: Vector2 = points[Num.i(road["to"])]
			var along := (nodes[n] - a).dot((b - a).normalized())
			var across := absf((nodes[n] - a).cross((b - a).normalized()))
			if along > 0.0 and along < a.distance_to(b):
				if across < Num.f(road["width"]) * 0.5 - WALK_SLACK:
					in_road += 1
					if first.is_empty():
						first = "node %d at %s on a %s" % [n, nodes[n], road["kind"]]
					break
	check_fn.call(
		not nodes.is_empty() and in_road == 0,
		(
			"stage %d, map_seed %d: no walker node lies in a carriageway (%d of %d do; first: %s)"
			% [tier, map_seed, in_road, nodes.size(), first]
		)
	)
