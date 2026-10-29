extends "res://tests/lib/military_base.gd"
## The military suite's game-view check (D-066 r4): the clip's scene (tools/capture/
## capture_military.gd: a Behemoth at its crossing, columns calling in close) runs as the game
## runs it, measured every sim step through the drawn models: no two tanks' drawn parts (hull,
## turret, gun, from the voxels through the models' own transforms) ever touch, and no driving
## hull lies more than DRIVE_DEG off its road; mid-clip the kaiju strides at the tanks and none
## comes within EDGE_GAP of its body's edge (tail root to snout, body_radius wide), and no
## tank's hull meets a car still on its wheels (cars keep out of the tanks' way). Prints the
## probe table (a VIEW line) for the PR.

const Clip := preload("res://tools/capture/capture_military.gd")
const MilitaryCornered := preload("res://tests/lib/military_cornered.gd")
const VIEW_SECONDS := 18.0
## Standoff: a tank's hull (its nearest corner or side) this far from the kaiju's body edge
## (LEAD r6; r7: from the hull, not its centre).
const EDGE_GAP := 8.0
const CAR_HALF := Vector2(1.0, 0.5)  # a car as drawn, half length x half width (m)
## How fast a tank backs out from inside the danger line, at least and at most (m/s, LEAD r6:
## 3-4 m/s, never a creep that reads as stuck).
const RETREAT_PACE := Vector2(3.0, 4.0)
## The army seeds (the run index) the view runs: a fall-back is judged over all of them together.
## One seed is a coin toss at the 90% bar: swept over army seeds 1-20 (2026-10-25, D-166, with
## the stomp's damage centred on the foot and with it centred on kaiju_pos) the share of
## fall-back tank-steps at 3-4 m/s was 90.4% and 88.9% pooled (9 seeds see a fall-back, 271 and
## 270 tank-steps), and single seeds ran 80-100% either way (seed 1: 85% and 96%; seed 5: 80% and
## 0%): the foot-centred stomps break other buildings, the tanks turn the other way round a
## corner, and a pivot on the way counts as a slow step. The slow steps are the pivots, not a
## creep. These three read 96, 100 and 92% with the foot-centred stomp (96, 96 and 93% without),
## 115 tank-steps in all. Re-swept for road geometry (#243: bigger blocks), runs 1-20: 91.2%
## pooled (427 of 468 tank-steps, 15 runs see a fall-back); runs 3 and 11 now see 4 steps each,
## mostly pivots. Runs 5, 9 and 17 read 94, 98 and 95% (94 of 98). With the clip moved to the fixed
## front's city (#411) they read 87% (78 of 90). The wider city (#413) reads 83% (52 of 63, 86%
## pooled over runs 1-7): the bar is RETREAT_SHARE, tuning comes later (director 2026-10-30,
## "Lower to 80%").
const RETREAT_SHARE := 0.8
const VIEW_RUNS: Array[int] = [5, 9, 17]

var _shapes := {}  # tank part -> its footprint (_tank_shapes)


## The clip's scene through the drawn models; prints the probe line and checks the bars.
func _check_view() -> void:
	root.size = Vector2i(1920, 1080)
	_shapes = _tank_shapes()
	var got := await _view_runs()
	var head := (
		(
			", closest hull to the kaiju's body edge %.1f m (to its origin %.1f, danger %.1f), tank on a"
			% [got["edge"], got["closest"], got["danger"]]
		)
		+ " car %d" % got["on_car"]
		+ (
			", cornered (no road out) %d tank-steps, closest %.1f m"
			% [got["cornered"], got["cornered_edge"]]
		)
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
			+ (
				" tank-steps, falling back %.1f-%.1f m/s (%d tank-steps)"
				% [got["retreat_min"], got["retreat_max"], got["retreat_steps"]]
			)
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
		Num.f(got["edge"]) >= EDGE_GAP,
		(
			(
				"in the game view the kaiju strides at the tanks and they fall back: no hull with a"
				+ " road out comes within %.0f m of the edge of its body, snout to tail root"
				+ " (closest %.1f m); tanks may run cars over (director 2026-10-20), %d tank-steps"
			)
			% [EDGE_GAP, got["edge"], got["on_car"]]
		)
	)
	check(
		Num.i(got["cornered_closer"]) == 0,
		(
			(
				"a tank nearer the kaiju than %.0f m is only one with no road out (every way ends"
				+ " nearer its body): it holds and fires, never drives at it (%d tank-steps"
				+ " cornered, closest %.1f m; %d drove nearer)"
			)
			% [EDGE_GAP, got["cornered"], got["cornered_edge"], got["cornered_closer"]]
		)
	)
	var steps := Num.i(got["retreat_steps"])
	check(
		(
			steps >= 5
			and Num.i(got["retreat_ok"]) >= RETREAT_SHARE * steps
			and Num.f(got["retreat_max"]) <= RETREAT_PACE.y
		),
		(
			(
				"a tank falling back from inside the danger line moves out at %.0f-%.0f m/s, never"
				+ " a creep (%d of %d tank-steps, at least %.0f%%, a pivot on the way the rest;"
				+ " %.1f-%.1f m/s)"
			)
			% [
				RETREAT_PACE.x,
				RETREAT_PACE.y,
				got["retreat_ok"],
				steps,
				RETREAT_SHARE * 100.0,
				got["retreat_min"],
				got["retreat_max"]
			]
		)
	)


## The clip's run on each of VIEW_RUNS, the counts summed and the extremes kept.
func _view_runs() -> Dictionary:
	var all := {}
	for run: int in VIEW_RUNS:
		var got := await _view_run(run)
		if all.is_empty():
			all = got
			continue
		for key: String in ["touching", "moving", "on_car", "cornered", "cornered_closer"]:
			all[key] = Num.i(all[key]) + Num.i(got[key])
		for key: String in ["retreat_steps", "retreat_ok"]:
			all[key] = Num.i(all[key]) + Num.i(got[key])
		for key: String in ["gap", "closest", "edge", "cornered_edge", "retreat_min"]:
			all[key] = minf(Num.f(all[key]), Num.f(got[key]))
		for key: String in ["yaw", "retreat_max"]:
			all[key] = maxf(Num.f(all[key]), Num.f(got[key]))
	return all


## The clip's run on army seed `run`, measured every sim step: {gap, touching, yaw, moving}.
func _view_run(run: int) -> Dictionary:
	var rampage := _view_scene(run)
	root.add_child(rampage)
	await physics_frame
	_clip_overrides(rampage.sim)
	var roads := _roads(rampage.sim)
	var got := {"gap": INF, "touching": 0, "yaw": 0.0, "moving": 0, "closest": INF, "on_car": 0}
	got["edge"] = INF
	got.merge({"cornered": 0, "cornered_edge": INF, "cornered_closer": 0, "was_at": {}})
	got.merge({"retreat_steps": 0, "retreat_ok": 0, "retreat_min": INF, "retreat_max": 0.0})
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
		_measure_retreat(sim, tank, was, got)
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


## A tank falling back from inside the danger line: its pace over the last sim step (m/s).
func _measure_retreat(
	sim: RampageSim, tank: RampageSim.Tank, was: Vector2, got: Dictionary
) -> void:
	var convoy := sim.army_units.convoy
	var r: ConvoyRoute = convoy.routes.get(tank.id)
	var moved := tank.pos.distance_to(was)
	if (
		r == null
		or not r.retreating
		or moved < 0.01
		or convoy.posts.to_body(was) >= convoy.danger()
	):
		return
	var pace := moved / (4.0 / 60.0)
	got["retreat_steps"] = Num.i(got["retreat_steps"]) + 1
	if pace >= RETREAT_PACE.x and pace <= RETREAT_PACE.y:
		got["retreat_ok"] = Num.i(got["retreat_ok"]) + 1
	got["retreat_min"] = minf(Num.f(got["retreat_min"]), pace)
	got["retreat_max"] = maxf(Num.f(got["retreat_max"]), pace)


## How near the kaiju the tanks come, and any tank hull over a car still on its wheels.
func _measure_cars(rampage: Rampage, got: Dictionary) -> void:
	var sim := rampage.sim
	var street := rampage._city.street
	for tank: RampageSim.Tank in sim.tanks:
		got["closest"] = minf(Num.f(got["closest"]), tank.pos.distance_to(sim.kaiju_pos))
		var u := sim.army_units.convoy.front(tank.id)
		var edge := _hull_to_body(sim, tank.pos, u)
		var seen: Dictionary = got["was_at"]
		var was_at: Vector2 = seen.get(tank.id, tank.pos)
		seen[tank.id] = tank.pos
		var was := _hull_to_body(sim, was_at, u)  # where it stood a sim step ago, body as now
		if edge < EDGE_GAP and MilitaryCornered.cornered(sim, tank.pos):  # LEAD r7: it holds and fires
			got["cornered"] = Num.i(got["cornered"]) + 1
			got["cornered_edge"] = minf(Num.f(got["cornered_edge"]), edge)
			if edge < was - 0.05:  # it drove nearer the body (not the body nearer it)
				got["cornered_closer"] = Num.i(got["cornered_closer"]) + 1
		else:
			got["edge"] = minf(Num.f(got["edge"]), edge)
		if street == null or u == Vector2.ZERO:
			continue
		var half := Vector2(HULL_LENGTH * 0.5, HULL_HALF_WIDTH)
		for car: Traffic.Car in street.traffic.cars:
			var d := car.pos - tank.pos
			var lx := absf(d.dot(u)) - half.x - CAR_HALF.x
			var ly := absf(d.dot(u.orthogonal())) - half.y - CAR_HALF.y
			if not car.crushed and maxf(lx, ly) <= 0.0:
				got["on_car"] = Num.i(got["on_car"]) + 1


## How far the hull's nearest corner or side (HULL_LENGTH x 2 HULL_HALF_WIDTH along `u`; a
## circle that wide before it has a pose) is from the kaiju's body edge: the line from its
## origin (tail root) to its snout, body_radius wide (LEAD r7: the ground gap, head included).
static func _hull_to_body(sim: RampageSim, p: Vector2, u: Vector2) -> float:
	var snout: Vector2 = BreathCone.of(sim)["origin"]
	var radius := Num.f(sim.powers_cfg["body_radius"]) * sim.body_scale()
	var half := Vector2(HULL_LENGTH * 0.5, HULL_HALF_WIDTH)
	if u == Vector2.ZERO:
		var q := Geometry2D.get_closest_point_to_segment(p, sim.kaiju_pos, snout)
		return p.distance_to(q) - radius - half.length()
	var s := u.orthogonal()
	var hull := PackedVector2Array()
	for k: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1), Vector2(-1, 1)]:
		hull.append(p + u * half.x * k.x + s * half.y * k.y)
	var spine := PackedVector2Array([sim.kaiju_pos, snout])
	if not Geometry2D.intersect_polyline_with_polygon(spine, hull).is_empty():
		return -radius
	var best := INF
	for i: int in 4:
		var a := hull[i]
		var b := hull[(i + 1) % 4]
		var on_body := Geometry2D.get_closest_points_between_segments(a, b, sim.kaiju_pos, snout)
		best = minf(best, on_body[0].distance_to(on_body[1]))
	return best - radius


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
func _view_scene(run: int) -> Rampage:
	var species := Content.species_def("reptilian")
	var levels := {"claws": 1, "evolve1": 1}
	var tree := UpgradeTree.new(Content.upgrades(), levels, "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	stats["hp"] = 100000.0
	var tier := Num.i(stats["size"])
	var rampage := Rampage.new()
	var layout := CityGrowth.layout(Content.tuning(), tier, Seeds.make("city", 0))
	rampage.setup(species, stats, layout, run)
	rampage.sim.collapse.cut_only()  # the tanks' retreat, not where b2-5's mix drops the blocks
	Clip.start_at(rampage.sim)
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
