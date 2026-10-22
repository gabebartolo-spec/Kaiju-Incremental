extends SceneTree
## A plain smash topple, close up (the shared collapse defect, BuildingView.lift_piece): an
## autoplayed reptilian walks into towers until one topples; stills at the game camera and from a
## camera beside the falling piece over its fall, so its cut side and the stump left behind show.
## Needs a window and the no-focus override.cfg.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_topple_faces.gd -- --out=<dir> --run=3

const Kit := preload("res://tools/capture/capture_kit.gd")
const LEVELS := {"claws": 5, "hide": 5, "rage": 3, "evolve1": 1}
## Frames after the fall starts at which to still it.
const AT: Array[int] = [6, 14, 24, 40]
const GIVE_UP := 60 * 90
## The side camera: this far from the piece's pivot (world units), this high.
const SIDE := Vector3(14.0, 6.0, 10.0)

var _out := "user://topple_faces"


func _initialize() -> void:
	var a := Kit.args({"out": _out, "run": 3, "falls": 2})
	_out = str(a["out"])
	DirAccess.make_dir_recursive_absolute(_out)
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred(Num.i(a["run"]), Num.i(a["falls"]))


func _run(run: int, falls: int) -> void:
	await process_frame
	var rampage := Kit.autoplay(self, "reptilian", Kit.stats("reptilian", LEVELS), run)
	rampage.autoplay_signature = false
	await rampage.wait_loaded()
	rampage.sim.time_left = 600.0
	var city: CityView = rampage.get("_city")
	var seen: Array[int] = []
	for frame: int in GIVE_UP:
		await physics_frame
		var falling: Dictionary = city.get("_falling")
		for id: int in falling:
			var f: Dictionary = falling[id]
			if seen.has(id) or str(f["kind"]) != "topple":
				continue
			seen.append(id)
			var piece: Node3D = f["node"]
			await _shots(seen.size(), piece)
			if seen.size() >= falls:
				quit()
				return
	print("capture_topple_faces: only %d topples in %d frames" % [seen.size(), GIVE_UP])
	quit()


func _shots(n: int, piece: Node3D) -> void:
	var pivot := piece.global_position
	var waited := 0
	for at: int in AT:
		await Kit.frames(self, at - waited)
		waited = at
		if not is_instance_valid(piece):
			return
		Kit.still(self, _out, "fall%d_game_%02d" % [n, at])
		var game_cam := root.get_viewport().get_camera_3d()
		var cam := Kit.camera(root)
		cam.position = pivot + SIDE
		cam.look_at(pivot + Vector3(0, 4.0, 0))
		cam.current = true
		await process_frame
		Kit.still(self, _out, "fall%d_side_%02d" % [n, at])
		game_cam.current = true
		cam.queue_free()
