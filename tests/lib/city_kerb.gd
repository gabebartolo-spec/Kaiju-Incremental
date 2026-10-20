extends RefCounted
## Cars stand on the street, never on a pavement (senior dev review of #115: a landmark plaza
## now runs to the kerb, and its pavement grown over the sidewalk put 22-32 parked cars on it):
## no car's footprint reaches into any block's drawn pavement (CityGen.pavement), its lot or a
## building; and a plaza's pavement is its own rect, no wider.


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
