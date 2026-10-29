class_name TreeArea
extends Control
## The evolution tree's nodes on its map (D-275, layout A): polar rings round the baby's ring at
## the centre (TreeLayout), seen through a camera that zooms and pans (TreeView). Zoom: the mouse
## wheel (toward the cursor) and the pad triggers, from the default (text 24 px at 1080p) out to
## the whole tree on screen. Pan: drag with the left button, WASD or the arrows, the pad's right
## stick; the tree never leaves the screen. Glass tubes join each shown node to what it needs.
## Rates: tuning "tree" "view". Look: a bio-lab specimen plate, tuning "tree" "skin".

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
## The juice (TreeFx): what is playing; drawn here under the nodes and by TreeFxLayer over them.
var fx: TreeFx
## The kaiju at the plate's centre (D-395), under the nodes.
var specimen: TreeSpecimen
var _species: Dictionary
var _roles: Dictionary
var _cfg: Dictionary
var _skin: Dictionary
var _layer: TreeFxLayer
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
	_skin = Content.section("tree")["skin"]
	var fx_cfg: Dictionary = _skin["fx"]
	fx = TreeFx.new(fx_cfg)
	if fx.enabled():
		specimen = TreeSpecimen.new(_species, fx.f("specimen_spin"))
		add_child(specimen)
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
	_layer = TreeFxLayer.new(self)
	add_child(_layer)
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
	if specimen != null:
		var side := fx.f("specimen_px") * view.zoom
		specimen.size = Vector2(side, side)
		specimen.position = view.to_screen(Vector2.ZERO) - Vector2(side, side) * 0.5
	queue_redraw()


## The kaiju at the centre shows his growth stage (TreeSpecimen); nothing with the fx off.
func show_specimen(stage: String) -> void:
	if specimen != null:
		specimen.show_stage(stage)


## A node was bought: Special K surges down its tubes, motes fly in from `from` (the biomass
## counter, in this area's coordinates) and the node flashes.
func play_buy(id: String, from: Vector2) -> void:
	var children: Array[String] = []
	for other: String in tree.order:
		var def: Dictionary = tree.defs[other]
		var requires: Array = def.get("requires", [])
		if requires.has(id):
			children.append(other)
	fx.buy(id, children, from)


## Ring `ring` (1-based, as UpgradeTree.ring) opened: its rim flares.
func play_ring_open(ring: int) -> void:
	fx.ring_open(ring)


## An evolution node was bought: bolts from the plate's centre and a plate flash.
func play_evolve(id: String) -> void:
	fx.evolve(id)


## A node's centre on screen.
func centre_of(id: String) -> Vector2:
	return _centre(id)


## The radius (canvas units) of the rim round ring index `r` (0 is the baby's ring).
func rim_radius(r: int) -> float:
	var gap := Num.f(Content.section("tree")["layout"]["ring_gap"]) * 0.5
	r = clampi(r, 0, layout.radii.size() - 1)
	return layout.radii[r] + layout.half_depth[r] + gap


func colour(key: String) -> Color:
	return _colour(key)


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
	if fx.enabled():
		fx.advance(delta)
		queue_redraw()
		_layer.queue_redraw()
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


## The plate under the nodes: its fill, a graticule and a dish rim round each ring, all moving
## with the camera. Tubes join shown nodes only: nothing leads into a ring that is not shown yet
## (R 1.4); a tube runs with Special K once the node it leads from is owned.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _colour("plate"))
	_draw_grid()
	_draw_scan()
	_draw_rims()
	var width := maxf(LINK_MIN_WIDTH, LINK_WIDTH * view.zoom)
	var tube_width := width + Num.f(_skin["tube_extra"]) * view.zoom
	for pass_core: bool in [false, true]:
		_draw_tubes(pass_core, width, tube_width)
	if fx.enabled():
		_draw_surges(width)


## A dish rim round each ring, halfway across the gap outside its band; an open ring's glows.
func _draw_rims() -> void:
	var origin := view.to_screen(Vector2.ZERO)
	var rim := _colour("rim")
	var rim_width := maxf(LINK_MIN_WIDTH, Num.f(_skin["rim_width"]) * view.zoom)
	for r: int in layout.radii.size():
		var reach := rim_radius(r) * view.zoom
		if tree.ring_open(r + 1) and fx.enabled():
			var glow := Color(_colour("juice"), 0.18)
			draw_arc(origin, reach, 0.0, TAU, 128, glow, rim_width * 3.0, true)
		draw_arc(origin, reach, 0.0, TAU, 128, rim, rim_width, true)


## One pass over the tubes: the glass (`core` false) or what runs inside it (`core` true).
func _draw_tubes(core: bool, width: float, tube_width: float) -> void:
	for id: String in tree.order:
		var def: Dictionary = tree.defs[id]
		var requires: Array = def.get("requires", [])
		for req: String in requires:
			if not buttons.has(req) or not _shown(id) or not _shown(req):
				continue
			if not core:
				draw_line(_centre(req), _centre(id), _colour("tube"), tube_width, true)
				continue
			var owned := tree.level(req) > 0
			var colour := _colour("juice") if owned else _colour("empty")
			draw_line(_centre(req), _centre(id), colour, width, true)
			if owned and fx.enabled():
				_draw_bubbles(_centre(req), _centre(id), width)


## Bubbles rise along an owned tube: bubbles_per_100px of them per 100 canvas px, each on its own
## phase, moving bubble_speed px/s from the parent toward the child.
func _draw_bubbles(from: Vector2, to: Vector2, width: float) -> void:
	var cfg: Dictionary = _skin["fx"]
	var length := from.distance_to(to)
	var n := maxi(1, roundi(length / 100.0 * Num.f(cfg["bubbles_per_100px"])))
	var speed := Num.f(cfg["bubble_speed"]) * view.zoom
	var px := Num.f(cfg["bubble_px"]) * maxf(0.5, view.zoom)
	var top := _colour("liquid_top")
	var across := Vector2(-(to - from).y, (to - from).x).normalized() * width * 0.3
	var phase_seed := float(hash(from) % 1000) * 0.001
	for i: int in n:
		var phase := (float(i) + phase_seed) / float(n)
		var share := fmod(fx.time * speed / maxf(1.0, length) + phase, 1.0)
		var at := from.lerp(to, share) + across * sin(fx.time * 3.0 + float(i))
		draw_circle(at, px * (0.6 + 0.4 * sin(share * PI)), Color(top, 0.6))


## Special K surging down a tube a bought node leads out of: a bright pulse, head first.
func _draw_surges(width: float) -> void:
	var cfg: Dictionary = _skin["fx"]
	var length_s := Num.f(cfg["surge_s"])
	for surge: Dictionary in fx.surges:
		var share := Num.f(surge["t"]) / length_s
		var from := _centre(str(surge["from"]))
		var to := _centre(str(surge["to"]))
		var head := from.lerp(to, share)
		var tail := from.lerp(to, maxf(0.0, share - 0.3))
		draw_line(tail, head, _colour("liquid_top"), width * 1.6, true)
		draw_circle(head, width * 1.3, Color.WHITE)


## The lab scanner: a soft bar sweeping down the plate every scan_period_s.
func _draw_scan() -> void:
	if not fx.enabled():
		return
	var cfg: Dictionary = _skin["fx"]
	var period := Num.f(cfg["scan_period_s"])
	var share := fmod(fx.time, period) / period
	var band := Num.f(cfg["scan_px"])
	var y := -band + (size.y + band * 2.0) * share
	var alpha := Num.f(cfg["scan_alpha"])
	var top := _colour("liquid_top")
	draw_rect(Rect2(Vector2(0.0, y), Vector2(size.x, band)), Color(top, alpha))
	draw_rect(Rect2(Vector2(0.0, y + band * 0.5), Vector2(size.x, 2.0)), Color(top, alpha * 3.0))


## The plate's graticule: lines every grid_step canvas units, over the part of the plate in view.
func _draw_grid() -> void:
	var step := Num.f(_skin["grid_step"])
	var colour := _colour("grid")
	if fx.enabled():
		# The graticule breathes: brighter and dimmer over breath_period_s.
		var cfg: Dictionary = _skin["fx"]
		var breath := 0.5 + 0.5 * sin(fx.time * TAU / Num.f(cfg["breath_period_s"]))
		colour = colour.lerp(_colour("rim"), breath * Num.f(cfg["breath_alpha"]))
	var low := view.to_tree(Vector2.ZERO)
	var high := view.to_tree(size)
	var x := floorf(low.x / step) * step
	while x <= high.x:
		var sx := view.to_screen(Vector2(x, 0.0)).x
		draw_line(Vector2(sx, 0.0), Vector2(sx, size.y), colour, 1.0)
		x += step
	var y := floorf(low.y / step) * step
	while y <= high.y:
		var sy := view.to_screen(Vector2(0.0, y)).y
		draw_line(Vector2(0.0, sy), Vector2(size.x, sy), colour, 1.0)
		y += step


func _colour(key: String) -> Color:
	return Color(str(_skin[key]))


func _shown(id: String) -> bool:
	var b: Button = buttons[id]
	return b.visible


func _centre(id: String) -> Vector2:
	var at: Vector2 = layout.centres[id]
	return view.to_screen(at)
