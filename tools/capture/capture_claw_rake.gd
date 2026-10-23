extends SceneTree
## The croc standing still in a real rampage at the game camera (no input: the sim's own claw
## rakes, every 2 s, alternating arms, are all that happens). For the claw rake's proof: a clip of
## --seconds from the moment the rise from the river ends (pair with --write-movie), and with
## --shots 2x crops round the hit point (the claw at the load) at the load's end and at the hit
## frame -1, 0, +2 and +5 of the first rake. Everything the proof claims is measured from the clip
## (and these stills), not from the engine. Needs a window; the off-screen no_focus override.cfg.
## godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 --write-movie <dir>/rake.avi
## --script tools/capture/capture_claw_rake.gd -- --out=<dir> --stage=1 --seconds=6 [--shots]
## --stage 0 young croc, 1 Behemoth, 2 Colossus (Kit.STAGE_LEVELS)

const Kit := preload("res://tools/capture/capture_kit.gd")
const CROP := Vector2i(640, 480)
const FRAME := 1.0 / 60.0
## The stills: name -> seconds from the sim's hit (the load's end is its own).
const SHOTS := {"hit_m1": -FRAME, "hit_0": 0.0, "hit_p2": 2.0 * FRAME, "hit_p5": 5.0 * FRAME}

var _out := "user://claw_rake"
var _seconds := 6.0
var _stage := 1
var _shots := false


func _initialize() -> void:
	var a := Kit.args({"out": _out, "seconds": _seconds, "stage": _stage, "shots": false})
	_out = str(a["out"])
	_seconds = Num.f(a["seconds"])
	_stage = Num.i(a["stage"])
	_shots = a["shots"]
	DirAccess.make_dir_recursive_absolute(_out)
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var levels: Dictionary = Kit.STAGE_LEVELS[_stage]
	var stats := Kit.stats("reptilian", levels)
	stats["stomp_interval"] = 9999.0  # standing, no footstep: nothing but the rake moves the camera
	var rampage := Kit.rampage("reptilian", stats, 1)
	rampage.scripted = func(_sim: RampageSim) -> Dictionary: return {}
	root.add_child(rampage)
	await rampage.wait_loaded()
	var aim: Node3D = rampage.find_child("BreathAim", false, false)
	if aim != null:  # the breath's aim wedge is a game aid, not part of the shot
		aim.set_physics_process(false)
		aim.visible = false
	while rampage.sim.emerge.active:
		await process_frame
	print("capture_claw_rake: emerged at frame %d" % Engine.get_process_frames())
	var start := Engine.get_process_frames()
	var swing: BipedSwing = (rampage._kaiju._rig.gait as BipedGait).swing
	var taken: Array[String] = []
	while Engine.get_process_frames() - start < int(_seconds * 60.0):
		await process_frame
		if not _shots:
			continue
		var t := swing.rake_time()
		var marks := swing.rake_marks()
		var want := {"load": Num.f(marks["load_end"])}
		for shot_name: String in SHOTS:
			want[shot_name] = Num.f(marks["hit"]) + Num.f(SHOTS[shot_name])
		for shot_name: String in want:
			if t >= Num.f(want[shot_name]) and t >= 0.0 and not taken.has(shot_name):
				taken.append(shot_name)
				_snap(rampage, "stage%d_%s" % [_stage, shot_name], swing)
	print("capture_claw_rake: stills %s" % [taken])
	quit()


func _snap(rampage: Rampage, shot_name: String, swing: BipedSwing) -> void:
	var img := root.get_texture().get_image()
	img.save_png(_out.path_join(shot_name + ".png"))
	var at := swing.rake_hit() if shot_name != "stage%d_load" % _stage else swing.rake_tip()
	var centre := Kit.image_point(self, rampage._camera, at, Vector2(img.get_size()))
	Kit.crop_2x(img, centre, CROP, _out.path_join(shot_name + "_2x.png"))
