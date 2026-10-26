extends SceneTree
## The city's street plan from above, as the game builds it (road geometry, D-265; the director
## asked for "4K overhead stills of stage 1 and stage 3 plus one close still of an island"): the
## stage's real city (Rampage, as a run sets it up, HUD hidden) under a camera straight down over
## the arena and the band past it, and with --island a close, angled still of the traffic island
## nearest the middle (TrafficIsland: where the diagonal meets an avenue).
## Needs a window and the off-screen no_focus override.cfg on this PC (or CI):
##   godot --path . --resolution 3840x2160 --fixed-fps 60 \
##     --script tools/capture/capture_city_overhead.gd -- --stage=1 --out=<dir> [--island]

const Kit := preload("res://tools/capture/capture_kit.gd")
const SETTLE := 90  # frames for streaming and lights to settle before the still
const FOV := 40.0
const ISLAND_VIEW := Vector3(0.0, 9.0, 11.0)  # the island still's camera, off the island (m)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	if not Kit.window_ok():
		quit(2)
		return
	var a := Kit.args({"stage": 1, "out": "user://overhead", "island": false, "seed": 0})
	var stage: int = a["stage"]
	var out: String = a["out"]
	DirAccess.make_dir_recursive_absolute(out)
	var stats := Kit.stats("reptilian", Kit.STAGE_LEVELS[stage - 1])
	var layout := CityGrowth.layout(Content.tuning(), stage, Seeds.make("city", Num.i(a["seed"])))
	var rampage := Kit.rampage("reptilian", stats, Num.i(a["seed"]), layout)
	rampage.scripted = func(_s: RampageSim) -> Dictionary: return {"move": Vector2.ZERO}
	root.add_child(rampage)
	await Kit.frames(self, 2)
	_hide_hud(rampage)
	var sim := rampage.sim
	var cam := Kit.camera(root)
	cam.fov = FOV
	var shot := "stage%d_overhead" % stage
	if a["island"]:
		var decor: CityDecor = _find(rampage, CityDecor)
		var spot := _nearest_middle(decor.islands)
		if spot == Vector2.INF:
			printerr("capture: no traffic island in this city")
			quit(1)
			return
		var at := Vector3(spot.x, 0.0, spot.y)
		cam.position = at + ISLAND_VIEW
		cam.look_at(at, Vector3.UP)
		shot = "stage%d_island" % stage
		print("capture: island at %s" % spot)
	else:
		var reach := sim.arena_half + Num.f(sim.city["view_beyond"])
		var high := reach / tan(deg_to_rad(FOV * 0.5))
		cam.position = Vector3(0.0, high, 0.0)
		cam.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	for k: int in SETTLE:
		cam.make_current()
		await process_frame
	print("capture: ", Kit.still(self, out, shot))
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


static func _nearest_middle(spots: Array[Vector2]) -> Vector2:
	var best := Vector2.INF
	for p: Vector2 in spots:
		if p.length() < best.length():
			best = p
	return best
