class_name PhotoMode
extends CanvasLayer
## Photo mode (director 2026-10-26, D-259 "Photo mode: Yes, simple"), opened from the pause menu.
## The tree stays paused, so the sim never steps and the world holds still (the engine holds
## particles, animation and sound with it); the pause menu, the HUD, the breath's aim and the
## floating numbers hide, and a free camera flies round the kaiju: never further from his feet
## than tuning "photo_mode" radius (a multiple of the gameplay camera's distance, so it grows with
## him) and never below its min_height over the ground. It flies on the player's own move keys
## (D-259 rebinds), rises and sinks on E / Q (RB / LB), turns with a mouse drag or the right stick.
## A small card names the controls; H / X hides it for a clean picture. Esc / B (or Pause) puts
## the gameplay camera back exactly where it was and returns to the pause menu.

signal closed

const LAYER := 31
const GROUND_Y := 0.0  # the street's level
const RISE := "photo_rise"
const SINK := "photo_sink"
const HINT_TOGGLE := "photo_hint"
## The card's rows after the move row: name, keyboard, pad.
const HINT_ROWS: Array[Array] = [
	["Look", "Drag mouse", "Right stick"],
	["Up / down", "E / Q", "RB / LB"],
	["Hide this", "H", "X"],
	["Back", "Esc", "B"],
]

## The small controls card (null until _ready).
var hint: PanelContainer
## The kaiju's feet: the centre of the camera's allowed sphere.
var centre: Vector3
## How far from `centre` the camera may fly, and how fast (units a second).
var radius: float
var speed: float
## The lowest the camera may sink (world y).
var floor_y: float
var _camera: Camera3D
var _saved: Transform3D
var _hide: Array[Node3D] = []
var _was_visible: Array[bool] = []
var _yaw := 0.0
var _pitch := 0.0
var _mouse := Vector2.ZERO
var _cfg: Dictionary


## camera: the gameplay camera (moved here, put back on close); feet: the kaiju's feet; rest: the
## gameplay camera's distance from them now; hide: what goes while the picture is taken.
func _init(camera: Camera3D, feet: Vector3, rest: float, hide: Array[Node3D]) -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cfg = Content.section("photo_mode")
	_camera = camera
	centre = feet
	radius = rest * Num.f(_cfg["radius_rest_multiple"])
	speed = rest * Num.f(_cfg["speed_rest_multiple"])
	floor_y = GROUND_Y + Num.f(_cfg["min_height"])
	_hide = hide


func _ready() -> void:
	_saved = _camera.global_transform
	var ahead := -_saved.basis.z
	_yaw = atan2(-ahead.x, -ahead.z)
	_pitch = asin(clampf(ahead.y, -1.0, 1.0))
	for node: Node3D in _hide:
		_was_visible.append(node.visible)
		node.visible = false
	_build_hint()


func _exit_tree() -> void:
	_restore()


func _unhandled_input(event: InputEvent) -> void:
	var drag := event as InputEventMouseMotion
	if drag != null:
		if drag.button_mask != 0:  # a drag turns; the cursor stays the player's
			_mouse += drag.relative
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed(HINT_TOGGLE):
		get_viewport().set_input_as_handled()
		hint.visible = not hint.visible


func _process(delta: float) -> void:
	var stick := Input.get_vector(
		"photo_look_left", "photo_look_right", "photo_look_up", "photo_look_down"
	)
	var turn := stick * deg_to_rad(Num.f(_cfg["look_deg_per_s"])) * delta
	turn += _mouse * deg_to_rad(Num.f(_cfg["mouse_deg_per_px"]))
	_mouse = Vector2.ZERO
	var limit := deg_to_rad(Num.f(_cfg["pitch_limit_deg"]))
	_yaw -= turn.x
	_pitch = clampf(_pitch - turn.y, -limit, limit)
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var flat := Basis(Vector3.UP, _yaw)
	var go := flat * Vector3(move.x, 0.0, move.y)
	go.y = Input.get_axis(SINK, RISE)
	var eye := clamp_eye(_camera.global_position + go * speed * delta)
	_camera.global_transform = Transform3D(Basis.from_euler(Vector3(_pitch, _yaw, 0.0)), eye)


## `p` pulled back inside the allowed space: no lower than floor_y, no further than radius from
## the kaiju's feet (the height first, then the reach along the ground at that height).
func clamp_eye(p: Vector3) -> Vector3:
	var out := p
	out.y = clampf(out.y, floor_y, maxf(floor_y, centre.y + radius))
	var rise := out.y - centre.y
	var reach := sqrt(maxf(radius * radius - rise * rise, 0.0))
	var flat := Vector2(out.x - centre.x, out.z - centre.z)
	if flat.length() > reach:
		flat = flat.normalized() * reach
	return Vector3(centre.x + flat.x, out.y, centre.z + flat.y)


## Puts the gameplay camera back and returns to the pause menu.
func close() -> void:
	_restore()
	closed.emit()
	queue_free()


func _restore() -> void:
	if _camera == null:
		return
	if is_instance_valid(_camera):
		_camera.global_transform = _saved
	for i: int in _hide.size():
		if is_instance_valid(_hide[i]):
			_hide[i].visible = _was_visible[i]
	_camera = null


## The controls card, bottom left inside the TV's title-safe margin (keyboard and pad; the move
## row shows the player's own keys).
func _build_hint() -> void:
	var safe := MarginContainer.new()
	UiKit.full_rect(safe)
	UiKit.safe_area(safe)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(safe)
	hint = PanelContainer.new()
	hint.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hint.size_flags_vertical = Control.SIZE_SHRINK_END
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_stylebox_override("panel", UiKit.panel_box())
	safe.add_child(hint)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	hint.add_child(col)
	col.add_child(UiKit.header(tr("PHOTO MODE"), UiKit.SIZE_HEAD))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 4)
	col.add_child(grid)
	for row: Array in hint_rows():
		grid.add_child(UiKit.label(_shown(str(row[0])), UiKit.SIZE_BODY, UiKit.TEXT))
		grid.add_child(UiKit.label(_shown(str(row[1])), UiKit.SIZE_BODY, UiKit.MUTED))
		grid.add_child(UiKit.label(_shown(str(row[2])), UiKit.SIZE_BODY, UiKit.MUTED))


## A hint row's text in the player's language: HINT_ROWS's own words, else KeyBinds's names.
func _shown(text: String) -> String:
	match text:
		"Look":
			return tr("Look")
		"Drag mouse":
			return tr("Drag mouse")
		"Right stick":
			return tr("Right stick")
		"Up / down":
			return tr("Up / down")
		"Hide this":
			return tr("Hide this")
	return KeyBinds.shown(text)


## The card's rows: the Controls list's Move row with the player's keys, then HINT_ROWS.
static func hint_rows() -> Array[Array]:
	var out: Array[Array] = []
	for entry: Array in PlayerSettings.CONTROLS:
		if str(entry[0]) == "Move":
			out.append(KeyBinds.row_text(entry))
	out.append_array(HINT_ROWS)
	return out
