extends "res://tests/lib/runner.gd"
## Camera framing suite (D-121 review): the follow keeps the kaiju's distance while it walks along
## the view (no zoom bob), and HeadFrame tilts the aim up so a drawn head that would ride into the
## frame's top margin stays below camera.safe_top, while a head already in frame changes nothing.
## The follow and the tilt are critically damped (Damped): a target that jumps moves the camera up
## to speed over many frames, within the acceleration cap, never overshooting.
## Seeded by design: no randomness; the pose is the rig's rest pose, time stepped by hand.
##   godot --headless --path . --script tests/run_camera_frame_tests.gd

const BubbleReplay := preload("res://tests/lib/bubble_replay.gd")

const FRAME := 1.0 / 60.0
const ASPECT := 16.0 / 9.0


func suite_name() -> String:
	return "Camera framing"


func run_checks() -> void:
	await _t("_check_follow_keeps_distance")
	await _t("_check_turns_behind")
	await _t("_check_swing")
	await _t("_check_head_room")
	await _t("_check_damped")
	await _t("_check_bubble")
	await _t("_check_bubble_picks")
	await _t("_check_frame_share")
	await _h("BubbleReplay", func() -> void: BubbleReplay.new(check).run())
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


## D-330: he turns to face east; with the turn the eye ends behind him (west of him), never in
## one frame; without step_yaw (the old fixed offset) it stays south, at his side.
func _check_turns_behind() -> void:
	var offset := Vector3(0, 16, 30)
	var follow := CameraFollow.new(Vector3.ZERO, offset)
	follow.step_yaw(Vector2(0, -1), 0.0, true)
	var fixed := CameraFollow.new(Vector3.ZERO, offset)
	follow.step_yaw(Vector2(1, 0), FRAME)
	check(follow.eye().x > -offset.z * 0.2, "one frame after the turn the camera has barely moved")
	for _i: int in 600:
		follow.step_yaw(Vector2(1, 0), FRAME)
		follow.step(Vector3.ZERO, offset, FRAME)
		fixed.step(Vector3.ZERO, offset, FRAME)
	var eye := follow.eye()
	check(eye.x < -offset.z * 0.99 and absf(eye.z) < 0.5, "on: the eye sits behind him, %s" % eye)
	check(fixed.eye().z > offset.z * 0.99, "off: the fixed offset stays at his side")


## D-259: a long swing stops at swing_deg off behind him; let go, it eases back behind him.
## Without step_swing the eye never leaves behind him.
func _check_swing() -> void:
	var offset := Vector3(0, 16, 30)
	var follow := CameraFollow.new(Vector3.ZERO, offset)
	for _i: int in 120:
		follow.step_swing(0.05, FRAME)
	var limit := deg_to_rad(Num.f(Content.section("camera")["swing_deg"]))
	check(is_equal_approx(follow.swing, limit), "on: the swing stops at its limit")
	check(follow.eye().x > 1.0, "on: the eye has swung off behind him, %s" % follow.eye())
	for _i: int in 600:
		follow.step_swing(0.0, FRAME)
	check(absf(follow.swing) < 0.01, "let go, it eases back behind him (%.3f)" % follow.swing)
	check(CameraFollow.new(Vector3.ZERO, offset).eye().x == 0.0, "off: the eye stays behind him")


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


## The camera bubble (CameraBubble; D-283, D-326, director 2026-10-27: "its the ones that the
## camera itself phases through"): a sphere round the camera of camera.bubble_radius that shrinks
## so its far edge stays the destruction field short of the kaiju on the ground (none inside the
## field); a point inside it is not drawn, one outside is fully solid, on every side.
func _check_bubble() -> void:
	var size := Num.f(Content.section("camera")["bubble_radius"])
	var field := 10.0
	var far := CameraBubble.radius_for(Vector3(0, 20, field + size + 50.0), Vector3.ZERO, field)
	check(is_equal_approx(far, size), "away from the kaiju the sphere is %.1f m" % size)
	var near := CameraBubble.radius_for(Vector3(0, 20, field + size * 0.5), Vector3.ZERO, field)
	check(
		is_equal_approx(near, size * 0.5),
		"nearer, it shrinks so its far edge stays the field's radius from him (%.1f m)" % near
	)
	var inside := CameraBubble.radius_for(Vector3(0, 20, field * 0.5), Vector3.ZERO, field)
	check(inside == 0.0, "a camera inside the field has no bubble")
	var eye := Vector3(0, 20, 40)
	var dirs := [Vector3.LEFT, Vector3.RIGHT, Vector3.UP, Vector3.DOWN, Vector3.BACK]
	dirs.append(Vector3.FORWARD)
	var all_sides := true
	for dir: Vector3 in dirs:
		var cut: bool = CameraBubble.hides(eye + dir * size * 0.9, eye, size)
		var kept: bool = CameraBubble.hides(eye + dir * size * 1.1, eye, size)
		all_sides = all_sides and cut and not kept
	check(all_sides, "a point 0.9 radius from the camera is cut away and 1.1 stays, on every side")


## What it cuts: the standing buildings the sphere reaches, at most camera.bubble_max, those that
## cover the most of the view first (the camera inside one is all of it; the nearest first between
## equals); never one in the kaiju's destruction field (even with the camera against it), never a
## damaged one. A cut starts open on the run's first frame, then opens and closes over
## camera.bubble_seconds; damage closes it at once.
func _check_bubble_picks() -> void:
	var field := 10.0
	var eye := Vector3(0, 10, 200)
	var r := CameraBubble.radius_for(eye, Vector3.ZERO, field)
	var city: Array[RampageSim.Building] = [_box(0, 200, 6), _box(0, 196.0 - r, 4)]
	city.append(_box(0, 100, 200))  # 2: from his feet to the camera, so in the field
	city.append(_box(0, 188, 10))  # 3: a wall 7 m ahead, most of the view
	for k: int in range(1, 5):
		city.append(_box(r * 0.2 * k + 0.5, 200, 1))  # 4..7: beside the camera, k * 0.2 radius
	var bubble := CameraBubble.new(city, func(_n: int) -> BuildingView: return null)
	var most := Num.i(Content.section("camera")["bubble_max"])
	var picked := bubble.picked(_frame_at(eye), Vector3.ZERO, field, r)
	check(
		picked == PackedInt32Array([0, 3, 4]) and most == 3,
		(
			(
				"it picks the %d covering the most of the view (the wall before the nearer slim"
				+ " ones), not the one 2 m past it nor the field's (%s)"
			)
			% [most, str(picked)]
		)
	)
	bubble.update(_frame_at(eye), Vector3.ZERO, field, FRAME)
	check(bubble.cut(0) == 1.0 and bubble.cut(3) == 1.0, "the first frame's cuts start open")
	check(bubble.cut(2) == 0.0, "the building in the field is whole with the camera against it")
	city[0].frame.remove(Vector3i.ZERO)
	bubble.update(_frame_at(eye), Vector3.ZERO, field, FRAME)
	var step := FRAME / Num.f(Content.section("camera")["bubble_seconds"])
	check(bubble.cut(0) == 0.0, "a building that loses a chunk is whole at once")
	check(is_equal_approx(bubble.cut(5), step), "the next one in eases open (%.3f)" % bubble.cut(5))
	var away := _frame_at(Vector3(0, 10, 400))
	bubble.update(away, Vector3.ZERO, field, FRAME)
	check(is_equal_approx(bubble.cut(3), 1.0 - step), "one the sphere leaves eases closed")
	for _i: int in ceili(1.0 / step):
		bubble.update(away, Vector3.ZERO, field, FRAME)
	check(bubble.cut(3) == 0.0 and bubble.cut(5) == 0.0, "and is whole once closed")


## The game camera's frame from `eye` looking at the kaiju at the origin.
func _frame_at(eye: Vector3) -> FrameShare:
	return FrameShare.looking(eye, Vector3.ZERO, CameraTuning.fov(), ASPECT)


## FrameShare, the share of the screen a box covers, on boxes worked out by hand.
func _check_frame_share() -> void:
	var eye := Vector3(0, 10, 40)
	var frame := FrameShare.looking(eye, Vector3(0, 10, 0), 40.0, ASPECT)
	# 4 m cube 20 m ahead: 4 / (2 * 20 * tan 20) tall, and that over the aspect wide: about 4%.
	var small := frame.share_of(AABB(Vector3(-2, 8, 18), Vector3(4, 4, 4)))
	# A wall wider and taller than the whole view, 20 m ahead.
	var wall := frame.share_of(AABB(Vector3(-200, -100, 19), Vector3(400, 300, 2)))
	var inside := frame.share_of(AABB(Vector3(-5, 0, 35), Vector3(10, 30, 10)))
	var behind := frame.share_of(AABB(Vector3(-5, 0, 50), Vector3(10, 30, 10)))
	# Wide, from one metre over the eye's height up, from 10 m ahead (the near edge crosses the
	# camera's plane): the screen above the box's far lower edge, (1 - 0.5 / (10 tan 20)) / 2.
	var low := frame.share_of(AABB(Vector3(-50, 10.5, 30), Vector3(100, 50, 20)))
	var edge := (1.0 - 0.5 / (10.0 * tan(deg_to_rad(20.0)))) * 0.5
	check(
		small > 0.02 and small < 0.08 and wall > 0.99 and inside == 1.0 and behind == 0.0,
		(
			(
				"FrameShare: a 4 m cube 20 m ahead covers %.1f%%, a wall past the view %.1f%%, the"
				+ " eye inside a box 100%%, a box behind the camera %.1f%%"
			)
			% [small * 100.0, wall * 100.0, behind * 100.0]
		)
	)
	check(
		absf(low - edge) < 0.02,
		(
			"FrameShare: a box across the camera's near plane covers %.1f%% (worked out %.1f%%)"
			% [low * 100.0, edge * 100.0]
		)
	)


## A standing w x w building of the given height at (x, z), its frame whole.
func _box(x: float, z: float, w: int, height := 30) -> RampageSim.Building:
	var b := RampageSim.Building.new()
	b.x = x
	b.z = z
	b.w = w
	b.d = w
	b.height = height
	b.frame = Structure.new(w, w, height, 1.0)
	b.start_chunks = b.frame.alive_count
	return b


## Nothing draws a screen door any more: no shader has the dither path; only the baked building
## shader reads the bubble, never in a shadow pass (the cut part keeps its shadow); a piece lifted
## off a cut building draws whole (D-326); the old fade and share keys are gone.
func _check_no_screen_door() -> void:
	var dir := DirAccess.open("res://scenes")
	var clean := true
	var readers: Array[String] = []
	for file: String in dir.get_files():
		if file.ends_with(".gdshader"):
			var code := (load("res://scenes/" + file) as Shader).code
			if code.contains("BAYER") or code.contains("DITHER") or code.contains("float opacity"):
				clean = false
				push_error("%s still has the dither path" % file)
			if code.contains("bubble"):
				readers.append(file)
	check(clean, "no shader in scenes/ keeps the screen-door dither")
	var only := readers.size() == 1 and readers[0] == "building_baked.gdshader"
	check(only, "only the building shader cuts (%s)" % str(readers))
	var code := BuildingView.SHADER.code
	check(code.contains("bubble_cut > 0.0 && !IN_SHADOW_PASS"), "the cut keeps its shadow")
	var view := BuildingView.new(_box(0, 0, 4, 4), Color("8a7f72"))
	view.set_near_camera(true, 1.0)
	var piece := view.lift_piece([Vector3i(1, 3, 1)], Vector3.ZERO)
	var whole := true
	for child: Node in piece.get_children():
		var mat := (child as MeshInstance3D).material_override as ShaderMaterial
		whole = whole and Num.f(mat.get_shader_parameter("bubble_cut")) == 0.0
	check(whole and view.near_camera_cut() == 1.0, "a piece lifted off a cut building draws whole")
	piece.free()
	view.free()
	var cam := Content.section("camera")
	var gone := ["fade_opacity", "fade_seconds", "fade_width", "fade_frame_share", "bubble_share"]
	gone.append("bubble_width")
	var left := gone.filter(func(k: String) -> bool: return cam.has(k))
	check(left.is_empty(), "the old camera fade and share keys are gone (%s)" % str(left))
	check(
		not Content.section("vehicles").has("fade_opacity"), "vehicles.fade_opacity is gone as well"
	)
