class_name TrafficIsland
extends RefCounted
## D-062 (no empty ground): a ground cell (city.coverage_cell, the no-empty-ground grid) that is
## all road junction, with no building, prop or car in it and no spot a parked car fits in
## (DiagonalParking.fits_in), gets a small kerbed traffic island with a signal pole and bollards,
## each its own prop that flattens under the kaiju like a lamp. The island stands where no lane
## runs: city.traffic_island.lane_clear from every driving lane's line (and the diagonal's
## parked rows), node_clear from every crossing, never in the water. Presentation only; no RNG.

## Off only to show the rule's need (tests/run_empty_space_tests.gd).
static var enabled := true


## Plants the islands into decor's props (after every other prop, so nothing else moves).
static func plant(decor: CityDecor) -> void:
	if not enabled:
		return
	var cfg: Dictionary = decor.sim.city["traffic_island"]
	var half := Num.i(cfg["half_cells"])
	var bollards: Array = cfg["bollards"]
	decor.islands = spots(decor)
	for at: Vector2 in decor.islands:
		var base := Vector3(at.x, 0, at.y)
		decor._props.add(base, func(v: VoxelBuilder) -> void: _island(v, cfg))
		for corner: Array in bollards:
			var off := Vector3(Num.f(corner[0]), 0, Num.f(corner[1])) * half * CityDecor.PROP_VOXEL
			decor._props.add(base + off, _bollard.bind(cfg))


## The island centres for decor's city: one per all-junction empty cell, the free spot nearest
## the cell's middle (none when no spot keeps clear of every lane).
static func spots(decor: CityDecor) -> Array[Vector2]:
	var sim := decor.sim
	var city := sim.city
	var cfg: Dictionary = city["traffic_island"]
	var plan := decor.plan
	var size := Num.f(city["coverage_cell"])
	var half := CityGen.half_extent(city)
	var full := {}
	for b: RampageSim.Building in sim.buildings:
		_mark_rect(sim, Rect2(b.x - b.w * 0.5, b.z - b.d * 0.5, b.w, b.d), full)
	for r: Rect2 in decor.cars:
		_mark_rect(sim, r, full)
	for g: Dictionary in decor._props._groups:
		var at: Vector3 = g["at"]
		full[DiagonalParking.cell_of(sim, Vector2(at.x, at.z))] = true
	var lo := DiagonalParking.cell_of(sim, -Vector2.ONE * half)
	var hi := DiagonalParking.cell_of(sim, Vector2.ONE * half)
	var n_cells := ceili((sim.arena_half + Num.f(city["view_beyond"])) * 2.0 / size)
	var origin := -Vector2.ONE * n_cells * size * 0.5  # as DiagonalParking.cell_of
	var water := CityRiver.channels(plan, city)
	var lanes := _lanes(plan, city, half)
	var out: Array[Vector2] = []
	for i: int in range(lo.x, hi.x + 1):
		for j: int in range(lo.y, hi.y + 1):
			var cell := Vector2i(i, j)
			if full.has(cell) or DiagonalParking.fits_in(sim, plan, cell):
				continue
			var box := Rect2(origin + Vector2(cell) * size, Vector2.ONE * size)
			var near := _near_streets(plan, box)
			if near.is_empty() or _wet(box.get_center(), water):
				continue  # no street, or the river (the no-empty-ground grid skips it too)
			if not _all_road(box, near, water):
				continue
			var best := Vector2.INF
			var step := Num.f(cfg["search_step"])
			var n := floori(size / step)
			for u: int in n:
				for w: int in n:
					var p := box.position + Vector2(u + 0.5, w + 0.5) * step
					if maxf(absf(p.x), absf(p.y)) > half or _wet(p, water):
						continue
					if not _clear(p, lanes, plan, cfg):
						continue
					if p.distance_to(box.get_center()) < best.distance_to(box.get_center()):
						best = p
			if best != Vector2.INF:
				out.append(best)
	return out


## Every line a car drives or parks on inside the playable city, as [a, b] segments: a street's
## centre (one-way), an avenue's or the diagonal's two lanes (Traffic.TWO_WAY_LANE either side),
## and the diagonal's parked rows (city.diagonal_parked_lane).
static func _lanes(plan: Dictionary, city: Dictionary, half: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var nodes: Array[Vector2] = plan["nodes"]
	for s: Dictionary in plan["streets"]:
		var kind := str(s["kind"])
		var a := nodes[Num.i(s["from"])]
		var b := nodes[Num.i(s["to"])]
		if kind == CityGen.ALLEY or maxf(absf(a.x), absf(a.y)) > half + 0.5:
			continue
		if maxf(absf(b.x), absf(b.y)) > half + 0.5:
			continue
		var offsets: Array[float] = [0.0]
		if kind != CityGen.STREET:
			offsets = [-Traffic.TWO_WAY_LANE, Traffic.TWO_WAY_LANE]
		if kind == CityGen.DIAGONAL:
			var parked := Num.f(city["diagonal_parked_lane"])
			offsets.append_array([-parked, parked])
		var side := (b - a).normalized().orthogonal()
		for o: float in offsets:
			out.append(PackedVector2Array([a + side * o, b + side * o]))
	return out


static func _clear(
	p: Vector2, lanes: Array[PackedVector2Array], plan: Dictionary, cfg: Dictionary
) -> bool:
	var lane_clear := Num.f(cfg["lane_clear"])
	for line: PackedVector2Array in lanes:
		var q := Geometry2D.get_closest_point_to_segment(p, line[0], line[1])
		if q.distance_to(p) < lane_clear:
			return false
	var node_clear := Num.f(cfg["node_clear"])
	for node: Vector2 in plan["nodes"]:
		if node.distance_to(p) < node_clear:
			return false
	return true


## The carriageways reaching into box: [a, b, half width] each.
static func _near_streets(plan: Dictionary, box: Rect2) -> Array[Array]:
	var out: Array[Array] = []
	var nodes: Array[Vector2] = plan["nodes"]
	for s: Dictionary in plan["streets"]:
		var a := nodes[Num.i(s["from"])]
		var b := nodes[Num.i(s["to"])]
		var w := Num.f(s["width"]) * 0.5
		if Rect2(a, Vector2.ZERO).expand(b).grow(w).intersects(box):
			out.append([a, b, w])
	return out


## Whether every point of box (sampled half a metre apart) lies on a carriageway or the water.
static func _all_road(box: Rect2, streets: Array[Array], water: Array[Rect2]) -> bool:
	var n := ceili(box.size.x / 0.5)
	for u: int in n:
		for w: int in n:
			var p := box.position + Vector2(u + 0.5, w + 0.5) * 0.5
			if not _wet(p, water) and not _on_road(p, streets):
				return false
	return true


static func _on_road(p: Vector2, streets: Array[Array]) -> bool:
	for s: Array in streets:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) <= Num.f(s[2]):
			return true
	return false


static func _wet(p: Vector2, water: Array[Rect2]) -> bool:
	for channel: Rect2 in water:
		if channel.has_point(p):
			return true
	return false


static func _mark_rect(sim: RampageSim, r: Rect2, into: Dictionary) -> void:
	var lo := DiagonalParking.cell_of(sim, r.position)
	var hi := DiagonalParking.cell_of(sim, r.end)
	for i: int in range(lo.x, hi.x + 1):
		for j: int in range(lo.y, hi.y + 1):
			into[Vector2i(i, j)] = true


## A kerbed slab (half_cells either side of its middle) with a signal pole and a three-lamp head.
## Bollards stand on its corners as their own props (cells from 1 up, never sharing one).
static func _island(v: VoxelBuilder, cfg: Dictionary) -> void:
	var h := Num.i(cfg["half_cells"])
	var pole := Num.i(cfg["pole_cells"])
	v.box(Vector3i(-h, 0, -h), Vector3i(h, 0, h), "island_kerb")
	v.box(Vector3i(0, 1, 0), Vector3i(0, pole, 0), "pole")
	v.put(Vector3i(0, pole + 1, 0), "signal_green")
	v.put(Vector3i(0, pole + 2, 0), "signal_amber")
	v.put(Vector3i(0, pole + 3, 0), "signal_red")


static func _bollard(v: VoxelBuilder, cfg: Dictionary) -> void:
	v.box(Vector3i(0, 1, 0), Vector3i(0, Num.i(cfg["bollard_cells"]), 0), "island_bollard")
