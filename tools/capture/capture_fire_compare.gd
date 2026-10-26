extends SceneTree
## One still, the director's consistency check: an in-game fire (left, close) beside the title's
## fire (right, far, the same Fire at zoom) at a similar size on screen, on a dark night ground.
## Local GPU only:
##   godot --path . --windowed --resolution 1920x1080 \
##     --script tools/capture/capture_fire_compare.gd -- --out=<dir>

const SETTLE_FRAMES := 240
## The street fire stands this far from the camera; the title's fire this much farther, so both
## look about as big (the title's fire is its zoom times bigger).
const NEAR := 12.0
const SIDE := 3.2

var _out := "user://fire_compare"


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	Content.set_time("night")
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0c1224")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("3a4c78")
	env.ambient_light_energy = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.8
	var world := WorldEnvironment.new()
	world.environment = env
	root.add_child(world)
	var camera := Camera3D.new()
	camera.fov = 50.0
	root.add_child(camera)
	camera.position = Vector3(0.0, 2.0, 0.0)
	camera.look_at(Vector3(0.0, 2.0, -NEAR))
	var far: Dictionary = Content.section("title")["fires"]["far"]
	var zoom := Num.f(far["zoom"])
	var street := Fire.new(1.2, 1.0)
	street.position = Vector3(-SIDE, 0.0, -NEAR)
	root.add_child(street)
	var distant := FarFire.new(far, 2.0)
	# The same angle from the camera: zoom times farther and so zoom times lower.
	distant.position = Vector3(SIDE * zoom, 2.0 - 2.0 * zoom, -NEAR * zoom)
	root.add_child(distant)
	for _i: int in SETTLE_FRAMES:
		await process_frame
	root.get_texture().get_image().save_png(_out.path_join("fire_compare.png"))
	quit()
