extends "res://tests/lib/military_air.gd"
## The military suite's game-view checks (D-066 r4): the clip's scene (tools/capture/
## capture_military.gd: a Behemoth at its crossing, columns calling in close, a pair up from the
## start), then a Colossus and an Apex, run as the game runs them and measured every frame
## through the game camera and the drawn models: helicopters whole in the frame and off the
## HUD, and no two tanks' drawn parts (hull, turret, gun, from the voxels through the models'
## own transforms) ever touching. Prints the probe table (VIEW lines) for the PR body.

const VIEW_SECONDS := 18.0
## Share of the screen kept clear at each edge.
const FRAME_MARGIN := 0.04
## The runs: the clip's (Behemoth at the capture's crossing, its overrides), then a Colossus and
## an Apex standing at their city's start with the sky open (helicopters up at once).
const RUNS: Array[Dictionary] = [
	{"name": "Behemoth clip", "levels": {"claws": 1, "evolve1": 1}, "clip": true},
	{"name": "Colossus", "levels": {"evolve1": 1, "evolve2": 1}, "clip": false},
	{"name": "Apex", "levels": {"evolve1": 1, "evolve2": 1, "evolve3": 1}, "clip": false},
]

var _shapes := {}  # tank part -> its footprint (_tank_shapes)


## Every run through the game camera; prints the probe table (PR body) and checks the bars.
func _check_view() -> void:
	root.size = Vector2i(1920, 1080)
	_shapes = _tank_shapes()
	var framed_ok := true
	var hud := 0
	var touching := 0
	var drift := 0.0
	var fov_ok := true
	var table := ""
	for run: Dictionary in RUNS:
		var levels: Dictionary = run["levels"]
		var got := await _view_run(levels, bool(run["clip"]))
		var frames := Num.f(got["frames"])
		var share := Num.f(got["framed"]) / maxf(1.0, frames)
		framed_ok = framed_ok and frames > 300 and share >= 0.95
		hud += Num.i(got["under"])
		touching += Num.i(got["touching"])
		drift = maxf(drift, Num.f(got["drift"]))
		fov_ok = fov_ok and bool(got["fov_ok"])
		table += (
			(
				"\nVIEW %s: heli in frame %.1f%% of %d, under HUD %d, pair lateral min %.1f m,"
				+ " facade min %.1f m, rotor-roof min %.1f m, fire yaw max %.1f deg (%d bursts);"
				+ " tank drawn gap min %.2f m, touching %d, yaw moving max %.1f deg"
			)
			% [
				run["name"],
				share * 100.0,
				frames,
				got["under"],
				got["lateral"],
				got["facade"],
				got["rotor"],
				got["fire_yaw"],
				got["bursts"],
				got["gap"],
				got["touching"],
				got["yaw"]
			]
		)
	print(table)
	check(drift < 1.0 and fov_ok, "air.view is the game camera: within %.2f m, same fov" % drift)
	check(
		framed_ok and hud == 0,
		"helicopters stay whole in the frame (>= 95%% each run) and off the HUD (%d)" % hud
	)
	check(touching == 0, "no two tanks' drawn parts touch in the game view (%d)" % touching)


## One run, measured every frame: {frames, framed, under, lateral, facade, rotor, fire_yaw,
## bursts, gap, touching, yaw, drift, fov_ok}.
func _view_run(levels: Dictionary, clip: bool) -> Dictionary:
	var rampage := _view_scene(levels, clip)
	root.add_child(rampage)
	await physics_frame
	var sim := rampage.sim
	if clip:
		_clip_overrides(sim)
	else:
		sim.air.cfg["after_chunks"] = 0
		sim.air.cfg["interval"] = 0.8
		sim.chunks_destroyed = Num.i(sim.air.cfg["max_per_chunks"]) * 3
	var roads := _roads(sim)
	var cam: Camera3D = rampage._camera
	var view: Dictionary = sim.air.cfg["view"]
	var got := {
		"frames": 0,
		"framed": 0,
		"under": 0,
		"lateral": INF,
		"facade": INF,
		"rotor": INF,
		"fire_yaw": 0.0,
		"bursts": 0,
		"gap": INF,
		"touching": 0,
		"yaw": 0.0,
		"drift": 0.0,
		"fov_ok": is_equal_approx(cam.fov, Num.f(view["fov"])),
	}
	var last := {}
	for i: int in roundi(VIEW_SECONDS * 60.0):
		await physics_frame
		sim.facing = Vector2(1, 0)
		if i > 300:  # the camera has settled on the kaiju
			var off := sim.air.space.camera()[0].distance_to(cam.global_position)
			got["drift"] = maxf(Num.f(got["drift"]), off)
		_measure_air(sim, cam, _plates(rampage._hud), got)
		_measure_tanks(rampage, roads, last, got)
	rampage.queue_free()
	await process_frame
	return got


## The helicopters this frame: framing, HUD, pair spacing, facades, roofs and fire yaw.
func _measure_air(sim: RampageSim, cam: Camera3D, plates: Array[Rect2], got: Dictionary) -> void:
	for heli: AirWing.Heli in sim.air.helis:
		got["frames"] = Num.i(got["frames"]) + 1
		var seen := _heli_seen(cam, heli, plates)
		got["framed"] = Num.i(got["framed"]) + (1 if seen.x > 0.0 else 0)
		got["under"] = Num.i(got["under"]) + (1 if seen.y > 0.0 else 0)
		for b: RampageSim.Building in sim.buildings:
			var half := Vector2(b.w, b.d) * 0.5
			var near := heli.pos.clamp(Vector2(b.x, b.z) - half, Vector2(b.x, b.z) + half)
			var across := near.distance_to(heli.pos)
			if across < 3.3 + 0.8:  # under the rotor disc
				got["rotor"] = minf(Num.f(got["rotor"]), heli.alt - b.height)
			if b.height > heli.alt - 4.0:  # not well below it: a face it must keep off
				got["facade"] = minf(Num.f(got["facade"]), across)
		for lead: AirWing.Heli in sim.air.helis:
			if lead.id == heli.wing_of:
				got["lateral"] = minf(Num.f(got["lateral"]), heli.pos.distance_to(lead.pos))
	for event: Dictionary in sim.events:
		if str(event["type"]) != "heli_fired":
			continue
		for heli: AirWing.Heli in sim.air.helis:
			if heli.id == Num.i(event["heli"]):
				var yaw := rad_to_deg(absf(heli.front.angle_to(sim.kaiju_pos - heli.pos)))
				got["fire_yaw"] = maxf(Num.f(got["fire_yaw"]), yaw)
				got["bursts"] = Num.i(got["bursts"]) + 1


## The tanks this frame: their drawn parts' closest approach and the hull's yaw while moving.
func _measure_tanks(rampage: Rampage, roads: Dictionary, last: Dictionary, got: Dictionary) -> void:
	var sim := rampage.sim
	var parts := {}
	for tank: RampageSim.Tank in sim.tanks:
		var was: Vector2 = last.get(tank.id, tank.pos)
		var front := sim.army_units.convoy.front(tank.id)
		if tank.pos.distance_to(was) > 0.0005 and front != Vector2.ZERO:
			got["yaw"] = maxf(Num.f(got["yaw"]), _yaw_off_road(tank.pos, front, roads))
		last[tank.id] = tank.pos
		if rampage._tank_nodes.has(tank.id):
			var node: TankModel = rampage._tank_nodes[tank.id]
			parts[tank.id] = _tank_drawn(node, _shapes)
	var ids := parts.keys()
	for a: int in ids.size():
		for b: int in range(a + 1, ids.size()):
			var one: Array[PackedVector2Array] = parts[ids[a]]
			var two: Array[PackedVector2Array] = parts[ids[b]]
			var g := _parts_gap(one, two)
			got["gap"] = minf(Num.f(got["gap"]), g)
			got["touching"] = Num.i(got["touching"]) + (1 if g <= 0.0 else 0)


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


## The game's rampage scene for `levels`: a reptilian that cannot fall, standing at the
## capture's crossing (clip) or its city's start.
func _view_scene(levels: Dictionary, clip: bool) -> Rampage:
	var species := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), levels, "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	stats["hp"] = 100000.0
	var tier := Num.i(stats["size"])
	var rampage := Rampage.new()
	var layout := CityGrowth.layout(Content.tuning(), tier, Seeds.make("city", 0))
	rampage.setup(species, stats, layout, 1)
	if clip:
		rampage.sim.kaiju_pos = Vector2(5, -70)  # capture_military.CLIP_AT
	rampage.scripted = func(_s: RampageSim) -> Dictionary: return {"move": Vector2.ZERO}
	return rampage


## The capture's overrides (capture_military._run), so it all happens in sight inside 18 s.
func _clip_overrides(sim: RampageSim) -> void:
	sim.army["spawn_radius"] = 44.0
	sim.army["start_interval"] = 1.6
	sim.army_units._spawn_timer = 0.3
	sim.air.cfg["after_chunks"] = 0
	sim.air.cfg["max_per_chunks"] = 1
	sim.air.cfg["interval"] = 0.8
	sim.air._form["run_every"] = 2.5
	sim.chunks_destroyed = 2


func _plates(hud: Node) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for node: Node in hud.find_children("*", "PanelContainer", true, false):
		var plate := node as PanelContainer
		if plate.is_visible_in_tree():
			out.append(plate.get_global_rect())
	return out


## (1 if the airframe, nose to tail and the rotor disc, is whole inside the frame's margin,
## 1 if any of it is under a HUD plate).
func _heli_seen(cam: Camera3D, heli: AirWing.Heli, plates: Array[Rect2]) -> Vector2:
	var size := root.get_viewport().get_visible_rect().size
	var nose := heli.front if heli.front != Vector2.ZERO else Vector2(0, -1)
	var c := Vector3(heli.pos.x, heli.alt, heli.pos.y)
	var along := Vector3(nose.x, 0, nose.y) * HELI_HALF
	var points: Array[Vector3] = [c + along, c - along]
	for k: int in 8:
		var d := Vector2.from_angle(k * TAU / 8.0) * 3.3  # the main rotor's radius
		points.append(c + Vector3(d.x, 2.2, d.y))
	var inside := 1.0
	var covered := 0.0
	for p: Vector3 in points:
		if cam.is_position_behind(p):
			inside = 0.0
			continue
		var s := cam.unproject_position(p)
		var lo := size * FRAME_MARGIN
		if s.x < lo.x or s.y < lo.y or s.x > size.x - lo.x or s.y > size.y - lo.y:
			inside = 0.0
		for plate: Rect2 in plates:
			if plate.has_point(s):
				covered = 1.0
	return Vector2(inside, covered)


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
