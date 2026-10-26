extends SceneTree
## A still of one spot of the real game's city (the rampage scene as the player gets it, seed and
## stage of a run, Medium preset), seen from a camera placed by hand before the kaiju rises: the
## roads suite's named spots (a bridge into a park, a junction seam) for the director, before and
## after a ground change. No HUD aid or debug overlay: the breath-aim wedge is hidden, as in
## capture_one_look.gd.
##   godot --path . --windowed --resolution 3840x2160 --script <this file> --
##     --spot=-3,52 --from=8,10,-12 --stage=1 --time=noon --label=bridge_park --out=<dir>
##   --spot=x,z (what the camera looks at)  --from=dx,dy,dz (the camera, from the spot)

const Kit := preload("res://tools/capture/capture_kit.gd")


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var a := Kit.args(
		{
			"spot": "0,0",
			"from": "8,10,-12",
			"stage": 1,
			"time": "noon",
			"label": "spot",
			"out": "user://road_spots",
			"graphics": "medium",
			"fov": 50.0
		}
	)
	DirAccess.make_dir_recursive_absolute(str(a["out"]))
	PlayerSettings.graphics = str(a["graphics"])
	var stats := Kit.stats("reptilian", Kit.STAGE_LEVELS[Num.i(a["stage"]) - 1], "reptilian")
	var tier := Num.i(stats["size"])
	var layout := CityGrowth.layout(Content.tuning(), tier, Seeds.make("city", 0))
	var rampage := Rampage.new()
	rampage.setup(Content.species_def("reptilian"), stats, layout, 0)
	Content.set_time(str(a["time"]))
	root.add_child(rampage)
	var city: CityView = rampage.get("_city")
	var stream: BuildingStream = city.get("_stream")
	while not stream.complete():
		await process_frame
	rampage.set_physics_process(false)
	rampage.set_process(false)
	for child: Node in rampage.get_children():
		if child is BreathAim:
			(child as BreathAim).visible = false
	var spot := _vec(str(a["spot"]))
	var at := Vector3(spot.x, 0.0, spot.y)
	var off := _vec3(str(a["from"]))
	var cam := Camera3D.new()
	cam.fov = Num.f(a["fov"])
	root.add_child(cam)
	cam.look_at_from_position(at + off, at, Vector3.UP)
	cam.make_current()
	await Kit.frames(self, 30)
	var path := Kit.still(self, str(a["out"]), str(a["label"]))
	print("SPOT %s at %s from %s -> %s" % [a["label"], spot, off, path])
	quit()


static func _vec(text: String) -> Vector2:
	var p := text.split(",")
	return Vector2(float(p[0]), float(p[1]))


static func _vec3(text: String) -> Vector3:
	var p := text.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))
