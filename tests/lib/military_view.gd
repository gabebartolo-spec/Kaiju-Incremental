extends "res://tests/lib/military_air.gd"
## The military suite's game-view checks (D-066 r4): the clip's scene (tools/capture/
## capture_military.gd: a Behemoth at its crossing, columns calling in close, a pair up from the
## start) run as the game runs it, measured every frame through the game camera and the drawn
## models: helicopters whole in the frame and off the HUD, and no two tanks' drawn parts (hull,
## turret, gun, from the voxels through the models' own transforms) ever touching.

const VIEW_SECONDS := 18.0
## Share of the screen kept clear at each edge.
const FRAME_MARGIN := 0.04


func _check_view() -> void:
	root.size = Vector2i(1920, 1080)
	var rampage := _clip_scene()
	root.add_child(rampage)
	await physics_frame
	_clip_overrides(rampage.sim)
	var sim := rampage.sim
	var shapes := _tank_shapes()
	var cam: Camera3D = rampage._camera
	var hud: Node = rampage._hud
	var frames := 0
	var framed := 0
	var under := 0
	var touching := 0
	var gap := INF
	var drift := 0.0
	for i: int in roundi(VIEW_SECONDS * 60.0):
		await physics_frame
		sim.facing = Vector2(1, 0)
		if i > 300:  # the camera has settled on the kaiju
			drift = maxf(drift, sim.air.space.camera()[0].distance_to(cam.global_position))
		var plates := _plates(hud)
		for heli: AirWing.Heli in sim.air.helis:
			frames += 1
			var seen := _heli_seen(cam, heli, plates)
			framed += 1 if seen.x > 0.0 else 0
			under += 1 if seen.y > 0.0 else 0
		var parts := {}
		for tank: RampageSim.Tank in sim.tanks:
			if rampage._tank_nodes.has(tank.id):
				var node: TankModel = rampage._tank_nodes[tank.id]
				parts[tank.id] = _tank_drawn(node, shapes)
		var ids := parts.keys()
		for a: int in ids.size():
			for b: int in range(a + 1, ids.size()):
				var one: Array[PackedVector2Array] = parts[ids[a]]
				var two: Array[PackedVector2Array] = parts[ids[b]]
				var g := _parts_gap(one, two)
				gap = minf(gap, g)
				touching += 1 if g <= 0.0 else 0
	rampage.queue_free()
	var view: Dictionary = sim.air.cfg["view"]
	check(
		drift < 1.0 and is_equal_approx(cam.fov, Num.f(view["fov"])),
		"air.view is the game camera: within %.2f m of it, fov %.0f" % [drift, cam.fov]
	)
	check(
		frames > 600 and framed >= frames * 0.95 and under == 0,
		(
			"helicopters stay whole in the frame (%.0f%% of %d heli-frames) and off the HUD (%d)"
			% [100.0 * framed / maxf(1.0, frames), frames, under]
		)
	)
	check(
		touching == 0 and gap < INF,
		"no two tanks' drawn parts touch in the game view (%d; closest %.2f m)" % [touching, gap]
	)


## The capture's scene: a Behemoth croc that cannot fall, at the capture's crossing.
func _clip_scene() -> Rampage:
	var species := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), {"claws": 1, "evolve1": 1}, "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	stats["hp"] = 100000.0
	var tier := Num.i(stats["size"])
	var rampage := Rampage.new()
	var layout := CityGrowth.layout(Content.tuning(), tier, Seeds.make("city", 0))
	rampage.setup(species, stats, layout, 1)
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
