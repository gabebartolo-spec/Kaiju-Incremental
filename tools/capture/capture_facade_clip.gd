extends SceneTree
## The facade-carve clip (D-289): a real autoplayed reptilian rampage in the stage's own city, at
## the game camera, game speed. It logs when one tower (--building) first loses a chunk, which
## floors have lost chunks, and whether its base and top are on screen at that moment, so the
## ~6 s cut around that moment (ffmpeg -ss <t-2> -t 6) shows a tower carved at its base with its
## top in frame. Needs a window and the no-focus override.cfg; record with --write-movie.
##   godot --path . --resolution 3840x2160 --windowed --fixed-fps 60 --write-movie <out.avi> \
##     --script tools/capture/capture_facade_clip.gd -- --stage=3 --level=2 --building=116 \
##     --seconds=14

const Kit := preload("res://tools/capture/capture_kit.gd")

var _opt := {}


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	_opt = Kit.args(
		{"stage": 3, "level": 2, "building": 116, "seconds": 14.0, "species": "reptilian"}
	)
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var species := str(_opt["species"])
	var stats := Kit.stats(species, Kit.STAGE_LEVELS[Num.i(_opt["level"])], species)
	var layout := CityGrowth.layout(Content.tuning(), Num.i(_opt["stage"]), Seeds.make("city", 0))
	var rampage := Kit.autoplay(self, species, stats, 0, layout)
	var b := rampage.sim.buildings[Num.i(_opt["building"])]
	var last := b.frame.alive_count
	var frames := 0
	while frames < int(Num.f(_opt["seconds"]) * 60.0):
		await physics_frame
		frames += 1
		if b.frame.alive_count != last:
			last = b.frame.alive_count
			print("t=%.2f %s" % [frames / 60.0, _report(b)])
	quit()


## Floors that have lost chunks, and where the building's base and top fall on the screen now.
func _report(b: RampageSim.Building) -> String:
	var floors := {}
	for y: int in b.frame.h:
		for z: int in b.frame.d:
			for x: int in b.frame.w:
				if not b.frame.alive(Vector3i(x, y, z)):
					floors[y] = Num.i(floors.get(y, 0)) + 1
	var cam := Kit.game_camera(self)
	var base := Vector3(b.x, 0.0, b.z)
	var top := Vector3(b.x, float(b.height), b.z)
	return (
		"building %d %dx%dx%d style %d: chunks gone per floor %s; base %s top %s (screen %s)"
		% [
			Num.i(_opt["building"]),
			b.w,
			b.d,
			b.height,
			b.style,
			floors,
			_where(cam, base),
			_where(cam, top),
			root.get_visible_rect().size
		]
	)


func _where(cam: Camera3D, at: Vector3) -> String:
	if cam.is_position_behind(at):
		return "behind the camera"
	return str(cam.unproject_position(at).round())
