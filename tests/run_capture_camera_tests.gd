extends "res://tests/lib/runner.gd"
## Capture camera suite (director 2026-10-26, "that isnt the game camera angle, again"): a capture
## tool shows the player's view. For the hatchling and the adult, the camera a tool hand-builds
## (Kit.place_game_camera) lands within 0.5 m and 0.5 deg of the real Rampage's own camera at
## rest; the camera a tool reads off a loaded rampage (Kit.game_camera) is the rampage's node; and
## no tool under tools/capture keeps its own camera numbers (the old offset 0,27,19, FOV 55).
## Seeded by design: city seed 0, run 0, no input, time stepped by the fixed frame clock.
##   godot --headless --path . --script tests/run_capture_camera_tests.gd

const Kit := preload("res://tools/capture/capture_kit.gd")
const SPECIES := "reptilian"
const MAX_M := 0.5
const MAX_DEG := 0.5
const SETTLE_FRAMES := 240
## The run's opening (the rise from the sea bay, RunIntro) holds the sim back and has its own
## shot; "at rest" starts when it is over. The cap is far above the longest opening.
const RISE_CAP_FRAMES := 3000
## Camera numbers a tool must take from CameraTuning instead.
const STALE := ["Vector3(0, 27, 19)", "fov = 55"]


func suite_name() -> String:
	return "Capture camera"


func run_checks() -> void:
	await _t("_check_hatchling")
	await _t("_check_adult")
	await _t("_check_tools_keep_no_camera_numbers")


func _check_hatchling() -> void:
	await _compare({}, 0, "hatchling")


func _check_adult() -> void:
	await _compare(Kit.STAGE_LEVELS[2], 3, "adult")


## A real rampage at `levels` standing still, against a hand-built rig for the same body.
func _compare(levels: Dictionary, tier: int, label: String) -> void:
	var stats := Kit.stats(SPECIES, levels, SPECIES)
	var layout: Array[Dictionary] = []
	if tier > 0:
		layout = CityGrowth.layout(Content.tuning(), tier, Seeds.make("city", 0))
	var rampage := Kit.rampage(SPECIES, stats, 0, layout)
	rampage.scripted = func(_sim: RampageSim) -> Dictionary: return {}
	root.add_child(rampage)
	await rampage.wait_loaded()
	var waited := 0
	while rampage.sim.emerge.active and waited < RISE_CAP_FRAMES:
		await physics_frame
		waited += 1
	check(
		not rampage.sim.emerge.active,
		"%s: the rise is over before the cameras are compared" % label
	)
	for _i: int in SETTLE_FRAMES:
		await process_frame
	var motion := PlayerSettings.camera_motion
	PlayerSettings.camera_motion = 0.0  # at rest: a landing's shake is not the camera's rest
	rampage._place_camera(0.0)
	PlayerSettings.camera_motion = motion
	var game := Kit.game_camera(self)
	check(game == rampage._camera, "%s: Kit.game_camera is the rampage's own camera" % label)
	var rig := Camera3D.new()
	root.add_child(rig)
	Kit.place_game_camera(rig, rampage._kaiju, rampage.sim.body_scale())
	var moved := rig.global_position.distance_to(game.global_position)
	var turned := rad_to_deg((-rig.global_basis.z).angle_to(-game.global_basis.z))
	var fov := absf(rig.fov - game.fov)
	check(
		moved < MAX_M and turned < MAX_DEG and fov < MAX_DEG,
		(
			"%s: tool camera %.2f m, %.2f deg, %.2f fov off the game's (body %.2f)"
			% [label, moved, turned, fov, rampage.sim.body_scale()]
		)
	)
	rig.queue_free()
	rampage.queue_free()
	await process_frame


func _check_tools_keep_no_camera_numbers() -> void:
	var bad: Array[String] = []
	var dir := DirAccess.open("res://tools/capture")
	var scanned := 0
	for file: String in dir.get_files():
		if not file.ends_with(".gd"):
			continue
		scanned += 1
		var text := FileAccess.get_file_as_string("res://tools/capture/" + file)
		for stale: String in STALE:
			if text.contains(stale):
				bad.append("%s has %s" % [file, stale])
	check(
		scanned > 10 and bad.is_empty(),
		"%d capture tools, stale camera numbers: %s" % [scanned, bad]
	)
