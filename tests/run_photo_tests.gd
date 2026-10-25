extends "res://tests/lib/runner.gd"
## Photo mode suite (director 2026-10-26, D-259 "Photo mode: Yes, simple"): in a seed-0 reptilian
## rampage, Esc and a real click on PHOTO MODE open it; the sim does not step (elapsed and step
## count unchanged across frames, the kaiju still); nothing of the HUD or the pause menu shows but
## the small controls card (24 px+, inside the title-safe margin), and H hides that; the move keys
## fly the camera, the mouse and the right stick turn it, E and Q lift and sink it; it never leaves
## the data radius round the kaiju nor sinks under the ground; Esc puts the camera back exactly and
## returns to the pause menu, and a second Esc resumes the run; a rebound move key flies it, pad A
## opens it from the pause menu and pad B leaves.
## Seeded by design: city seed 0, army seed 0; time stepped by frames; no random draw is read.
##   godot --headless --path . --script tests/run_photo_tests.gd

const GuiInput := preload("res://tests/lib/gui_input.gd")

var rampage: Rampage
var mode: PhotoMode
var _saved: Transform3D


func suite_name() -> String:
	return "Photo"


func run_checks() -> void:
	KeyBinds.reset()
	await _t("_check_clamp_math")
	await _open_run()
	await _t("_check_enter")
	if mode == null:
		return
	await _t("_check_frozen")
	await _t("_check_hud_hidden")
	await _t("_check_fly")
	await _t("_check_clamped")
	await _t("_check_hint_toggle")
	await _t("_check_return")
	await _t("_check_rebound_and_pad")
	KeyBinds.reset()
	paused = false
	rampage.free()


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


func _open_run() -> void:
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades())
	)
	rampage = Rampage.new()
	rampage.setup(
		species, stats, CityGen.generate(Seeds.make("city", 0), Content.section("city")), 0
	)
	get_root().add_child(rampage)
	await rampage.wait_loaded()
	var frames := 0
	while rampage.sim.emerge.active and frames < 1200:
		await physics_frame
		frames += 1


## Holds `code` down for `frames` frames, then lets go (a player's held key).
func _hold(code: Key, frames: int) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(frames)
	var up := e.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(2)


func _menu() -> PauseMenu:
	return GuiInput.find_script(rampage, PauseMenu) as PauseMenu


func _mode() -> PhotoMode:
	return GuiInput.find_script(rampage, PhotoMode) as PhotoMode


func _cam() -> Camera3D:
	return rampage.get_viewport().get_camera_3d()


## clamp_eye on its own: far points come back to the radius, low points to the floor.
func _check_clamp_math() -> void:
	var cam := Camera3D.new()
	var p := PhotoMode.new(cam, Vector3(10, 0, -5), 40.0, [] as Array[Node3D])
	var out := p.clamp_eye(Vector3(500, 30, 200))
	check(
		absf(out.distance_to(p.centre) - p.radius) < 0.01,
		(
			"a point far out comes back onto the sphere (%.2f of %.2f)"
			% [out.distance_to(p.centre), p.radius]
		)
	)
	out = p.clamp_eye(Vector3(10, -50, -5))
	check(out.y == p.floor_y and p.floor_y > 0.0, "a point under the street rises to %.2f" % out.y)
	out = p.clamp_eye(Vector3(12, 9, -4))
	check(out == Vector3(12, 9, -4), "a point inside is left alone")
	p.free()
	cam.free()


func _check_enter() -> void:
	await GuiInput.key(self, KEY_ESCAPE)
	_saved = _cam().global_transform  # the world is paused: the game camera holds here
	var menu := _menu()
	var b := GuiInput.button(menu, "PHOTO MODE") if menu != null else null
	check(paused and b != null, "Esc pauses and the pause menu offers PHOTO MODE")
	if b == null:
		return
	await GuiInput.click(self, b)
	await _frames(2)
	mode = _mode()
	check(mode != null and paused, "clicking PHOTO MODE opens photo mode with the world paused")


func _check_frozen() -> void:
	var elapsed := rampage.sim.elapsed
	var steps := rampage._steps
	var at := rampage._kaiju.global_position
	await _hold(KEY_W, 30)
	for _i: int in 10:
		await physics_frame
	check(
		rampage.sim.elapsed == elapsed and rampage._steps == steps,
		(
			"the sim does not step in photo mode (elapsed %.3f -> %.3f, steps %d -> %d)"
			% [elapsed, rampage.sim.elapsed, steps, rampage._steps]
		)
	)
	check(rampage._kaiju.global_position == at, "the kaiju stands still while the camera flies")


## Every Control drawn on screen in photo mode belongs to the photo card or the post effects.
func _shown_controls() -> Array[String]:
	var out: Array[String] = []
	for node: Node in rampage.find_children("*", "Control", true, false):
		var c := node as Control
		if not c.is_visible_in_tree() or mode.is_ancestor_of(c):
			continue
		if c.get_parent() is PostFx or c.get_parent().get_parent() is PostFx:
			continue
		out.append(str(c.get_path()).get_file())
	return out


func _check_hud_hidden() -> void:
	var shown := _shown_controls()
	check(shown.is_empty(), "no HUD or pause menu shows in photo mode (%s)" % [shown])
	check(not rampage._aim.visible, "the breath's aim hides in photo mode")
	var screen := mode.hint.get_viewport_rect().size
	var safe := Rect2(UiKit.safe_margin(), screen - UiKit.safe_margin() * 2.0)
	var card := mode.hint.get_global_rect()
	check(
		mode.hint.is_visible_in_tree() and safe.encloses(card),
		"the controls card shows inside the title-safe area (%s in %s)" % [card, safe]
	)
	var small := 0
	var labels := mode.hint.find_children("*", "Label", true, false)
	for node: Node in labels:
		if (node as Label).get_theme_font_size("font_size") < UiKit.SIZE_BODY:
			small += 1
	check(small == 0 and labels.size() >= 16, "every card text is 24 px+ (%d small)" % small)


func _check_fly() -> void:
	var cam := _cam()
	var before := cam.global_position
	var ahead := -cam.global_basis.z
	await _hold(KEY_W, 20)
	var moved := cam.global_position - before
	check(
		moved.length() > 1.0 and Vector2(moved.x, moved.z).dot(Vector2(ahead.x, ahead.z)) > 0.0,
		"holding W flies the camera forward (%.2f units)" % moved.length()
	)
	before = cam.global_position
	await _hold(KEY_E, 10)
	check(cam.global_position.y > before.y + 0.5, "E lifts the camera")
	var facing := -cam.global_basis.z
	var turn := InputEventMouseMotion.new()
	turn.relative = Vector2(200, 0)
	turn.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(turn)
	await _frames(2)
	check((-cam.global_basis.z).angle_to(facing) > 0.3, "a mouse drag turns the camera")
	facing = -cam.global_basis.z
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_RIGHT_X
	stick.axis_value = 1.0
	Input.parse_input_event(stick)
	await _frames(20)
	stick.axis_value = 0.0
	Input.parse_input_event(stick)
	await _frames(2)
	check((-cam.global_basis.z).angle_to(facing) > 0.1, "the right stick turns the camera")


func _check_clamped() -> void:
	var cam := _cam()
	await _hold(KEY_W, 420)
	var far := cam.global_position.distance_to(mode.centre)
	check(
		far <= mode.radius + 0.01 and far > mode.radius - 2.0,
		"flying on stops at the radius (%.2f of %.2f)" % [far, mode.radius]
	)
	await _hold(KEY_Q, 240)
	check(
		absf(cam.global_position.y - mode.floor_y) < 0.01,
		(
			"sinking stops above the street (y %.2f, floor %.2f)"
			% [cam.global_position.y, mode.floor_y]
		)
	)


func _check_hint_toggle() -> void:
	await GuiInput.key(self, KEY_H)
	check(not mode.hint.visible, "H hides the controls card")
	await GuiInput.key(self, KEY_H)
	check(mode.hint.visible, "H again shows it")


func _check_return() -> void:
	await GuiInput.key(self, KEY_ESCAPE)
	await _frames(2)
	var menu := _menu()
	check(_mode() == null and paused, "Esc leaves photo mode and the world stays paused")
	check(
		_cam().global_transform.is_equal_approx(_saved), "the gameplay camera is back where it was"
	)
	check(
		menu != null and GuiInput.button(menu, "RESUME") != null, "the pause menu is back on screen"
	)
	var steps := rampage._steps
	await GuiInput.key(self, KEY_ESCAPE)
	for _i: int in 5:
		await physics_frame
	check(not paused and rampage._steps > steps, "a second Esc resumes the rampage")


## A rebound move key flies the camera; pad A opens photo mode from its focused button, B leaves.
func _check_rebound_and_pad() -> void:
	var press := InputEventKey.new()
	press.physical_keycode = KEY_I
	KeyBinds.bind("move_up", press)
	await GuiInput.key(self, KEY_ESCAPE)
	var b := GuiInput.button(_menu(), "PHOTO MODE")
	b.grab_focus()
	await _frames(1)
	await GuiInput.pad(self, JOY_BUTTON_A)
	await _frames(2)
	mode = _mode()
	check(mode != null, "pad A on PHOTO MODE opens photo mode")
	if mode == null:
		return
	var row: Array = PhotoMode.hint_rows()[0]
	check(str(row[1]).begins_with("I"), "the card shows the rebound move key ('%s')" % row[1])
	var before := _cam().global_position
	await _hold(KEY_I, 20)
	check(_cam().global_position.distance_to(before) > 1.0, "the rebound key I flies the camera")
	await GuiInput.pad(self, JOY_BUTTON_B)
	await _frames(2)
	check(_mode() == null and _menu() != null, "pad B returns to the pause menu")
