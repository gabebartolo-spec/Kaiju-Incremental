extends "res://tests/lib/runner.gd"
## Camera framing suite (D-121 review): the follow keeps the kaiju's distance while it walks along
## the view (no zoom bob), and HeadFrame tilts the aim up so a drawn head that would ride into the
## frame's top margin stays below camera.safe_top, while a head already in frame changes nothing.
## The follow and the tilt are critically damped (Damped): a target that jumps moves the camera up
## to speed over many frames, within the acceleration cap, never overshooting.
## Seeded by design: no randomness; the pose is the rig's rest pose, time stepped by hand.
##   godot --headless --path . --script tests/run_camera_frame_tests.gd

const FRAME := 1.0 / 60.0


func suite_name() -> String:
	return "Camera framing"


func run_checks() -> void:
	await _t("_check_follow_keeps_distance")
	await _t("_check_head_room")
	await _t("_check_damped")
	await _t("_check_bubble")
	await _t("_check_no_screen_door")


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


## The camera bubble (CameraBubble, director 2026-10-26): its radius is camera.bubble_share of the
## camera-to-kaiju distance and clears everything near the camera in every direction (the shaders'
## test is the same distance); a point inside is not drawn, one outside is fully solid.
func _check_bubble() -> void:
	var share := Num.f(Content.section("camera")["bubble_share"])
	check(
		is_equal_approx(CameraBubble.target(50.0), 50.0 * share)
		and is_equal_approx(CameraBubble.target(100.0), 2.0 * CameraBubble.target(50.0)),
		"the radius is %.2f of the camera-to-kaiju distance and scales with it" % share
	)
	var eye := Vector3(0, 20, 40)
	var radius := CameraBubble.target(eye.distance_to(Vector3.ZERO))
	var dirs := [Vector3.LEFT, Vector3.RIGHT, Vector3.UP, Vector3.DOWN, Vector3.BACK]
	dirs.append(Vector3.FORWARD)
	var all_sides := true
	for dir: Vector3 in dirs:
		var inside: bool = CameraBubble.hides(eye + dir * radius * 0.9, eye, radius)
		var outside: bool = CameraBubble.hides(eye + dir * radius * 1.1, eye, radius)
		all_sides = all_sides and inside and not outside
	check(all_sides, "a point 0.9 radius from the camera is cut away and 1.1 stays, on every side")
	var bubble := CameraBubble.new()
	bubble.update(eye, Vector3.ZERO, FRAME)
	var first := bubble.radius()
	check(is_equal_approx(first, radius), "the radius starts at its size on the first frame")
	var far := Vector3(0, 20, 140)
	bubble.update(far, Vector3.ZERO, FRAME)
	var step := bubble.radius() - first
	var want := CameraBubble.target(far.distance_to(Vector3.ZERO))
	var eased := step > 0.0 and step < (want - first) * 0.5
	check(eased, "a zoom eases the radius, no pop (%.2f)" % step)
	for _i: int in 60:
		bubble.update(far, Vector3.ZERO, FRAME)
	check(is_equal_approx(bubble.radius(), want), "the radius settles on the new size")


## Nothing draws a screen door any more: no shader has the dither path, the baked building shader
## and the voxel shader both read the bubble, a plain voxel material (the kaiju) is not cut by it,
## and the old tuning keys are gone.
func _check_no_screen_door() -> void:
	var dir := DirAccess.open("res://scenes")
	var clean := true
	for file: String in dir.get_files():
		if file.ends_with(".gdshader"):
			var code := (load("res://scenes/" + file) as Shader).code
			if code.contains("BAYER") or code.contains("DITHER") or code.contains("float opacity"):
				clean = false
				push_error("%s still has the dither path" % file)
	check(clean, "no shader in scenes/ keeps the screen-door dither")
	for path: String in ["res://scenes/building_baked.gdshader", "res://scenes/voxel.gdshader"]:
		check((load(path) as Shader).code.contains("bubble_radius"), "%s reads the bubble" % path)
	var kaiju_mat := Look.voxel_material(0.0)
	var cut: Variant = kaiju_mat.get_shader_parameter("bubble_on")
	check(
		cut == null or Num.f(cut) == 0.0, "a plain voxel material (the kaiju's) is never cut by it"
	)
	var cam := Content.section("camera")
	check(
		not cam.has("fade_opacity") and not cam.has("fade_width"),
		"the dead camera.fade_opacity and fade_width are gone"
	)
	check(
		not Content.section("vehicles").has("fade_opacity"), "vehicles.fade_opacity is gone as well"
	)
