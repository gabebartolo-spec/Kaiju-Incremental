class_name TreeArea
extends Control
## The evolution tree's nodes on its map (D-275, layout A): polar rings round the baby's ring at
## the centre (TreeLayout), seen through a camera that zooms and pans (TreeView). Zoom: the mouse
## wheel (toward the cursor) and the pad triggers, from the default (text 24 px at 1080p) out to
## the whole tree on screen. Pan: drag with the left button, WASD or the arrows, the pad's right
## stick; the tree never leaves the screen. Lines join each shown node to what it needs. Rates:
## tuning "tree" "view".

signal node_pressed(id: String)
signal node_selected(id: String)

## Smallest the area may get.
const MIN_SIZE := Vector2(640, 480)
const LINK_WIDTH := 4.0
const LINK_MIN_WIDTH := 1.5
const PAN_LEFT: Array[Key] = [KEY_A, KEY_LEFT]
const PAN_RIGHT: Array[Key] = [KEY_D, KEY_RIGHT]
const PAN_UP: Array[Key] = [KEY_W, KEY_UP]
const PAN_DOWN: Array[Key] = [KEY_S, KEY_DOWN]

var tree: UpgradeTree
var buttons: Dictionary = {}
var layout: TreeLayout
var view: TreeView
var _species: Dictionary
var _roles: Dictionary
var _cfg: Dictionary
var _dragging := false
## A tree point to centre on once the area has its size (centre_on before the first layout).
var _pending := Vector2.ZERO
var _has_pending := false


## roles: id -> "plain" / "branch" / "evolve" / "ultimate" (UpgradeScreen.role_of).
func setup(p_tree: UpgradeTree, species: Dictionary, roles: Dictionary) -> void:
	tree = p_tree
	_species = species
	_roles = roles


func _ready() -> void:
	custom_minimum_size = MIN_SIZE
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_cfg = Content.section("tree")["view"]
	var ultimates: Array[String] = []
	for id: String in tree.order:
		if str(_roles[id]) == "ultimate":
			ultimates.append(id)
	layout = TreeLayout.build(tree, ultimates)
	view = TreeView.new(layout.bounds, size, Num.f(_cfg["fit_margin"]))
	for id: String in tree.order:
		var def: Dictionary = tree.defs[id]
		var b := UpgradeNode.new(id, str(_roles[id]), str(def["name"]))
		# Wheel and drag over a node reach the map; clicks stay the node's.
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b.pressed.connect(func() -> void: node_pressed.emit(id))
		b.focus_entered.connect(func() -> void: _on_focus(id))
		b.mouse_entered.connect(func() -> void: node_selected.emit(id))
		add_child(b)
		var box: Vector2 = layout.sizes[id]
		b.place(Vector2.ZERO, box)
		buttons[id] = b
	resized.connect(_on_resized)
	_on_resized()


## Centres the view on node `id` (as near as the clamps allow), now or once the area has a size.
func centre_on(id: String) -> void:
	if not layout.centres.has(id):
		return
	_pending = layout.centres[id]
	_has_pending = true
	if size.x > 0.0 and size.y > 0.0:
		view.look_at(_pending)
		_place()


func _on_resized() -> void:
	view.resize(size)
	if _has_pending and size.x > 0.0 and size.y > 0.0:
		view.look_at(_pending)
	_place()


## A node reached by the keyboard or pad comes into view.
func _on_focus(id: String) -> void:
	node_selected.emit(id)
	var b: Button = buttons[id]
	if not Rect2(Vector2.ZERO, size).encloses(Rect2(b.position, b.size * view.zoom)):
		var at: Vector2 = layout.centres[id]
		view.look_at(at)
		_place()


## Puts every node where the camera shows it, at the camera's zoom.
func _place() -> void:
	for id: String in tree.order:
		var b: Button = buttons[id]
		var box: Vector2 = layout.sizes[id]
		var at: Vector2 = layout.centres[id]
		b.scale = Vector2(view.zoom, view.zoom)
		b.position = view.to_screen(at) - box * 0.5 * view.zoom
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var wheel := Num.f(_cfg["wheel_step"])
	if event is InputEventMouseButton:
		var press := event as InputEventMouseButton
		if press.pressed and press.button_index == MOUSE_BUTTON_WHEEL_UP:
			view.zoom_at(press.position, wheel)
		elif press.pressed and press.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			view.zoom_at(press.position, 1.0 / wheel)
		elif press.button_index == MOUSE_BUTTON_LEFT:
			_dragging = press.pressed
		else:
			return
		_place()
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		view.pan_by(motion.relative)
		_place()
		accept_event()


## Keys, the right stick and the triggers, each frame the tree is on screen.
func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var move := Vector2(
		float(_held(PAN_RIGHT)) - float(_held(PAN_LEFT)),
		float(_held(PAN_DOWN)) - float(_held(PAN_UP))
	)
	var dead := Num.f(_cfg["deadzone"])
	var stick := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	)
	if stick.length() > dead:
		move += stick
	var squeeze := (
		Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) - Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT)
	)
	if move == Vector2.ZERO and absf(squeeze) <= dead:
		return
	if move != Vector2.ZERO:
		# The view moves the way the stick points: the tree slides the other way.
		view.pan_by(-move.limit_length(1.0) * Num.f(_cfg["pan_per_second"]) * delta)
	if absf(squeeze) > dead:
		var rate := pow(Num.f(_cfg["zoom_per_second"]), squeeze * delta)
		view.zoom_at(size * 0.5, rate)
	_place()


static func _held(keys: Array[Key]) -> bool:
	for key: Key in keys:
		if Input.is_physical_key_pressed(key):
			return true
	return false


## Links join shown nodes only: nothing leads into a ring that is not shown yet (R 1.4).
func _draw() -> void:
	var width := maxf(LINK_MIN_WIDTH, LINK_WIDTH * view.zoom)
	for id: String in tree.order:
		var def: Dictionary = tree.defs[id]
		var requires: Array = def.get("requires", [])
		for req: String in requires:
			if not buttons.has(req) or not _shown(id) or not _shown(req):
				continue
			var owned := tree.level(req) > 0
			var colour := UiKit.GOOD if owned else UiKit.LOCKED
			draw_line(_centre(req), _centre(id), colour, width, true)


func _shown(id: String) -> bool:
	var b: Button = buttons[id]
	return b.visible


func _centre(id: String) -> Vector2:
	var at: Vector2 = layout.centres[id]
	return view.to_screen(at)
