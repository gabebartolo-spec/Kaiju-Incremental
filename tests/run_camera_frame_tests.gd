extends "res://tests/lib/runner.gd"
## Camera framing suite (D-121 review): the follow keeps the kaiju's distance while it walks along
## the view (no zoom bob), and HeadFrame tilts the aim up so a drawn head that would ride into the
## frame's top margin stays below camera.safe_top, while a head already in frame changes nothing.
## The follow and the tilt are critically damped (Damped): a target that jumps moves the camera up
## to speed over many frames, within the acceleration cap, never overshooting. The fade's sight
## points include the drawn body (HeadFrame.sight): a tower over the drawn head fades, though the
## sim's own points stop short of the snout.
## Seeded by design: no randomness; the pose is the rig's rest pose, time stepped by hand.
##   godot --headless --path . --script tests/run_camera_frame_tests.gd

const FRAME := 1.0 / 60.0


func suite_name() -> String:
	return "Camera framing"


func run_checks() -> void:
	await _t("_check_follow_keeps_distance")
	await _t("_check_head_room")
	await _t("_check_damped")
	await _t("_check_drawn_sight")


## A body walking 36 units/s straight at the camera: the eye stays one offset length from it every
## frame (the old lag put it 3 units nearer). A body walking across the view still trails.
func _check_follow_keeps_distance() -> void:
	var offset := Vector3(0, 30, 56)
	var follow := CameraFollow.new(Vector3.ZERO, offset)
	var worst := 0.0
	var body := Vector3.ZERO
	for _i: int in 90:
		body += Vector3(0, 0, 36.0 * FRAME)
		follow.step(body, offset, FRAME)
		worst = maxf(worst, absf(follow.eye().distance_to(body) - offset.length()))
	check(worst < 0.001, "walking along the view the eye holds %.4f of its distance" % worst)
	var side := CameraFollow.new(Vector3.ZERO, offset)
	side.step(Vector3(10, 0, 0), offset, FRAME)
	check(side.focus.x > 0.0 and side.focus.x < 10.0, "across the view the aim still eases in")


## An adult croc seen close from its front: without the tilt its highest drawn point is inside the
## top margin; with it the point sits at or below safe_top of the frame, and a distant view (the
## head far from the margin) needs no tilt.
func _check_head_room() -> void:
	var def: Dictionary = Content.species_def("reptilian")
	var colors: Dictionary = def["colors"]
	var kaiju := KaijuModel.new("reptilian", colors, "adult")
	root.add_child(kaiju)
	var camera := Camera3D.new()
	camera.fov = CameraTuning.fov()
	root.add_child(camera)
	var frame := HeadFrame.new(kaiju)
	var view := Vector2(camera.fov, 0.0)
	var feet := kaiju.focus()
	var top := frame.points().size() > 0
	check(top, "the adult croc's bone boxes give corners to frame")
	var safe := Num.f(Content.section("camera")["safe_top"])
	var far := feet + Vector3(0, 30, 100)
	var near := feet + Vector3(0, 5, 20)
	camera.global_position = near
	camera.look_at(feet)
	var before := _top_fraction(camera, frame)
	var aim := Vector3.ZERO
	for _i: int in 120:  # two seconds: the tilt is critically damped
		aim = frame.aim(near, feet, view, FRAME)
	camera.look_at(aim)
	var after := _top_fraction(camera, frame)
	check(before < safe, "close up the head rides into the margin (%.3f of the height)" % before)
	check(after >= safe - 0.002, "tilted it sits %.3f from the top (safe %.2f)" % [after, safe])
	var calm := HeadFrame.new(kaiju)
	camera.global_position = far
	camera.look_at(feet)
	var untouched := calm.aim(far, feet, view, FRAME)
	check(
		calm.tilt == 0.0 and untouched.is_equal_approx(feet),
		"a head well inside the frame is not tilted"
	)
	var nod := HeadFrame.new(kaiju)
	for _i: int in 120:
		nod.aim(near, feet, Vector2(camera.fov, 0.05), FRAME)
	check(nod.tilt < frame.tilt, "a shake pitching the view up lowers the tilt needed")
	camera.free()
	kaiju.free()


## The highest drawn corner's distance from the frame's top, as a fraction of its height.
func _top_fraction(camera: Camera3D, frame: HeadFrame) -> float:
	var height := float(root.get_visible_rect().size.y)
	var best := INF
	for p: Vector3 in frame.points():
		if not camera.is_position_behind(p):
			best = minf(best, camera.unproject_position(p).y)
	return best / height


## A target that jumps 10 units: the follower never overshoots, its first frame moves almost
## nothing (no pop), its speed grows over many frames, and a cap on acceleration is kept.
func _check_damped() -> void:
	var free := Damped.new()
	var worst := 0.0
	var first := 0.0
	var peak_at := 0
	var peak := 0.0
	for f: int in 180:
		free.step(Vector3(10, 0, 0), 0.3, 0.0, FRAME)
		worst = maxf(worst, free.value.x)
		if f == 0:
			first = free.value.x
		if free.velocity.x > peak:
			peak = free.velocity.x
			peak_at = f
	check(worst <= 10.0001 and free.value.x > 9.9, "it settles on the target without overshoot")
	check(first < 0.1, "the first frame after a jump moves %.3f of 10 units" % first)
	check(peak_at >= 6, "the speed peaks after %d frames (an ease of many frames)" % peak_at)
	var capped := Damped.new()
	var jump := 0.0
	var last := 0.0
	for _i: int in 120:
		capped.step(Vector3(10, 0, 0), 0.3, 100.0, FRAME)
		jump = maxf(jump, absf(capped.velocity.x - last))
		last = capped.velocity.x
	check(jump <= 100.0 * FRAME + 0.0001, "a capped follower changes speed by %.3f a frame" % jump)


## The sim's sight points sit a body radius or two ahead of the hips, short of the croc's drawn
## snout; the drawn points reach it, so a tower standing between the camera and it fades.
func _check_drawn_sight() -> void:
	var def: Dictionary = Content.species_def("reptilian")
	var colors: Dictionary = def["colors"]
	var kaiju := KaijuModel.new("reptilian", colors, "adult")
	root.add_child(kaiju)
	var frame := HeadFrame.new(kaiju)
	var points := frame.sight()
	check(points.size() >= 27, "the drawn body gives sight points (%d)" % points.size())
	var rig: KaijuRig = kaiju.find_children("*", "KaijuRig", true, false)[0]
	var snout := rig.bone("head1").global_position
	var eye := snout + Vector3(0, 6, 30)
	var tower := RampageSim.Building.new()
	tower.w = 2
	tower.d = 2
	tower.height = 60
	tower.x = snout.x + (eye.x - snout.x) * 0.5
	tower.z = snout.z + (eye.z - snout.z) * 0.5
	var front := BuildingFade.blocks(eye, points, tower)
	tower.x += 20.0
	var beside := BuildingFade.blocks(eye, points, tower)
	check(front and not beside, "a tower over the drawn snout fades, one 20 units aside does not")
	kaiju.free()
