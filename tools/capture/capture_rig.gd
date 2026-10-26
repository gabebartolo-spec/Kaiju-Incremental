extends SceneTree
## Records a rigged kaiju walking, stopping and roaring on a plain stage, for checking the rig,
## the walk and the tail physics. Needs a window and --write-movie.
##
##   godot --path . --resolution 1280x720 --windowed --write-movie <out.avi> --fixed-fps 30 \
##     --script tools/capture/capture_rig.gd -- --species=reptilian --stage=adult

var _species := "reptilian"
var _stage := "adult"


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--species="):
			_species = arg.substr(10)
		elif arg.begins_with("--stage="):
			_stage = arg.substr(8)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var empty: Array[Dictionary] = []
	var sim := RampageSim.new({}, Content.tuning(), empty, Seeds.make("army", 0))
	var stage := Node3D.new()
	stage.add_child(CityView.new(sim, Seeds.make("fx", 0), false))
	var colors: Dictionary = Content.species_def(_species)["colors"]
	var kaiju := KaijuModel.new(_species, colors, _stage)
	stage.add_child(kaiju)
	var cam := Camera3D.new()
	cam.fov = 45.0
	stage.add_child(cam)
	root.add_child(stage)
	var frames := 0
	while frames < 30 * 9:
		var t := frames / 30.0
		var moving := 1.0 if t < 4.0 else 0.0
		if t >= 4.0 and t < 4.05:
			kaiju.roar()
		kaiju.rotation.y = t * 0.5 if t < 4.0 else 2.0 + (t - 4.0) * 0.15
		cam.position = Vector3(16, 9, 16)
		cam.look_at(Vector3(0, 4.5, 0))
		kaiju.animate(1.0 / 30.0, moving)
		await process_frame
		frames += 1
	quit()
