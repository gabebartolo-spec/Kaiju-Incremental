extends SceneTree
## Photo mode as the player meets it (D-259), for the director's clip: a seed-0 croc rampage plays
## on autoplay, Esc opens the pause menu, a click on PHOTO MODE freezes the world under the free
## camera, which flies in (W), turns with a mouse drag, rises (E) and strafes (D); Esc returns to
## the pause menu and Esc again resumes the run. Every step is a real key, click or mouse motion.
## Needs a window and the no-focus override.cfg (Kit.window_ok).
##
##   godot --path . --resolution 3840x2160 --windowed --fixed-fps 60 \
##     --write-movie <dir>/photo.avi --script tools/capture/capture_photo.gd

const Kit := preload("res://tools/capture/capture_kit.gd")
const GuiInput := preload("res://tests/lib/gui_input.gd")


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	if not Kit.window_ok():
		quit(1)
		return
	var rampage := Kit.rampage("reptilian", Kit.stats("reptilian", Kit.STAGE_LEVELS[1]), 0)
	root.add_child(rampage)
	await rampage.wait_loaded()
	while rampage.sim.emerge.active:
		await physics_frame
	rampage.set_autoplay(true)
	await Kit.frames(self, 60)
	await GuiInput.key(self, KEY_ESCAPE)
	await Kit.frames(self, 30)
	await GuiInput.click(self, GuiInput.button(rampage, "PHOTO MODE"))
	await Kit.frames(self, 30)
	await _hold(KEY_W, 50, Vector2(4, 0))
	await _hold(KEY_E, 30, Vector2(0, -1))
	await _hold(KEY_D, 70, Vector2(-6, 0))
	await Kit.frames(self, 20)
	await GuiInput.key(self, KEY_ESCAPE)
	await Kit.frames(self, 30)
	await GuiInput.key(self, KEY_ESCAPE)
	await Kit.frames(self, 50)
	quit()


## Holds `code` for `frames` frames while the mouse moves `turn` pixels a frame.
func _hold(code: Key, frames: int, turn: Vector2) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	for _i: int in frames:
		var m := InputEventMouseMotion.new()
		m.relative = turn
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(m)
		await process_frame
	var up := e.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame
