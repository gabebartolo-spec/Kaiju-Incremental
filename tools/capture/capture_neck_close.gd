extends SceneTree
## Comments #32/#33: the croc's neck close up, walking, with the head looking straight ahead and
## then thrown into the sharpest look-ahead each way (turn_ahead past HEAD_LEAD_MAX), from the side
## and above. One still per stage and look in --out. Off-screen GPU render (no_focus override.cfg).
##   godot --path . --resolution 1280x720 --windowed --script tools/capture/capture_neck_close.gd -- --out=<dir>

const LOOKS: Array[float] = [0.0, 3.0, -3.0]
const SETTLE := 60

var _out := "user://neck_close"


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var colors: Dictionary = Content.species_def("reptilian")["colors"]
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -30, 0)
	root.add_child(light)
	for stage: String in ["baby", "adolescent", "adult"]:
		var kaiju := KaijuModel.new("reptilian", colors, stage)
		root.add_child(kaiju)
		var cam := Camera3D.new()
		root.add_child(cam)
		cam.current = true
		for look: float in LOOKS:
			kaiju.position = Vector3.ZERO
			for i: int in SETTLE:
				kaiju.position.z -= 0.09  # a walk (5.4 u/s)
				kaiju.animate(1.0 / 60.0, 1.0, look)
				await physics_frame
			var head := kaiju._rig.bone("head0").global_position
			cam.global_position = head + Vector3(7, 4, 3) * kaiju.scale.x
			cam.look_at(head, Vector3.UP)
			await process_frame
			await process_frame
			root.get_texture().get_image().save_png("%s/%s_look%+.0f.png" % [_out, stage, look])
		kaiju.queue_free()
		cam.queue_free()
	quit()
