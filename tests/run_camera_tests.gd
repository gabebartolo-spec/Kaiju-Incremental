extends "res://tests/lib/runner.gd"
## Camera suite: the gameplay camera's shake (CameraShake, R 19.2). Trauma stacks to its cap and
## fades; the turn is trauma squared on smooth noise, never past tuning "camera_shake" max_deg,
## larger for a bigger body, faded with distance; a 0% camera-motion setting gives no motion in
## a real rampage, and a full one turns the camera (no roll, no move) within the cap.
## Seeded by design: the shake's noise has its own fixed seed and time is stepped by hand.
##   godot --headless --path . --script tests/run_camera_tests.gd

const BABY := 0.5  # body scales of stage 1 and stage 4 (19-camera research table)
const ADULT := 1.7
const FRAME := 1.0 / 60.0


func suite_name() -> String:
	return "Camera"


func run_checks() -> void:
	await _t("_check_stacks_and_caps")
	await _t("_check_decays")
	await _t("_check_turn")
	await _t("_check_falloff")
	await _t("_check_rampage")


func _cfg() -> Dictionary:
	return Content.section("camera_shake")


func _check_stacks_and_caps() -> void:
	var shake := CameraShake.new()
	for _i: int in 3:
		shake.add(shake.source("stomp"), Vector3.INF, Vector3.ZERO, ADULT)
	var three := shake.trauma
	shake.add(shake.source("topple"), Vector3.INF, Vector3.ZERO, ADULT)
	shake.add(shake.source("topple"), Vector3.INF, Vector3.ZERO, ADULT)
	check(
		is_equal_approx(three, shake.source("stomp") * 3.0) and shake.trauma == 1.0,
		"hits stack (3 stomps = %.2f trauma) up to a cap of 1 (%.2f)" % [three, shake.trauma]
	)


func _check_decays() -> void:
	var shake := CameraShake.new()
	shake.add(1.0, Vector3.INF, Vector3.ZERO, ADULT)
	var levels: Array[float] = []
	for _i: int in 4:
		shake.update(0.25)
		levels.append(snappedf(shake.trauma, 0.001))
	var falling := range(1, levels.size()).all(
		func(i: int) -> bool: return levels[i] < levels[i - 1]
	)
	var gone := 1.0 / Num.f(_cfg()["decay_per_s"])
	shake.update(gone)
	check(
		falling and levels[0] < 1.0 and shake.trauma == 0.0,
		"trauma fades every frame (%s) and is gone within %.2f s" % [levels, gone]
	)


func _check_turn() -> void:
	var shake := CameraShake.new()
	var cap := deg_to_rad(Num.f(_cfg()["max_deg"]))
	shake.add(1.0, Vector3.INF, Vector3.ZERO, ADULT)
	var full := 0.0
	var half := 0.0
	for _i: int in 120:
		shake.trauma = 1.0
		shake.update(FRAME)
		full = maxf(full, shake.turn(ADULT, 1.0).length())
		shake.trauma = 0.5
		half = maxf(half, shake.turn(ADULT, 1.0).length())
	shake.trauma = 1.0
	var off := shake.turn(ADULT, 0.0)
	var coarse := _largest_step(FRAME)
	var fine := _largest_step(FRAME / 4.0)
	check(
		full > 0.0 and full <= cap and fine < coarse * 0.4,
		(
			(
				"full trauma turns the camera up to %.2f deg (cap %.2f), on smooth noise (largest"
				+ " step %.3f deg a 60 fps frame, %.3f at 240 fps)"
			)
			% [rad_to_deg(full), rad_to_deg(cap), rad_to_deg(coarse), rad_to_deg(fine)]
		)
	)
	check(
		half > 0.0 and half <= shake.max_turn(ADULT) * 0.25 + 0.0001,
		"half trauma turns a quarter as far (trauma squared): %.3f deg" % rad_to_deg(half)
	)
	check(
		shake.max_turn(ADULT) > shake.max_turn(BABY) and shake.max_turn(ADULT) <= cap,
		(
			"an adult shakes harder than a baby (%.2f vs %.2f deg), within the cap"
			% [rad_to_deg(shake.max_turn(ADULT)), rad_to_deg(shake.max_turn(BABY))]
		)
	)
	check(off == Vector2.ZERO, "a 0%% camera-motion setting turns nothing: %s" % off)


## The largest change of the turn between two frames dt apart over two seconds at full trauma:
## smooth noise changes less in a shorter frame, white noise redrawn each frame does not.
func _largest_step(dt: float) -> float:
	var shake := CameraShake.new()
	var step := 0.0
	var before := Vector2.ZERO
	for i: int in roundi(2.0 / dt):
		shake.trauma = 1.0
		shake.update(dt)
		var now := shake.turn(ADULT, 1.0)
		if i > 0:
			step = maxf(step, (now - before).length())
		before = now
	return step


func _check_falloff() -> void:
	var near := CameraShake.new()
	var far := CameraShake.new()
	var mid := CameraShake.new()
	var reach := Num.f(_cfg()["far_per_scale"]) * ADULT
	near.add(0.5, Vector3(5, 0, 0), Vector3.ZERO, ADULT)
	mid.add(0.5, Vector3(reach * 0.7, 0, 0), Vector3.ZERO, ADULT)
	far.add(0.5, Vector3(reach + 1.0, 0, 0), Vector3.ZERO, ADULT)
	check(
		near.trauma == 0.5 and mid.trauma > 0.0 and mid.trauma < 0.5 and far.trauma == 0.0,
		(
			(
				"a hit at the kaiju shakes fully (%.2f), one across the city less (%.2f), one out of"
				+ " reach not at all (%.2f)"
			)
			% [near.trauma, mid.trauma, far.trauma]
		)
	)


## A real rampage's camera: at 0% motion full trauma leaves it exactly where it was; at 100% it
## turns (yaw and pitch, no roll) within the cap and does not move.
func _check_rampage() -> void:
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades())
	)
	var rampage := Rampage.new()
	rampage.setup(
		species, stats, CityGen.generate(Seeds.make("city", 0), Content.section("city")), 0
	)
	root.add_child(rampage)
	for _i: int in 30:
		await process_frame
	var camera := rampage._camera
	var saved := PlayerSettings.camera_motion
	rampage.shake.trauma = 0.0
	rampage._place_camera(0.0)
	var rest := camera.global_transform
	rampage.shake.update(0.37)  # off the noise's zero at time 0
	rampage.add_trauma(1.0)
	PlayerSettings.camera_motion = 0.0
	rampage._place_camera(0.0)
	var still := camera.global_transform
	PlayerSettings.camera_motion = 1.0
	rampage._place_camera(0.0)
	var shaken := camera.global_transform
	PlayerSettings.camera_motion = saved
	var turned := rest.basis.get_rotation_quaternion().angle_to(
		shaken.basis.get_rotation_quaternion()
	)
	var cap := deg_to_rad(Num.f(_cfg()["max_deg"]))
	check(
		still.is_equal_approx(rest),
		"at 0%% camera motion full trauma leaves the camera still (%s vs %s)" % [still, rest]
	)
	check(
		(
			turned > 0.0
			and turned <= cap + 0.0001
			and absf(shaken.basis.x.y) < 0.001
			and shaken.origin.is_equal_approx(rest.origin)
		),
		(
			"at 100%% full trauma turns the camera %.2f deg (cap %.2f), no roll (%.4f), no move"
			% [rad_to_deg(turned), rad_to_deg(cap), shaken.basis.x.y]
		)
	)
	rampage.free()
