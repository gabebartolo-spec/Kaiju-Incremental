extends SceneTree
## Where the trees stand (director comment 2026-10-27, D-345: "why are there so many trees on top of
## buildings is that a bug?"). A real rampage (the flow test's city, the reptilian risen and then
## stood in a street, the HUD up, no debug UI) at --time with the game camera at rest behind it.
##   --view=far   on the play area's north edge at the foot of a north-south street, looking north
##                over the quay and the bay to the far skyline (capture_far_city.gd's view)
##                --shift=<m> moves it that far east along the ring avenue (a closer roof)
##   --view=play  at the city's centre block, on a street with street trees down both kerbs
##   --view=skyline the camera 9 m from the nearest white solar heater on a far stand-in's roof
##                (SkylineRoofTank), looking down at it from the city side
##   --view=tower the street node `--dz` north and `--dx` east of the low brick building nearest
##                the centre (5-9 floors), so its roof and water tower fill the lower frame
## Writes <out>/rooftop_trees_<view>_<tag>.png (the window's size: 1080p with the off-screen
## no_focus override.cfg); with --nodecor also <view>_<tag>_nodecor.png, the same frame with
## everything CityDecor plants (trees, bushes, cars, lamps) hidden, to tell its trees from
## whatever else on the roofs reads as one.
##   godot --path . --windowed --fixed-fps 60 --script tools/capture/capture_rooftop_trees.gd -- \
##     --out=<dir> --view=far --time=noon [--tag=after] [--nodecor]

const Kit := preload("res://tools/capture/capture_kit.gd")
const SPECIES := "reptilian"
const FRAMES_BETWEEN := 3  # frames after a change before a grab, so it is drawn

var _a := {}


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	_a = Kit.args(
		{
			"out": "",
			"tag": "after",
			"time": "noon",
			"view": "far",
			"settle": 600,
			"walk": 300,
			"shift": 0.0,
			"dx": 8.0,
			"dz": 30.0,
			"nodecor": false
		}
	)
	if str(_a["out"]) == "" or not Kit.window_ok():
		printerr("capture_rooftop_trees: needs --out and a window (no_focus override.cfg)")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(str(_a["out"]))
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var rampage := Kit.rampage(SPECIES, Kit.stats(SPECIES), Content.times().find(str(_a["time"])))
	root.add_child(rampage)
	await rampage.wait_loaded()
	await Kit.frames(self, Num.i(_a["settle"]))  # risen from the river
	var half := CityGen.half_extent(rampage.sim.city)
	var plan := CityGen.map(rampage.sim.city)
	match str(_a["view"]):
		"far":
			rampage.sim.kaiju_pos = _north_edge(plan, half) + Vector2(Num.f(_a["shift"]), 0.0)
		"tower":
			rampage.sim.kaiju_pos = _by_tower(rampage.sim, plan)
		_:
			rampage.sim.kaiju_pos = _centre(plan)
	await Kit.frames(self, Num.i(_a["walk"]))  # there, the camera at rest behind it
	paused = true
	await Kit.frames(self, FRAMES_BETWEEN)
	if str(_a["view"]) == "skyline":
		_look_at_heater(rampage)
		await Kit.frames(self, FRAMES_BETWEEN)
	var stem := "rooftop_trees_%s_%s" % [str(_a["view"]), str(_a["tag"])]
	Kit.still(self, str(_a["out"]), stem)
	if _a["nodecor"] == true:
		var decor: Array = rampage.find_children("*", "CityDecor", true, false)
		for node: Node3D in decor:
			node.visible = false
		await Kit.frames(self, FRAMES_BETWEEN)
		Kit.still(self, str(_a["out"]), stem + "_nodecor")
	print("capture_rooftop_trees: %s done" % stem)
	quit()


## Puts the camera 9 m toward the city centre and 7 m up from the nearest white heater on a far
## stand-in's roof (within CitySkyline's roof-detail reach), looking at it.
func _look_at_heater(rampage: Node) -> void:
	var skyline: CitySkyline = rampage.find_children("*", "CitySkyline", true, false)[0]
	var best := Vector3.ZERO
	var nearest := INF
	for box: Dictionary in skyline.plain_drawn():
		var c: Color = box["c"]
		var t: Transform3D = box["t"]
		var flat := Vector2(t.origin.x, t.origin.z)
		if c.is_equal_approx(SkylineRoofTank.WHITE) and flat.length() > 60.0:
			if flat.length() < nearest:
				nearest = flat.length()
				best = t.origin
	var toward := Vector3(-best.x, 0.0, -best.z).normalized()
	var cam := root.get_viewport().get_camera_3d()
	cam.global_position = best + toward * 9.0 + Vector3(0.0, 7.0, 0.0)
	cam.look_at(best, Vector3.UP)
	print("capture_rooftop_trees: heater at %s, %.0f from the centre" % [best, nearest])


## On the play area's north edge (`half` from the centre): the ring avenue at the foot of the
## north-south street nearest the centre, so the camera behind rides above the street, not a roof.
func _north_edge(plan: Dictionary, half: float) -> Vector2:
	var nodes: Array[Vector2] = plan["nodes"]
	var best := Vector2(INF, -half)
	for street: Dictionary in plan["streets"]:
		var a := nodes[Num.i(street["from"])]
		var b := nodes[Num.i(street["to"])]
		var ring := absf(minf(a.y, b.y) + half) < 1.0 and maxf(a.y, b.y) > -half + 1.0
		if ring and absf(a.x - b.x) < 0.5 and absf(a.x) < absf(best.x):
			best = Vector2(a.x, -half)
	return best if best.x != INF else Vector2(0.0, -half)


## The street node nearest the centre that no diagonal avenue crosses: a street with trees down
## both kerbs, the camera behind it looking along the street.
func _centre(plan: Dictionary) -> Vector2:
	var nodes: Array[Vector2] = plan["nodes"]
	var best := Vector2.ZERO
	var nearest := INF
	for node: Vector2 in nodes:
		if node.length() < nearest and CityGen.diagonal_distance(plan, node) > 12.0:
			nearest = node.length()
			best = node
	return best


## The street node nearest the spot `--dz` north and `--dx` east of the low (5-9 floor) brick
## building nearest the centre of the city: the camera rides behind and above, so that building's
## roof is what lies under it.
func _by_tower(sim: RampageSim, plan: Dictionary) -> Vector2:
	var pick: RampageSim.Building = null
	for b: RampageSim.Building in sim.lot_buildings():
		if b.style % 4 != BuildingLayout.BRICK or b.height < 5 or b.height > 9:
			continue
		if pick == null or Vector2(b.x, b.z).length() < Vector2(pick.x, pick.z).length():
			pick = b
	var want := Vector2(pick.x + Num.f(_a["dx"]), pick.z - Num.f(_a["dz"]))
	var best := want
	var nearest := INF
	for node: Vector2 in plan["nodes"]:
		if node.distance_to(want) < nearest:
			nearest = node.distance_to(want)
			best = node
	print(
		(
			"capture_rooftop_trees: tower lot %dx%d, %d floors at (%.0f, %.0f), kaiju at %s"
			% [pick.w, pick.d, pick.height, pick.x, pick.z, best]
		)
	)
	return best
