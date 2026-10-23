extends SceneTree
## The croc titan standing on a plain stage (D-165, the living predator): stills at chosen times
## from a close camera on the head, the back, or the side, and per-stage numbers. Needs a window;
## fixed frame clock.
##
##   godot --path . --resolution 1280x720 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_idle_life.gd -- --stage=adult --cam=back \
##     --times=1,3.5,6 --out=<dir> [--life=0]
##
## --cam: head (front three-quarter, the eyes), back (the game camera's side), side.
## --lids=1 holds the lids shut (2: magenta), to check which cubes are the eyes.
## --life=0 turns the life layer off (the plain baked idle) to compare.

const Kit := preload("res://tools/capture/capture_kit.gd")
const DT := 1.0 / 60.0

var _stage := "adult"
var _cam := "back"
var _times: Array[float] = [1.0, 3.0]
var _out := "user://idle_life"
var _life := true
var _lids := 0.0
var _rest := false
var _peaks := false


func _initialize() -> void:
	var a := Kit.args(
		{
			"stage": _stage,
			"cam": _cam,
			"times": "1,3",
			"out": _out,
			"life": 1,
			"lids": 0.0,
			"rest": 0,
			"peaks": 0
		}
	)
	_stage = str(a["stage"])
	_cam = str(a["cam"])
	_out = str(a["out"])
	_life = Num.i(a["life"]) != 0
	_lids = Num.f(a["lids"])
	_rest = Num.i(a["rest"]) != 0
	_peaks = Num.i(a["peaks"]) != 0
	_times.clear()
	for part: String in str(a["times"]).split(","):
		_times.append(part.to_float())
	DirAccess.make_dir_recursive_absolute(_out)
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var empty: Array[Dictionary] = []
	var sim := RampageSim.new({}, Content.tuning(), empty, Seeds.make("army", 0))
	var stage := Node3D.new()
	stage.add_child(CityView.new(sim, Seeds.make("fx", 0), false))
	var colors: Dictionary = Content.species_def("reptilian")["colors"]
	var kaiju := KaijuModel.new("reptilian", colors, _stage)
	stage.add_child(kaiju)
	var cam := Camera3D.new()
	cam.fov = 40.0
	stage.add_child(cam)
	root.add_child(stage)
	var rig: KaijuRig = kaiju.find_children("*", "KaijuRig", true, false)[0]
	var gait: ClipAlive = rig.gait
	gait.life_on = _life
	var last: float = _times.max()
	var frames := 0
	var next := 0
	var seen: Array[float] = []  # --peaks: the breath, to catch its top and its bottom
	var shot_max := false
	var shot_min := false
	while float(frames) * DT <= (30.0 if _peaks else last + DT):
		if _rest:  # the bind pose, to measure positions in the baked skin
			for bone_name: String in rig.bone_names():
				rig.bone(bone_name).transform = rig.rest_of(bone_name)
			kaiju._skin.sync()
		else:
			kaiju.animate(DT, 0.0)
		if _lids > 0.0:  # debug: the lids held shut, to see which cubes are the eyes
			var skin: VoxelSkin = kaiju._skin
			skin.blink = minf(_lids, 1.0)
			if _lids > 1.5:  # 2: and the lid magenta, so the eye cubes stand out
				skin._cubes.set_shader_parameter("lid_colour", Vector3(1.0, 0.0, 1.0))
			skin.sync()
		_aim(cam, kaiju)
		await process_frame
		var t := float(frames) * DT
		if next < _times.size() and t >= _times[next]:
			var img := root.get_texture().get_image()
			img.save_png(_out.path_join("%s_%s_%.2f.png" % [_stage, _cam, _times[next]]))
			next += 1
		if _peaks and gait.life.weight >= 1.0:
			seen.append(gait.life.breath)
			if (
				seen.size() > 2
				and not shot_max
				and seen[-2] > 0.8
				and seen[-2] > seen[-1]
				and seen[-2] >= seen[-3]
			):
				shot_max = true
				_still(kaiju, "peak", t)
			if (
				seen.size() > 2
				and not shot_min
				and seen[-2] < -0.8
				and seen[-2] < seen[-1]
				and seen[-2] <= seen[-3]
			):
				shot_min = true
				_still(kaiju, "trough", t)
		if _peaks and shot_max and shot_min:
			break
		frames += 1
	print(
		(
			"capture_idle_life: %s done, breath %.3f blink %.2f"
			% [_stage, gait.life.breath, gait.life.blink]
		)
	)
	print("head1 ", rig.bone("head1").global_position)
	quit()


func _still(_kaiju: KaijuModel, label: String, t: float) -> void:
	var img := root.get_texture().get_image()
	img.save_png(_out.path_join("%s_%s_%s.png" % [_stage, _cam, label]))
	print("capture_idle_life: %s at %.2f s" % [label, t])


func _aim(cam: Camera3D, kaiju: KaijuModel) -> void:
	var rig: KaijuRig = kaiju.find_children("*", "KaijuRig", true, false)[0]
	var head := rig.bone("head1").global_position
	var chest := rig.bone("spine2").global_position
	match _cam:
		"head":
			cam.global_position = head + Vector3(4.5, 1.0, -5.5)
			cam.look_at(head + Vector3(0, 0.0, -0.3))
		"side":
			cam.global_position = chest + Vector3(16, 1.0, 0)
			cam.look_at(chest + Vector3(0, -1.0, 0))
		_:
			cam.global_position = chest + Vector3(0, 9.0, 16.0)
			cam.look_at(chest + Vector3(0, -0.5, 0))
