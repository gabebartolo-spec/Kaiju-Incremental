class_name RiverQuay
extends RefCounted
## D-062 (no empty ground), the riverside: where a street runs along the river, water on one
## side, nothing parks at the kerb and no lamp stands there (the water's clearance), so a cell of
## it can hold nothing to smash. Quay crates stand along the water's edge on the street side, one
## stack every city.river_quay.gap metres across the whole river, skipping the bridge decks and
## the crossings: crushable props like a lamp. Presentation only; no RNG.


## Plants the crates into decor's props (before the traffic islands, so a riverside junction
## cell that holds a crate needs no island).
static func plant(decor: CityDecor) -> void:
	var city := decor.sim.city
	var cfg: Dictionary = city["river_quay"]
	var plan := decor.plan
	var decks := CityRiver.bridges(plan, city)
	var nodes: Array[Vector2] = plan["nodes"]
	var gap := Num.f(cfg["gap"])
	var kerb := Num.f(cfg["kerb"])
	var deck_clear := Num.f(cfg["deck_clear"])
	var node_clear := Num.f(cfg["node_clear"])
	for water: Rect2 in CityRiver.channels(plan, city):
		for z: float in [water.position.y - kerb, water.end.y + kerb]:
			var x := ceilf(maxf(water.position.x, -decor._view) / gap) * gap
			while x <= minf(water.end.x, decor._view):
				var at := Vector2(x, z)
				x += gap
				if _blocked(at, decks, nodes, deck_clear, node_clear):
					continue
				decor._props.add(Vector3(at.x, 0, at.y), _crates.bind(cfg))


static func _blocked(
	at: Vector2, decks: Array[Rect2], nodes: Array[Vector2], deck_clear: float, node_clear: float
) -> bool:
	for deck: Rect2 in decks:
		if deck.grow_individual(deck_clear, 0.0, deck_clear, 0.0).has_point(at):
			return true
	for node: Vector2 in nodes:
		if node.distance_to(at) < node_clear:
			return true
	return false


## Two stacked crates (the voxel sizes and colours are city.river_quay's).
static func _crates(v: VoxelBuilder, cfg: Dictionary) -> void:
	var low: Array = cfg["low"]
	var top: Array = cfg["top"]
	var lw := Num.i(low[0])
	var lh := Num.i(low[1])
	var tw := Num.i(top[0])
	var th := Num.i(top[1])
	v.box(Vector3i(-lw, 0, -lw), Vector3i(lw, lh, lw), "quay_crate")
	v.box(Vector3i(-tw, lh + 1, -tw), Vector3i(tw, lh + 1 + th, tw), "quay_band")
