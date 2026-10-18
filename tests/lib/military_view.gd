extends "res://tests/lib/military_base.gd"
## The military suite's game-view check (D-066 r4): the clip's scene (tools/capture/
## capture_military.gd: a Behemoth at its crossing, columns calling in close) runs as the game
## runs it, measured every sim step through the drawn models: no two tanks' drawn parts (hull,
## turret, gun, from the voxels through the models' own transforms) ever touch, and no driving
## hull lies more than DRIVE_DEG off its road; mid-clip the kaiju strides at the tanks and none
## comes within the danger radius of its head (the snout, BreathCone: they fall back), and no
## tank's hull meets a car still on its wheels (cars keep out of the tanks' way). Prints the
## probe table (a VIEW line) for the PR.

const Clip := preload("res://tools/capture/capture_military.gd")
const VIEW_SECONDS := 18.0
const CAR_HALF := Vector2(1.0, 0.5)  # a car as drawn, half length x half width (m)

var _shapes := {}  # tank part -> its footprint (_tank_shapes)


## The clip's scene through the drawn models; prints the probe line and checks the bars.
func _check_view() -> void:
	root.size = Vector2i(1920, 1080)
	_shapes = _tank_shapes()
	var got := await _view_run()
	var head := (
		", closest to the kaiju's head %.1f m (to its origin %.1f, danger %.1f), tank on a car %d"
		% [got["head"], got["closest"], got["danger"], got["on_car"]]
	)
	print(
		(
			(
				(
					"\nVIEW Behemoth clip: tank drawn gap min %.2f m, touching %d pair-steps, yaw while"
					+ " moving max %.1f deg (%d tank-steps)"
				)
				% [got["gap"], got["touching"], got["yaw"], got["moving"]]
			)
			+ head
			+ " tank-steps"
		)
	)
	check(
		Num.i(got["touching"]) == 0 and Num.f(got["gap"]) < INF and Num.f(got["yaw"]) <= DRIVE_DEG,
		(
			"in the game view no two tanks' drawn parts touch (%d) and none drives skewed (%.1f deg)"
			% [got["touching"], got["yaw"]]
		)
	)
	check(
		Num.f(got["head"]) >= Num.f(got["danger"]) - 0.5 and Num.i(got["on_car"]) == 0,
		(
			(
				"in the game view the kaiju strides at the tanks and they fall back: none comes"
				+ " within danger of its head, the snout (closest %.1f m, danger %.1f m); no tank's"
				+ " hull meets a car (%d tank-steps)"
			)
			% [got["head"], got["danger"], got["on_car"]]
		)
	)


## The clip's run, measured every sim step: {gap, touching, yaw, moving}.
func _view_run() -> Dictionary:
	var rampage := _view_scene()
	root.add_child(rampage)
	await physics_frame
	_clip_overrides(rampage.sim)
	var roads := _roads(rampage.sim)
	var got := {"gap": INF, "touching": 0, "yaw": 0.0, "moving": 0, "closest": INF, "on_car": 0}
	got["head"] = INF
	got["danger"] = rampage.sim.army_units.convoy.danger()
	var last := {}
	for i: int in roundi(VIEW_SECONDS * 60.0):
		var frame := i
		rampage.scripted = func(_s: RampageSim) -> Dictionary: return {"move": Clip.walk(frame)}
		await physics_frame
		rampage.sim.facing = Vector2(1, 0)
		if i % 4 == 0:  # every sim step's worth (sim steps at 15 Hz)
			_measure_tanks(rampage, roads, last, got)
			_measure_cars(rampage, got)
	rampage.queue_free()
	await process_frame
	return got


## The tanks this frame: their drawn parts' closest approach and the hull's yaw while moving.
func _measure_tanks(rampage: Rampage, roads: Dictionary, last: Dictionary, got: Dictionary) -> void:
	var sim := rampage.sim
	var parts := {}
	for tank: RampageSim.Tank in sim.tanks:
		var was: Vector2 = last.get(tank.id, tank.pos)
		var front := sim.army_units.convoy.front(tank.id)
		if tank.pos.distance_to(was) > 0.0005 and front != Vector2.ZERO:
			got["yaw"] = maxf(Num.f(got["yaw"]), _yaw_off_road(tank.pos, front, roads))
			got["moving"] = Num.i(got["moving"]) + 1
		last[tank.id] = tank.pos
		if rampage._tank_nodes.has(tank.id):
			var node: TankModel = rampage._tank_nodes[tank.id]
			parts[tank.id] = _tank_drawn(node, _shapes)
	var ids := parts.keys()
	var at := {}
	for tank: RampageSim.Tank in sim.tanks:
		at[tank.id] = tank.pos
	for a: int in ids.size():
		for b: int in range(a + 1, ids.size()):
			var pa: Vector2 = at[ids[a]]
			var pb: Vector2 = at[ids[b]]
			if pa.distance_to(pb) > 14.0:  # two tanks' full reach apart and more
				continue
			var one: Array[PackedVector2Array] = parts[ids[a]]
			var two: Array[PackedVector2Array] = parts[ids[b]]
			var g := _parts_gap(one, two)
			got["gap"] = minf(Num.f(got["gap"]), g)
			got["touching"] = Num.i(got["touching"]) + (1 if g <= 0.0 else 0)


## How near the kaiju the tanks come, and any tank hull over a car still on its wheels.
func _measure_cars(rampage: Rampage, got: Dictionary) -> void:
	var sim := rampage.sim
	var street := rampage._city.street
	for tank: RampageSim.Tank in sim.tanks:
		got["closest"] = minf(Num.f(got["closest"]), tank.pos.distance_to(sim.kaiju_pos))
		var snout: Vector2 = BreathCone.of(sim)["origin"]
		got["head"] = minf(Num.f(got["head"]), tank.pos.distance_to(snout))
		var u := sim.army_units.convoy.front(tank.id)
		if street == null or u == Vector2.ZERO:
			continue
		var half := Vector2(HULL_LENGTH * 0.5, HULL_HALF_WIDTH)
		for car: Traffic.Car in street.traffic.cars:
			var d := car.pos - tank.pos
			var lx := absf(d.dot(u)) - half.x - CAR_HALF.x
			var ly := absf(d.dot(u.orthogonal())) - half.y - CAR_HALF.y
			if not car.crushed and maxf(lx, ly) <= 0.0:
				got["on_car"] = Num.i(got["on_car"]) + 1


## The hull's angle off the road it stands on (the least of them at a crossing).
func _yaw_off_road(p: Vector2, front: Vector2, roads: Dictionary) -> float:
	var best := 90.0
	for road: Array in roads.get(_cell4(p), []):
		var a: Vector2 = road[0]
		var b: Vector2 = road[1]
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		if q.distance_to(p) <= Num.f(road[2]) + 0.05:
			var tilt := absf(front.cross((b - a).normalized()))
			best = minf(best, rad_to_deg(asin(clampf(tilt, 0.0, 1.0))))
	return best


## The game's rampage scene for the clip: a Behemoth reptilian that cannot fall, standing at the
## capture's crossing.
func _view_scene() -> Rampage:
	var species := Content.species_def("reptilian")
	var levels := {"claws": 1, "evolve1": 1}
	var tree := UpgradeTree.new(Content.upgrades(), levels, "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	stats["hp"] = 100000.0
	var tier := Num.i(stats["size"])
	var rampage := Rampage.new()
	var layout := CityGrowth.layout(Content.tuning(), tier, Seeds.make("city", 0))
	rampage.setup(species, stats, layout, 1)
	rampage.sim.kaiju_pos = Clip.CLIP_AT
	rampage.scripted = func(_s: RampageSim) -> Dictionary: return {"move": Vector2.ZERO}
	return rampage


## The capture's overrides (capture_military._run), so it all happens in sight inside 18 s.
func _clip_overrides(sim: RampageSim) -> void:
	sim.army["spawn_radius"] = 44.0
	sim.army["start_interval"] = 1.6
	sim.army_units._spawn_timer = 0.3


## Each tank part's footprint on the ground (its voxels' convex hull), in the part's space.
func _tank_shapes() -> Dictionary:
	var height := Num.f(Content.section("vehicles")["tank_height"])
	var parts := VehicleParts.new(TankModel.BASE, height)
	var centre := parts.pivot("hull") * Vector3(1, 0, 1)
	var out := {}
	for part: String in ["hull", "turret", "barrel"]:
		var origin := -centre if part == "hull" else -parts.pivot(part)
		var points := PackedVector2Array()
		for cell: Vector3i in parts._read(part).frames[0].cells:
			for corner: int in 4:
				var at := Vector3(cell.x + (corner & 1), 0, cell.z + (corner >> 1))
				var v := origin + at * parts.voxel
				points.append(Vector2(v.x, v.z))
		out[part] = Geometry2D.convex_hull(points)
	return out


## A tank's parts as drawn now: hull, turret and gun footprints in the world.
func _tank_drawn(node: TankModel, shapes: Dictionary) -> Array[PackedVector2Array]:
	var xf: Array[Transform3D] = [
		node.global_transform, node._turret.global_transform, node._barrel.global_transform
	]
	var out: Array[PackedVector2Array] = []
	var k := 0
	for part: String in ["hull", "turret", "barrel"]:
		var poly := PackedVector2Array()
		var shape: PackedVector2Array = shapes[part]
		for p: Vector2 in shape:
			var w := xf[k] * Vector3(p.x, 0, p.y)
			poly.append(Vector2(w.x, w.z))
		out.append(poly)
		k += 1
	return out


## The closest any part of one tank comes to any part of the other (0 when they touch).
static func _parts_gap(a: Array[PackedVector2Array], b: Array[PackedVector2Array]) -> float:
	var best := INF
	for pa: PackedVector2Array in a:
		for pb: PackedVector2Array in b:
			if not Geometry2D.intersect_polygons(pa, pb).is_empty():
				return 0.0
			for i: int in pa.size():
				for j: int in pb.size():
					var e := pb[(j + 1) % pb.size()]
					var f := pa[(i + 1) % pa.size()]
					var q := Geometry2D.get_closest_point_to_segment(pa[i], pb[j], e)
					var r := Geometry2D.get_closest_point_to_segment(pb[j], pa[i], f)
					best = minf(best, minf(q.distance_to(pa[i]), r.distance_to(pb[j])))
	return best
