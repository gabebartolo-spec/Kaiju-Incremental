extends SceneTree
## The croc titan standing in a real rampage at the game camera (D-165, the living predator): no
## input, HUD on. Prints when the rise from the river ends and the breath's top and bottom (the
## seconds into the clip), and with --shots saves a still at the first top and the first bottom
## once the layer is fully in, each with a 2x crop on the back. --stomps=0 stops the sim's own
## stomps (a stomp every 0.7 s lifts a foot and shakes the camera), to see the breath alone. Needs
## a window; pair with --write-movie for a clip.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 --write-movie <dir>/c.avi \
##     --script tools/capture/capture_idle_game.gd -- --out=<dir> --stage=2 --seconds=24 \
##     [--shots] [--run=2] [--stomps=false]

const Kit := preload("res://tools/capture/capture_kit.gd")
const CROP := Vector2i(560, 420)

var _out := "user://idle_game"
var _stage := 2
var _seconds := 24.0
var _shots := false
var _stomps := true
var _run_index := 1  ## the run: its time of day is Content.time_for_run(run)


func _initialize() -> void:
	var a := Kit.args(
		{
			"out": _out,
			"stage": _stage,
			"seconds": _seconds,
			"shots": false,
			"stomps": true,
			"run": 1
		}
	)
	_out = str(a["out"])
	_stage = Num.i(a["stage"])
	_seconds = Num.f(a["seconds"])
	_shots = a["shots"]
	_stomps = a["stomps"]
	_run_index = Num.i(a["run"])
	DirAccess.make_dir_recursive_absolute(_out)
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var levels: Dictionary = Kit.STAGE_LEVELS[_stage]
	var rampage := Kit.rampage("reptilian", Kit.stats("reptilian", levels), _run_index)
	rampage.scripted = func(_sim: RampageSim) -> Dictionary: return {}
	root.add_child(rampage)
	await rampage.wait_loaded()
	var aim: Node3D = rampage.find_child("BreathAim", false, false)
	if aim != null:  # the breath's aim wedge is a game aid, not part of the shot
		aim.set_physics_process(false)
		aim.visible = false
	if not _stomps:
		rampage.sim.stats["stomp_interval"] = 100000.0
		rampage.sim._stomp_timer = 100000.0
	while rampage.sim.emerge.active:
		await process_frame
	var begin := Engine.get_process_frames()
	print(
		"capture_idle_game: run %d, time of day %s" % [_run_index, Content.time_for_run(_run_index)]
	)
	print("capture_idle_game: emerged at frame %d (%.2f s)" % [begin, float(begin) / 60.0])
	var gait: ClipAlive = rampage._kaiju._rig.gait
	var spine: Node3D = gait.rig.bone("spine2")
	var seen: Array[float] = []
	var shot_top := false
	var shot_bottom := false
	while Engine.get_process_frames() - begin < int(_seconds * 60.0):
		await process_frame
		var at := float(Engine.get_process_frames() - begin) / 60.0
		var now := gait.life.breath
		seen.append(now)
		if seen.size() > 2 and gait.life.weight >= 1.0:
			var top := seen[-2] > 0.5 and seen[-2] > seen[-1] and seen[-2] >= seen[-3]
			var bottom := seen[-1] <= 0.0001 and seen[-2] > 0.0001  # breathed out
			if top or bottom:
				print(
					(
						"capture_idle_game: breath %s at %.2f s (frame %d)"
						% ["top" if top else "bottom", at, Engine.get_process_frames()]
					)
				)
			if _shots and top and not shot_top:
				shot_top = true
				_snap(rampage, "breath_top", spine.global_position)
			if _shots and bottom and not shot_bottom:
				shot_bottom = true
				_snap(rampage, "breath_bottom", spine.global_position)
	quit()


func _snap(rampage: Rampage, shot_name: String, at: Vector3) -> void:
	var img := root.get_texture().get_image()
	img.save_png(_out.path_join("%s_%d.png" % [shot_name, _stage]))
	var centre := Kit.image_point(self, rampage._camera, at, Vector2(img.get_size()))
	Kit.crop_2x(img, centre, CROP, _out.path_join("%s_%d_2x.png" % [shot_name, _stage]))
