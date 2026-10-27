extends SceneTree
## The city's street plan from above, as the game builds it (road geometry, D-265; the director
## asked for "4K overhead stills of stage 1 and stage 3 plus one close still of an island"): the
## stage's real city (Rampage, as a run sets it up, HUD hidden) under a camera straight down over
## the arena and the band past it, and with --island a close, angled still of the traffic island
## nearest the middle (TrafficIsland: where the diagonal meets an avenue).
## Needs a window and the off-screen no_focus override.cfg on this PC (or CI):
##   godot --path . --resolution 3840x2160 --fixed-fps 60 \
##     --script tools/capture/capture_city_overhead.gd -- --stage=1 --out=<dir> \
##     [--island [--pick=k]]

const Kit := preload("res://tools/capture/capture_kit.gd")
const SETTLE := 90  # frames for streaming and lights to settle before the still
const FOV := 40.0
const ISLAND_BACK := 12.0  # the kaiju stands this far down the road from the crossing (m)


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	if not Kit.window_ok():
		quit(2)
		return
	var a := Kit.args({"stage": 1, "out": "user://overhead", "island": false, "seed": 0, "pick": 0})
	var stage: int = a["stage"]
	var out: String = a["out"]
	DirAccess.make_dir_recursive_absolute(out)
	var stats := Kit.stats("reptilian", Kit.STAGE_LEVELS[stage - 1])
	var layout := CityGrowth.layout(Content.tuning(), stage, Seeds.make("city", Num.i(a["seed"])))
	var rampage := Kit.rampage("reptilian", stats, Num.i(a["seed"]), layout)
	root.add_child(rampage)
	if a["island"]:
		await _island(rampage, out, stage, Num.i(a["pick"]))
		return
	rampage.scripted = func(_s: RampageSim) -> Dictionary: return {"move": Vector2.ZERO}
	await Kit.frames(self, 2)
	_hide_hud(rampage)
	var sim := rampage.sim
	var cam := Kit.camera(root)
	cam.fov = FOV
	var shot := "stage%d_overhead" % stage
	var reach := sim.arena_half + Num.f(sim.city["view_beyond"])
	var high := reach / tan(deg_to_rad(FOV * 0.5))
	cam.position = Vector3(0.0, high, 0.0)
	cam.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	for k: int in SETTLE:
		cam.make_current()
		await process_frame
	print("capture: ", Kit.still(self, out, shot))
	quit(0)


## The island still as the game shows it: the run's own camera rig at its default zoom, HUD on,
## the kaiju (once out of the river) set down in the street by the crossing of the island
## nearest the middle (or the pick-th nearest; _road_back), so the island sits ahead of it.
func _island(rampage: Rampage, out: String, stage: int, pick: int) -> void:
	while rampage.sim.emerge.active:
		await physics_frame
	var decor: CityDecor = _find(rampage, CityDecor)
	var spots := decor.islands.duplicate()
	spots.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.length() < q.length())
	print("capture: islands %s" % [spots])
	if pick >= spots.size():
		printerr("capture: no traffic island %d in this city" % pick)
		quit(1)
		return
	var spot: Vector2 = spots[pick]
	rampage.sim.kaiju_pos = _road_back(decor.plan, spot)
	for k: int in SETTLE:
		await process_frame
	print("capture: island at %s, kaiju at %s" % [spot, rampage.sim.kaiju_pos])
	print("capture: ", Kit.still(self, out, "stage%d_island" % stage))
	quit(0)


func _hide_hud(node: Node) -> void:
	for child: Node in node.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
		_hide_hud(child)


func _find(node: Node, type: Variant) -> Node:
	for child: Node in node.get_children():
		if is_instance_of(child, type):
			return child
		var deeper := _find(child, type)
		if deeper != null:
			return deeper
	return null


## A spot on the diagonal ISLAND_BACK metres from the crossing nearest `spot`, along its arm
## toward the camera (+z), so the kaiju stands in the street, off the avenue (where the railway
## may run overhead), with the island ahead.
static func _road_back(plan: Dictionary, spot: Vector2) -> Vector2:
	var nodes: Array[Vector2] = plan["nodes"]
	var n := 0
	for k: int in nodes.size():
		if nodes[k].distance_to(spot) < nodes[n].distance_to(spot):
			n = k
	var best := Vector2(0.0, 1.0)
	for s: Dictionary in plan["streets"]:
		var from := Num.i(s["from"])
		var to := Num.i(s["to"])
		if (from == n or to == n) and str(s["kind"]) == CityGen.DIAGONAL:
			var dir := (nodes[to if from == n else from] - nodes[n]).normalized()
			if dir.y > 0.0:
				best = dir
	return nodes[n] + best * ISLAND_BACK
