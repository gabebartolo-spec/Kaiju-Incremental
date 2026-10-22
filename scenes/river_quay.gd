class_name RiverQuay
extends RefCounted
## D-062 (no empty ground), the riverside: where a street runs along the river, water on one
## side, nothing parks at the kerb and no lamp stands there (the water's clearance), so a cell of
## it can hold nothing to smash. Quay crates stand along the water's edge on the street side,
## one stack every city.river_quay.gap metres across the whole river, and one at each end of
## every bridge deck so a crossing's own cell is never bare; none on a deck or a crossing.
## Crushable props like a lamp. Presentation only; no RNG.


## Off only so a test can show another rule's need without the riverside's crates
## (tests/lib/city_diag_fill.gd, tests/lib/junction_island.gd).
static var enabled := true


## Plants the crates into decor's props (before the traffic islands, so a riverside junction
## cell that holds a crate needs no island).
static func plant(decor: CityDecor) -> void:
	if not enabled:
		return
	var city := decor.sim.city
	var cfg: Dictionary = city["river_quay"]
	var plan := decor.plan
	var decks := CityRiver.bridges(plan, city)
	var gap := Num.f(cfg["gap"])
	var kerb := Num.f(cfg["kerb"])
	var deck_clear := Num.f(cfg["deck_clear"])
	for water: Rect2 in CityRiver.channels(plan, city):
		for z: float in [water.position.y - kerb, water.end.y + kerb]:
			var xs: Array[float] = []
			var x := ceilf(maxf(water.position.x, -decor._view) / gap) * gap
			while x <= minf(water.end.x, decor._view):
				xs.append(x)
				x += gap
			for deck: Rect2 in decks:
				xs.append(deck.position.x - deck_clear - 0.01)
				xs.append(deck.end.x + deck_clear + 0.01)
			for at_x: float in xs:
				var at := Vector2(at_x, z)
				if absf(at_x) <= decor._view and not _blocked(at, decks, plan, cfg):
					decor._props.add(Vector3(at.x, 0, at.y), _crates.bind(cfg))


static func _blocked(at: Vector2, decks: Array[Rect2], plan: Dictionary, cfg: Dictionary) -> bool:
	var deck_clear := Num.f(cfg["deck_clear"])
	for deck: Rect2 in decks:
		if deck.grow_individual(deck_clear, 0.0, deck_clear, 0.0).has_point(at):
			return true
	var nodes: Array[Vector2] = plan["nodes"]
	for node: Vector2 in nodes:
		if node.distance_to(at) < Num.f(cfg["node_clear"]):
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
