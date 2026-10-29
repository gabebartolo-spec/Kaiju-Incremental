extends "res://tests/lib/runner.gd"
## Shared scene-building for the military suite (run_military_tests): autoplayed rampages on
## generated cities built the way the game builds them, the plan's roads and the building
## footprints by grid cell, and the test's own hull-overlap check (independent of Convoy).

const DT := 1.0 / 15.0
const SEEDS: Array[int] = [0, 1, 2]
const LEVELS := {1: {}, 2: {"evolve1": 1}, 3: {"evolve1": 1, "evolve2": 1}}
## Half the tank hull's width and its length: the footprint and spacing the checks hold the tanks
## to, about the sim's convoy footprint (data army.convoy hull 5.0 x 2.5). The drawn tank (Tripo,
## assets/vehicles/tank: hull 3.96 x 1.98 m) sits inside it, so a pass here is conservative.
const HULL_HALF_WIDTH := 1.2
const HULL_LENGTH := 5.0
## How far a standing tank's hull may lie off its road's axis.
const ALIGN_DEG := 15.0
## A driving tank's hull off its road's axis, at most (D-066 r4: it turns standing, then drives).
const DRIVE_DEG := 10.0
## The turret and gun boxes the checks hold the tanks to, both turned to the kaiju: about the sim's
## convoy footprint (data army.convoy turret 3.0 x 2.3, gun 3.6 x 0.6), a little over the drawn
## tank's (assets/vehicles/tank: turret 2.72 x 1.98 m; the gun reaches 3.0 m from the turret ring
## and is 0.25 m across).
const TURRET_HALF := Vector2(1.55, 1.12)
const GUN_REACH := 3.54
const GUN_HALF_WIDTH := 0.37


## A reptilian rampage at size tier `tier` on city seed `seed`, built the way the game does.
func _rampage(tier: int, seed: int) -> RampageSim:
	var species := Content.species_def("reptilian")
	var levels: Dictionary = LEVELS[tier]
	var tree := UpgradeTree.new(Content.upgrades(), levels, "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	stats["hp"] = 1000000.0  # the kaiju must not fall: these checks watch the army to the clock
	var tuning := CityGrowth.tuning_for(Content.tuning(), tier)
	var layout := CityGrowth.layout(Content.tuning(), tier, Seeds.make("city", seed))
	var sim := RampageSim.new(stats, tuning, layout, Seeds.make("army", seed))
	sim.collapse.cut_only()  # the army as fitted, not where b2-5's mix drops the blocks
	var ability: Dictionary = species["ability"]
	sim.ability_type = str(ability["type"])
	return sim


## The plan's roads tanks may use (every avenue, street and diagonal, never an alley), by 4 m
## cell: [a, b, half width] each.
func _roads(sim: RampageSim) -> Dictionary:
	var plan := CityGen.map(sim.city)
	var nodes: Array = plan["nodes"]
	var grid := {}
	for street: Dictionary in plan["streets"]:
		if str(street["kind"]) == CityGen.ALLEY:
			continue
		var a: Vector2 = nodes[Num.i(street["from"])]
		var b: Vector2 = nodes[Num.i(street["to"])]
		var road := [a, b, Num.f(street["width"]) * 0.5]
		var steps := ceili(a.distance_to(b) / 2.0) + 1
		var seen := {}
		for k: int in steps + 1:
			var key := _cell4(a.lerp(b, float(k) / steps))
			for dx: int in [-1, 0, 1]:
				for dz: int in [-1, 0, 1]:
					var near := key + Vector2i(dx, dz)
					if seen.has(near):
						continue
					seen[near] = true
					if not grid.has(near):
						grid[near] = []
					var list: Array = grid[near]
					list.append(road)
	return grid


static func _cell4(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / 4.0), floori(p.y / 4.0))


func _on_road(p: Vector2, roads: Dictionary) -> bool:
	for road: Array in roads.get(_cell4(p), []):
		var a: Vector2 = road[0]
		var b: Vector2 = road[1]
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		if q.distance_to(p) <= Num.f(road[2]) + 0.05:
			return true
	return false


## Building footprints by 4 m cell, for the footprint check.
func _footprints(sim: RampageSim) -> Dictionary:
	var grid := {}
	for b: RampageSim.Building in sim.lot_buildings():  # tanks drive on under the viaduct
		var rect := Rect2(b.x - b.w * 0.5, b.z - b.d * 0.5, b.w, b.d)
		for cx: int in range(floori(rect.position.x / 4.0), floori(rect.end.x / 4.0) + 1):
			for cz: int in range(floori(rect.position.y / 4.0), floori(rect.end.y / 4.0) + 1):
				var key := Vector2i(cx, cz)
				if not grid.has(key):
					grid[key] = []
				var list: Array = grid[key]
				list.append(rect)
	return grid


## Does a hull at p pointing along `front` lie along a road it stands on (within `deg`)?
func _along_road(p: Vector2, front: Vector2, roads: Dictionary, deg := ALIGN_DEG) -> bool:
	for road: Array in roads.get(_cell4(p), []):
		var a: Vector2 = road[0]
		var b: Vector2 = road[1]
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		if q.distance_to(p) <= Num.f(road[2]) + 0.05:
			if absf(front.cross((b - a).normalized())) <= sin(deg_to_rad(deg)):
				return true
	return false


## Does the tank hull as drawn (HULL_LENGTH long, front along `front`) at p overlap any building
## footprint? The test's own separating axes (independent of RoadGraph's), corners and all.
func _hull_in_building(p: Vector2, front: Vector2, grid: Dictionary) -> bool:
	var half := Vector2(HULL_LENGTH * 0.5, HULL_HALF_WIDTH)
	var side := front.orthogonal()
	var ext := absf(front.x) * half.x + absf(side.x) * half.y
	var ezt := absf(front.y) * half.x + absf(side.y) * half.y
	var seen := {}
	for cx: int in range(floori((p.x - ext) / 4.0), floori((p.x + ext) / 4.0) + 1):
		for cz: int in range(floori((p.y - ezt) / 4.0), floori((p.y + ezt) / 4.0) + 1):
			for rect: Rect2 in grid.get(Vector2i(cx, cz), []):
				if seen.has(rect):
					continue
				seen[rect] = true
				var d := rect.get_center() - p
				var hb := rect.size * 0.5
				if absf(d.x) >= ext + hb.x or absf(d.y) >= ezt + hb.y:
					continue
				var rf := hb.x * absf(front.x) + hb.y * absf(front.y)
				var rs := hb.x * absf(side.x) + hb.y * absf(side.y)
				if absf(d.dot(front)) < half.x + rf and absf(d.dot(side)) < half.y + rs:
					return true
	return false


## Do two tanks as drawn touch: hull, turret and gun of each (turrets on `kaiju`)? The test's
## own boxes from the measured model, independent of TankSpacing's.
static func _tanks_touch(p: Vector2, u: Vector2, q: Vector2, w: Vector2, kaiju: Vector2) -> bool:
	var a := _drawn(p, u, kaiju)
	var b := _drawn(q, w, kaiju)
	for i: int in range(0, a.size(), 3):
		for j: int in range(0, b.size(), 3):
			if _boxes_touch(a[i], a[i + 1], a[i + 2], b[j], b[j + 1], b[j + 2]):
				return true
	return false


## Centre, long axis and half extents of the hull, the turret and the gun at p.
static func _drawn(p: Vector2, front: Vector2, kaiju: Vector2) -> PackedVector2Array:
	var aim := (kaiju - p).normalized()
	var hull := Vector2(HULL_LENGTH * 0.5, HULL_HALF_WIDTH)
	var gun := Vector2(GUN_REACH * 0.5, GUN_HALF_WIDTH)
	return PackedVector2Array(
		[p, front, hull, p, aim, TURRET_HALF, p + aim * GUN_REACH * 0.5, aim, gun]
	)


## The test's own separating-axis check (independent of TankSpacing's): boxes at p and q, long
## axes u and w, half extents ha and hb.
static func _boxes_touch(
	p: Vector2, u: Vector2, ha: Vector2, q: Vector2, w: Vector2, hb: Vector2
) -> bool:
	var d := q - p
	for axis: Vector2 in [u, u.orthogonal(), w, w.orthogonal()] as Array[Vector2]:
		var ra := ha.x * absf(u.dot(axis)) + ha.y * absf(u.orthogonal().dot(axis))
		var rb := hb.x * absf(w.dot(axis)) + hb.y * absf(w.orthogonal().dot(axis))
		if absf(d.dot(axis)) > ra + rb:
			return false
	return true


## The tanks' reach as the sim has it (Convoy.reach: never so short the firing band ends inside
## the body's keep-away).
func _reach(sim: RampageSim) -> float:
	return sim.army_units.convoy.reach()


func _danger(sim: RampageSim) -> float:
	var convoy: Dictionary = sim.army.get("convoy", {})
	return _reach(sim) * Num.f(convoy.get("danger", 0.55))


## The scripted player of tools/pacing.gd: walk to the nearest standing building, signature and
## ultimate when ready.
func _autoplay(sim: RampageSim, steps: int, target: Vector2) -> Vector2:
	if steps % 8 == 0:
		target = sim.nearest_standing(sim.kaiju_pos)
	var move := Vector2.ZERO
	if target.x < INF and not sim.body.stomp_reaches(target):
		move = (target - sim.kaiju_pos).normalized()
	var held := RampageSim.HELD if steps % 30 < 15 else 0
	sim.step(DT, move, sim.ability_ready_in <= 0.0, held | RampageSim.ULTIMATE)
	return target
