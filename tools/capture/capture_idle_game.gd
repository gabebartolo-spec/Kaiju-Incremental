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
var _quiet := false
var _px := false
var _run_index := 1  ## the run: its time of day is Content.time_for_run(run)


func _initialize() -> void:
	var a := Kit.args(
		{
			"out": _out,
			"stage": _stage,
			"seconds": _seconds,
			"shots": false,
			"stomps": true,
			"quiet": false,
			"px": false,
			"run": 1
		}
	)
	_out = str(a["out"])
	_stage = Num.i(a["stage"])
	_seconds = Num.f(a["seconds"])
	_shots = a["shots"]
	_stomps = a["stomps"]
	_quiet = a["quiet"]
	_px = a["px"]
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
	if _quiet:  # no tanks, no helicopters: nothing to rake, no hits, no camera shake
		rampage.sim.army_units._spawn_timer = 1.0e9
		rampage.sim.air._spawn_timer = 1.0e9
		rampage.sim.tanks.clear()
	while rampage.sim.emerge.active:
		await process_frame
	var begin := Engine.get_process_frames()
	print(
		"capture_idle_game: run %d, time of day %s" % [_run_index, Content.time_for_run(_run_index)]
	)
	print("capture_idle_game: emerged at frame %d (%.2f s)" % [begin, float(begin) / 60.0])
	var gait: ClipAlive = rampage._kaiju._rig.gait
	if _px:
		await _px_pair(rampage, gait)
		quit()
		return
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


## --px: with the world frozen at the game camera, three stills: the kaiju hidden (px_empty), the
## breath at its top (px_top: the biggest push, at the top of the curve, the lag down the back
## as played) and at rest (px_rest), so the only difference between the last two is the breath.
func _px_pair(rampage: Rampage, gait: ClipAlive) -> void:
	while gait.life.weight < 1.0:
		await process_frame
	var skin: VoxelSkin = rampage._kaiju._skin
	var cfg := Content.section("croc_idle")
	var amp: Array = cfg["skin_amp"]
	var peak := Num.f(amp[_stage]) * KaijuModel.MODEL_HEIGHT
	var lag := Num.f(cfg["skin_lag"])
	paused = true
	for pass_name: String in ["empty", "top", "rest"]:
		rampage._kaiju.visible = pass_name != "empty"
		for mat: ShaderMaterial in [skin._cubes, skin._fill]:
			mat.set_shader_parameter("breath", peak if pass_name == "top" else 0.0)
			mat.set_shader_parameter("breath_phase", 0.4)
			mat.set_shader_parameter("breath_lag", lag)
		for i: int in 4:
			await process_frame
		root.get_texture().get_image().save_png(
			_out.path_join("px_%s_%d.png" % [pass_name, _stage])
		)
	print("capture_idle_game: px stills saved (push %.3f rig units, lag %.2f)" % [peak, lag])


func _snap(rampage: Rampage, shot_name: String, at: Vector3) -> void:
	var img := root.get_texture().get_image()
	img.save_png(_out.path_join("%s_%d.png" % [shot_name, _stage]))
	var centre := Kit.image_point(self, rampage._camera, at, Vector2(img.get_size()))
	Kit.crop_2x(img, centre, CROP, _out.path_join("%s_%d_2x.png" % [shot_name, _stage]))
