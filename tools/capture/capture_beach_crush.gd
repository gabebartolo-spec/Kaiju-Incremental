extends SceneTree
## Crushed beach umbrellas as the game shows them (director 10-30: "Squashed umbrellas read as
## Skittles"): the stage's real city (Rampage, HUD hidden), a camera where the game's rests
## (CameraTuning's offset x zoom for the stage's body) over a stretch of sand west of the rise,
## then the same from straight above; each shot before and after every umbrella within REACH of
## that spot is crushed (CityDecor.crush, as a stomp does), the blow from the sand's middle.
## Needs a window and the off-screen no_focus override.cfg on this PC (or CI):
##   godot --path . --resolution 3840x2160 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_beach_crush.gd -- --stage=2 --out=<dir> [--x=-40]

const Kit := preload("res://tools/capture/capture_kit.gd")
const SETTLE := 90  # frames for streaming and lights to settle before each still
const REACH := 6.0  # umbrellas this near the spot are crushed (m)
const ABOVE := 30.0  # the straight-down shot's height over the spot (m)
const BLOW := 0.8  # each blow's radius, from 0.5 m off its umbrella (m)

var _out := ""


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	if not Kit.window_ok():
		quit(2)
		return
	var a := Kit.args({"stage": 2, "out": "user://beach_crush", "x": -40.0})
	var stage: int = a["stage"]
	_out = a["out"]
	DirAccess.make_dir_recursive_absolute(_out)
	var stats := Kit.stats("reptilian", Kit.STAGE_LEVELS[stage - 1])
	var layout := CityGrowth.layout(Content.tuning(), stage, Seeds.make("city", 0))
	var rampage := Kit.rampage("reptilian", stats, 0, layout)
	root.add_child(rampage)
	rampage.scripted = func(_s: RampageSim) -> Dictionary: return {"move": Vector2.ZERO}
	# The emerge drives its own camera and HUD until the kaiju is ashore.
	while rampage.sim.emerge.active:
		await physics_frame
	await Kit.frames(self, 2)
	_hide_hud(rampage)
	var decor: CityDecor = _find(rampage, CityDecor)
	var spot := _spot(decor, Num.f(a["x"]))
	var cam := Kit.camera(root)
	var eye := CameraTuning.offset() * CameraTuning.zoom(rampage.sim.body_scale())
	var views := {"game": Vector3(spot.x, 0, spot.y) + eye, "above": Vector3(spot.x, ABOVE, spot.y)}
	await _shots(cam, views, spot, "stage%d_beach_%%s_before" % stage)
	decor.trampling = true
	var hit := 0
	for at: Vector2 in BeachProps.spots(decor.plan, decor._view):
		if at.distance_to(spot) <= REACH:
			# The blow comes from a little seaward and west, so each falls a different way.
			decor.crush(Vector3(at.x - 0.3, 0, at.y - 0.4), BLOW)
			hit += 1
	var crushed := decor._beach._groups.filter(
		func(g: Dictionary) -> bool: return g.get("crushed", false)
	)
	print("capture: %d umbrellas struck, %d props crushed" % [hit, crushed.size()])
	await _shots(cam, views, spot, "stage%d_beach_%%s_after" % stage)
	quit(0)


## One still from each view, named `shot` with the view's name in it.
func _shots(cam: Camera3D, views: Dictionary, spot: Vector2, shot: String) -> void:
	for view: String in views:
		var eye: Vector3 = views[view]
		cam.position = eye
		if view == "above":
			cam.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		else:
			cam.look_at(Vector3(spot.x, 0, spot.y))
		for k: int in SETTLE:
			cam.make_current()
			await process_frame
		print("capture: ", Kit.still(self, _out, shot % view))


## The umbrella nearest the sand's middle at x.
func _spot(decor: CityDecor, x: float) -> Vector2:
	var spots := BeachProps.spots(decor.plan, decor._view)
	var mid := Vector2.ZERO
	for at: Vector2 in spots:
		mid += at
	mid = Vector2(x, mid.y / maxf(spots.size(), 1))
	var best := spots[0]
	for at: Vector2 in spots:
		if at.distance_to(mid) < best.distance_to(mid):
			best = at
	return best


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
