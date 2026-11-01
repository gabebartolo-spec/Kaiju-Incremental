class_name TrafficIsland
extends RefCounted
## Traffic islands where the diagonal meets avenues (director 2026-10-26, after the city audit,
## D-265, found none in any seed: "Where the diagonal meets avenues"): every crossing of the
## diagonal avenue with an avenue inside the playable city gets one small kerbed island with a
## signal pole and bollards, in the crossing's free wedge: along the bisector of a sharp corner
## between the two roads, the first spot (city.traffic_island.search_step apart, from node_clear
## out to wedge_reach) whose island keeps kerb_gap clear of every carriageway and prop_clear of
## every prop, on no building or parked car, never in the water; the nearer of the two sharp
## corners. Each part is its own prop that flattens under the kaiju like a lamp. The rule is
## city.traffic_island.at ("diagonal_avenue"; anything else plants none). Presentation only; no RNG.

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


## The island centres for decor's city: one per diagonal x avenue crossing with a free wedge.
## Each crossing searches only what lies within its wedge's reach (the whole city's buildings,
## cars, props and streets per spot took 0.9 s of the load); the spots are the same.
static func spots(decor: CityDecor) -> Array[Vector2]:
	var sim := decor.sim
	var city := sim.city
	var cfg: Dictionary = city["traffic_island"]
	var out: Array[Vector2] = []
	if str(cfg.get("at", "")) != "diagonal_avenue":
		return out
	var plan := decor.plan
	var half := CityGen.half_extent(city)
	var taken: Array[Rect2] = []
	for b: RampageSim.Building in sim.lot_buildings():
		taken.append(Rect2(b.x - b.w * 0.5, b.z - b.d * 0.5, b.w, b.d))
	taken.append_array(decor.cars)
	var props: Array[Vector2] = []
	for g: Dictionary in decor._props._groups:
		var at: Vector3 = g["at"]
		props.append(Vector2(at.x, at.z))
	var nodes: Array[Vector2] = plan["nodes"]
	var roads: Array[Array] = []  # [a, b, half width, box] each
	var touching := {}  # node -> its streets
	for st: Dictionary in plan["streets"]:
		var a := nodes[Num.i(st["from"])]
		var b := nodes[Num.i(st["to"])]
		var w := Num.f(st["width"]) * 0.5
		roads.append([a, b, w, Rect2(a, Vector2.ZERO).expand(b).grow(w)])
		for end: int in [Num.i(st["from"]), Num.i(st["to"])]:
			if not touching.has(end):
				touching[end] = []
			var list: Array = touching[end]
			list.append(st)
	var water := CityRiver.channels(plan, city)
	var foot := (Num.f(cfg["half_cells"]) + 0.5) * CityDecor.PROP_VOXEL
	var clear := maxf(Num.f(cfg["kerb_gap"]), Num.f(cfg["prop_clear"]))
	var reach := Num.f(cfg["wedge_reach"]) + foot + clear
	for n: int in nodes.size():
		var p := nodes[n]
		if maxf(absf(p.x), absf(p.y)) > half or not touching.has(n):
			continue
		var mine: Array = touching[n]
		var arms := _arms(nodes, mine, n)
		var diag: Array[Vector2] = arms[0]
		var avenue: Array[Vector2] = arms[1]
		if diag.is_empty() or avenue.is_empty():
			continue
		var area := Rect2(p, Vector2.ZERO).grow(reach)
		var world := {
			"taken": taken.filter(func(r: Rect2) -> bool: return r.intersects(area)),
			"props": props.filter(func(o: Vector2) -> bool: return area.grow(1.0).has_point(o)),
			"roads": roads.filter(func(r: Array) -> bool: return _box(r).intersects(area)),
			"water": water,
		}
		var best := Vector2.INF
		for d: Vector2 in diag:
			for a: Vector2 in avenue:
				if d.dot(a) <= 0.0:
					continue  # not a sharp corner
				var spot := _wedge_spot(p, (d + a).normalized(), world, cfg)
				if spot.distance_to(p) < best.distance_to(p):
					best = spot
		if best != Vector2.INF and maxf(absf(best.x), absf(best.y)) <= half:
			out.append(best)
	return out


## [diagonal arm directions, avenue arm directions] at node n (unit, away from it) of its streets.
static func _arms(nodes: Array[Vector2], streets: Array, n: int) -> Array:
	var diag: Array[Vector2] = []
	var avenue: Array[Vector2] = []
	for s: Dictionary in streets:
		var from := Num.i(s["from"])
		var to := Num.i(s["to"])
		var dir := (nodes[to if from == n else from] - nodes[n]).normalized()
		match str(s["kind"]):
			CityGen.DIAGONAL:
				diag.append(dir)
			CityGen.AVENUE:
				avenue.append(dir)
	return [diag, avenue]


## The first free spot from p along `dir` (INF none): clear of carriageways, props, buildings,
## parked cars and the water by the island's own half size plus the gaps in cfg.
static func _wedge_spot(p: Vector2, dir: Vector2, world: Dictionary, cfg: Dictionary) -> Vector2:
	var foot := (Num.f(cfg["half_cells"]) + 0.5) * CityDecor.PROP_VOXEL
	var step := Num.f(cfg["search_step"])
	var t := Num.f(cfg["node_clear"])
	var reach := Num.f(cfg["wedge_reach"])
	var water: Array[Rect2] = world["water"]
	var taken: Array = world["taken"]
	var roads: Array = world["roads"]
	var props: Array = world["props"]
	var gap := foot + Num.f(cfg["kerb_gap"])
	var apart := foot + Num.f(cfg["prop_clear"])
	while t <= reach:
		var q := p + dir * t
		t += step
		var box := Rect2(q, Vector2.ZERO).grow(foot)
		if _wet(q, water) or taken.any(func(r: Rect2) -> bool: return r.intersects(box)):
			continue
		if _near_road(q, roads, gap):
			continue
		if not props.any(func(o: Vector2) -> bool: return o.distance_to(q) < apart):
			return q
	return Vector2.INF


## Whether q lies within `gap` of any of `roads`' carriageways ([a, b, half width, box] each).
static func _near_road(q: Vector2, roads: Array, gap: float) -> bool:
	var box := Rect2(q, Vector2.ZERO).grow(gap)
	for r: Array in roads:
		if not _box(r).intersects(box):
			continue
		var a: Vector2 = r[0]
		var b: Vector2 = r[1]
		var w: float = r[2]
		if Geometry2D.get_closest_point_to_segment(q, a, b).distance_to(q) < w + gap:
			return true
	return false


static func _box(road: Array) -> Rect2:
	var box: Rect2 = road[3]
	return box


static func _wet(p: Vector2, water: Array[Rect2]) -> bool:
	for channel: Rect2 in water:
		if channel.has_point(p):
			return true
	return false


## A kerbed slab (half_cells either side of its middle), a signal pole (pole_cells, under a street
## lamp's height) and on its top a dark signal housing, 2 voxels wide, three lamps tall under a
## cap. Its two faces along x (the way the island's traffic mostly runs) carry the red, amber and
## green lamps: red lit (a glowing palette key), amber and green unlit. Bollards stand on the
## slab's corners as their own props (cells from 1 up, never shared).
static func _island(v: VoxelBuilder, cfg: Dictionary) -> void:
	var h := Num.i(cfg["half_cells"])
	var pole := Num.i(cfg["pole_cells"])
	v.box(Vector3i(-h, 0, -h), Vector3i(h, 0, h), "island_kerb")
	v.box(Vector3i(0, 1, 0), Vector3i(0, pole, 0), "pole")
	v.box(Vector3i(-1, pole + 1, 0), Vector3i(1, pole + 4, 1), "signal_housing")  # + a cap row
	var lamps: Array[String] = ["signal_green", "signal_amber", "signal_red"]
	for face: int in [-1, 1]:
		for row: int in lamps.size():
			v.box(Vector3i(face, pole + 1 + row, 0), Vector3i(face, pole + 1 + row, 1), lamps[row])


static func _bollard(v: VoxelBuilder, cfg: Dictionary) -> void:
	v.box(Vector3i(0, 1, 0), Vector3i(0, Num.i(cfg["bollard_cells"]), 0), "island_bollard")
