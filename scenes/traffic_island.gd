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
	var world := {"taken": taken, "props": props, "water": CityRiver.channels(plan, city)}
	var nodes: Array[Vector2] = plan["nodes"]
	for n: int in nodes.size():
		var p := nodes[n]
		if maxf(absf(p.x), absf(p.y)) > half:
			continue
		var arms := _arms(plan, n)
		var diag: Array[Vector2] = arms[0]
		var avenue: Array[Vector2] = arms[1]
		var best := Vector2.INF
		for d: Vector2 in diag:
			for a: Vector2 in avenue:
				if d.dot(a) <= 0.0:
					continue  # not a sharp corner
				var spot := _wedge_spot(plan, p, (d + a).normalized(), world, cfg)
				if spot.distance_to(p) < best.distance_to(p):
					best = spot
		if best != Vector2.INF and maxf(absf(best.x), absf(best.y)) <= half:
			out.append(best)
	return out


## [diagonal arm directions, avenue arm directions] at node n (unit, away from it).
static func _arms(plan: Dictionary, n: int) -> Array:
	var nodes: Array[Vector2] = plan["nodes"]
	var diag: Array[Vector2] = []
	var avenue: Array[Vector2] = []
	for s: Dictionary in plan["streets"]:
		var from := Num.i(s["from"])
		var to := Num.i(s["to"])
		if from != n and to != n:
			continue
		var dir := (nodes[to if from == n else from] - nodes[n]).normalized()
		match str(s["kind"]):
			CityGen.DIAGONAL:
				diag.append(dir)
			CityGen.AVENUE:
				avenue.append(dir)
	return [diag, avenue]


## The first free spot from p along `dir` (INF none): clear of carriageways, props, buildings,
## parked cars and the water by the island's own half size plus the gaps in cfg.
static func _wedge_spot(
	plan: Dictionary, p: Vector2, dir: Vector2, world: Dictionary, cfg: Dictionary
) -> Vector2:
	var foot := (Num.f(cfg["half_cells"]) + 0.5) * CityDecor.PROP_VOXEL
	var step := Num.f(cfg["search_step"])
	var t := Num.f(cfg["node_clear"])
	var reach := Num.f(cfg["wedge_reach"])
	while t <= reach:
		var q := p + dir * t
		t += step
		var box := Rect2(q, Vector2.ZERO).grow(foot)
		var water: Array[Rect2] = world["water"]
		var taken: Array[Rect2] = world["taken"]
		if _wet(q, water) or _hits(box, taken):
			continue
		if _near_road(q, plan, foot + Num.f(cfg["kerb_gap"])):
			continue
		var crowded := false
		var props: Array[Vector2] = world["props"]
		for o: Vector2 in props:
			crowded = crowded or o.distance_to(q) < foot + Num.f(cfg["prop_clear"])
		if not crowded:
			return q
	return Vector2.INF


static func _hits(box: Rect2, rects: Array[Rect2]) -> bool:
	for r: Rect2 in rects:
		if r.intersects(box):
			return true
	return false


## Whether q lies within `gap` of any street's carriageway.
static func _near_road(q: Vector2, plan: Dictionary, gap: float) -> bool:
	var near := _near_streets(plan, Rect2(q, Vector2.ZERO).grow(gap))
	for s: Array in near:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var w: float = s[2]
		if Geometry2D.get_closest_point_to_segment(q, a, b).distance_to(q) < w + gap:
			return true
	return false


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
