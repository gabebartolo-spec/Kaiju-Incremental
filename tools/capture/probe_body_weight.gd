extends SceneTree
## Measures how a kaiju's weight reads in a real autoplayed rampage (the flow test's city, seed 0,
## as capture_rampage_kaiju.gd records it): per physics frame, the gait's state, the body's yaw
## and its rate, each foot plant, the camera's footfall dip and shake trauma, the tail tip's swing
## off the body's long axis and the neck's turn from the body (D-200). Writes a CSV for the motion
## checks (Komodo test, D-193). Headless is fine.
##
##   godot --headless --path . --fixed-fps 60 --script tools/capture/probe_body_weight.gd -- \
##     --species=reptilian --stage=2 --seconds=12 --out=<file.csv>

const Kit := preload("res://tools/capture/capture_kit.gd")

var _species := "reptilian"
var _seconds := 12.0
var _stage := 2
var _out := "user://body_weight.csv"
var _plants: Array[String] = []


func _initialize() -> void:
	var a := Kit.args({"species": _species, "seconds": _seconds, "stage": _stage, "out": _out})
	_species = str(a["species"])
	_seconds = Num.f(a["seconds"])
	_stage = Num.i(a["stage"])
	_out = str(a["out"])
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var levels: Dictionary = Kit.STAGE_LEVELS[_stage] if _stage >= 0 else {}
	var rampage := Kit.autoplay(self, _species, Kit.stats(_species, levels), 0)
	await physics_frame
	var kaiju: KaijuModel = rampage._kaiju
	kaiju.foot_planted.connect(_on_plant)
	var rig: KaijuRig = kaiju._rig
	var f := FileAccess.open(_out, FileAccess.WRITE)
	f.store_line(
		"t,state,clip_t,speed,heading_deg,body_yaw_deg,plants,dip,trauma,cam_y,tail_tip_x,scale,neck_deg"
	)
	var frames := 0
	while frames < int(_seconds * 60.0) and not rampage.sim.over:
		_plants.clear()
		await physics_frame
		frames += 1
		var gait := rig.gait
		var state := ""
		var clip_t := 0.0
		var neck := 0.0
		if gait is ClipGait:
			state = (gait as ClipGait).state
			clip_t = (gait as ClipGait).clip_time
			neck = (gait as ClipGait)._look
		var tip := rig.to_local(rig.tail_world("tail8"))
		var row := [
			"%.4f" % (frames / 60.0),
			state,
			"%.2f" % clip_t,
			"%.3f" % gait.speed,
			"%.2f" % rad_to_deg(gait.model_yaw),
			"%.2f" % rad_to_deg(gait.body_yaw),
			" ".join(_plants),
			"%.4f" % (rampage._step_dip + rampage._heavy_dip),
			"%.4f" % rampage.shake.trauma,
			"%.4f" % rampage._camera.global_position.y,
			"%.3f" % (tip.x * rig.global_transform.basis.get_scale().x),
			"%.3f" % rampage.sim.body_scale(),
			"%.2f" % rad_to_deg(neck),
		]
		f.store_line(",".join(row))
	f.close()
	print("probe: %d frames -> %s" % [frames, ProjectSettings.globalize_path(_out)])
	quit()


func _on_plant(side: String, strength: float, _at: Vector3) -> void:
	_plants.append("%s:%.2f" % [side, strength])
