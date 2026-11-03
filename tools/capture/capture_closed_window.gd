extends SceneTree
## Closed windows (director 2026-11-03): one building of each archetype (office, brick, glass,
## stone), standing, from the game camera's angle onto its south face and from straight in front
## of it. Shows the window sash: 2x2 panes in a cross mullion, metal on towers, wood on low blocks.
## Needs a window.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_closed_window.gd -- --out=<dir> [--tag=after]

const Kit := preload("res://tools/capture/capture_kit.gd")
const SETTLE := 20
const NAMES: Array[String] = ["office", "brick", "glass", "stone"]

var _out := "user://closed_window"
var _tag := "after"
var _sim: RampageSim


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	var a := Kit.args({"out": _out, "tag": _tag})
	_out = str(a["out"])
	_tag = str(a["tag"])
	DirAccess.make_dir_recursive_absolute(_out)
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var stats := Kit.stats("reptilian", {"claws": 3}, "reptilian")
	_sim = Kit.stage_sim(stats, 1, CityGrowth.tuning_for(Content.tuning(), 1))
	_sim.time_left = 1.0e6
	var stage := Node3D.new()
	stage.add_child(CityView.new(_sim, Seeds.make("fx", 0)))
	var cam := Kit.camera(stage)
	root.add_child(stage)
	cam.current = true
	for arch: int in NAMES.size():
		var b := _pick(arch)
		if b == null:
			print("no ", NAMES[arch], " building")
			continue
		var face := Vector3(b.x, b.height * 0.55, b.z + b.d * 0.5)
		_sim.kaiju_pos = Vector2(face.x, face.z + 20.0)
		cam.position = face + CameraTuning.offset().normalized() * maxf(b.height * 1.6, 18.0)
		cam.look_at(face)
		await Kit.frames(self, SETTLE)
		_shot("%s_%s_game" % [NAMES[arch], _tag])
		cam.position = face + Vector3(0.0, 0.0, 7.0)
		cam.look_at(face)
		await Kit.frames(self, SETTLE)
		_shot("%s_%s_front" % [NAMES[arch], _tag])
	quit()


## The first standing building of archetype `arch`, 5 floors or more, not a landmark.
func _pick(arch: int) -> RampageSim.Building:
	for b: RampageSim.Building in _sim.buildings:
		if b.landmark == "" and b.style % 4 == arch and b.height >= 5 and b.base == 0:
			return b
	return null


func _shot(shot_name: String) -> void:
	print("saved ", Kit.still(self, _out, shot_name))
