class_name SpeciesSelect
extends Control
## New game: pick one of the species (in the demo, D-050, its species only; the rest are absent).
## Each card shows the kaiju spinning on a turntable in a live 3D preview, centred and in frame
## all the way round (b2-11), its signature attack and how its body compares.

signal chosen(species_id: String)
## Back to the title (Esc / B, or the BACK button); nothing has changed yet.
signal back_pressed

## With one species the card is wide: kaiju preview on the left, name, stats and CHOOSE on the
## right; the card is this share of the screen and the preview sized off the screen's height.
## With several, each card is a narrow column and the preview stays small, so all fit the TV at
## the largest UI scale (125%).
const WIDE_CARD_WIDTH := 1056.0
const WIDE_PREVIEW := Vector2i(640, 400)
## The gap between the preview and the info column (px at 1080p).
const WIDE_GAP := 24.0
const INFO_WIDTH := 320.0
const NARROW_PREVIEW := Vector2i(390, 220)
## The stat meters: a cell per step, each stat's value out of its maximum in COMPARE.
const STAT_CELLS := 8
const MIN_CELL := 14.0
const SIZE_STAT := 28
## Several cards share the screen: smaller stat text and thinner cells (px).
const SIZE_STAT_NARROW := 24
const NARROW_STAT_NAME := 96
const NARROW_MIN_CELL := 6.0
## Space above BACK (px at 1080p).
const BACK_GAP := 20
const BACK_GAP_NARROW := 12
## The preview camera looks down this way (the old fixed camera's view) through a fairly long lens
## (deg; a near limb swinging toward a wide lens would push the kaiju small); the spinning kaiju
## fills at most this much of the card's width and keeps this margin (of the height) top and bottom.
const PREVIEW_VIEW := Vector3(0, -2.9, -12.5)
const PREVIEW_FOV := 30.0
const PREVIEW_FILL := 0.92
const PREVIEW_MARGIN := 0.06
## It starts at a three-quarter side view (yaw, rad) and spins at tuning "ui" species_spin_rate
## (rad/s) about the middle of its own footprint; the fit samples a full turn at this many
## angles and every this-many-th skin corner.
const PREVIEW_YAW := PI * 0.62
const PREVIEW_SAMPLES := 16
const PREVIEW_STRIDE := 13
const BACK_WIDTH := 360
## The stat name column in a card (px), wide enough for Health and Speed at SIZE_STAT.
const STAT_NAME_WIDTH := 124
const COMPARE: Array[Array] = [
	["Health", "hp", 150.0],
	["Speed", "speed", 8.0],
	["Power", "stomp_damage", 12.0],
	["Reach", "stomp_radius", 4.0]
]

## Each preview's turntable: the kaiju sits on it with its footprint's middle on the axis.
var turntables: Array[Node3D] = []
## Each species' card, in order.
var cards: Array[Control] = []
var _wide := false
var _models: Array[KaijuModel] = []
var _spin := 0.0


func _ready() -> void:
	UiKit.full_rect(self)
	add_child(UiKit.backdrop())
	# No tape along the top edge on any screen (director 2026-10-25: "remove yellow bar at top").
	_spin = Num.f(UiKit.ui()["species_spin_rate"])
	var safe := MarginContainer.new()
	UiKit.full_rect(safe)
	UiKit.safe_area(safe)
	add_child(safe)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 16)
	safe.add_child(col)
	var title := UiKit.header(tr("CHOOSE YOUR KAIJU"))
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 32)
	col.add_child(row)
	var first: Button = null
	_wide = Demo.species().size() == 1
	for def: Dictionary in Demo.species():
		var pick := _card(row, def)
		if first == null:
			first = pick
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, BACK_GAP if _wide else BACK_GAP_NARROW)
	col.add_child(gap)
	var back := UiKit.button(tr("BACK  (ESC / B)"), UiKit.SIZE_BODY, UiKit.PANEL_EDGE)
	back.custom_minimum_size = Vector2(BACK_WIDTH, 0)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: back_pressed.emit())
	col.add_child(back)
	if first != null:
		first.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back_pressed.emit()


func _process(delta: float) -> void:
	for table: Node3D in turntables:
		table.rotation.y = wrapf(table.rotation.y + _spin * delta, 0.0, TAU)
	for model: KaijuModel in _models:
		model.animate(delta, 0.3)


## Puts the kaiju on its turntable with the middle of its footprint on the spin axis, so it
## turns in place instead of swinging round its feet (b2-11: it spun off camera).
func _centre(model: KaijuModel) -> void:
	var points := _skin_points(model)
	var box := AABB(points[0], Vector3.ZERO)
	for p: Vector3 in points:
		box = box.expand(p)
	var mid := box.get_center()
	model.position = -Vector3(mid.x, 0.0, mid.z)


## Frames the preview on the kaiju's skin at every angle of a full turn: aimed at the spin axis
## and stood back along the old camera's view until it fits the card's width and, with a margin
## top and bottom, its height (a long tail, a tall head never leave the card).
func _frame(cam: Camera3D, model: KaijuModel, size: Vector2i) -> void:
	var points := _skin_points(model)
	for i: int in points.size():
		points[i] += model.position
	var turns: Array[Basis] = []
	var box := AABB(points[0], Vector3.ZERO)
	for k: int in PREVIEW_SAMPLES:
		turns.append(Basis(Vector3.UP, TAU * k / PREVIEW_SAMPLES))
		for p: Vector3 in points:
			box = box.expand(turns[k] * p)
	var aim := Vector3(0.0, box.get_center().y, 0.0)
	var look := PREVIEW_VIEW.normalized()
	var up := look.cross(Vector3.UP).cross(look).normalized()
	var right := look.cross(up)
	var tan_v := tan(deg_to_rad(cam.fov) * 0.5) * (1.0 - 2.0 * PREVIEW_MARGIN)
	var tan_h := tan(deg_to_rad(cam.fov) * 0.5) * PREVIEW_FILL * size.x / size.y
	var back := 0.0
	for turn: Basis in turns:
		for p: Vector3 in points:
			var r := turn * p - aim
			var fit := maxf(absf(r.dot(up)) / tan_v, absf(r.dot(right)) / tan_h)
			back = maxf(back, fit - r.dot(look))
	cam.position = aim - look * back
	cam.look_at(aim)


## A sample of the skin's points (every PREVIEW_STRIDE-th corner) in the model's own space.
func _skin_points(model: KaijuModel) -> PackedVector3Array:
	var points: PackedVector3Array = []
	var from_model := model.global_transform.affine_inverse()
	for geo: Node in model.find_children("*", "MeshInstance3D", true, false):
		var g: MeshInstance3D = geo
		if g.mesh != null:
			var to_model := from_model * g.global_transform
			for surface: int in g.mesh.get_surface_count():
				var corners: PackedVector3Array = g.mesh.surface_get_arrays(surface)[
					Mesh.ARRAY_VERTEX
				]
				for i: int in range(0, corners.size(), PREVIEW_STRIDE):
					points.append(to_model * corners[i])
	return points


## The preview's size: beside the stats the wide card gives it a fixed size (never read off the
## window, which may still change size after the screen is built), else the small narrow size.
func _preview_size() -> Vector2i:
	return WIDE_PREVIEW if _wide else NARROW_PREVIEW


func _card(row: HBoxContainer, def: Dictionary) -> Button:
	var size := _preview_size()
	var panel := UiKit.panel()
	var width: float = WIDE_CARD_WIDTH if _wide else size.x + 28.0
	panel.custom_minimum_size = Vector2(width, 0)
	row.add_child(panel)
	cards.append(panel)
	var body: BoxContainer = HBoxContainer.new() if _wide else VBoxContainer.new()
	body.add_theme_constant_override("separation", int(WIDE_GAP) if _wide else 6)
	panel.add_child(body)
	_preview(body, def, size)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(INFO_WIDTH if _wide else 0.0, 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	body.add_child(col)
	col.add_child(UiKit.header(tr(str(def["name"])).to_upper(), UiKit.SIZE_HEAD))
	var blurb := UiKit.label(tr(str(def["blurb"])), UiKit.SIZE_BODY, UiKit.TEXT)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(blurb)
	var ability: Dictionary = def["ability"]
	var signature := tr("Signature: %s") % tr(str(ability["name"]))
	var sig := UiKit.label(signature, UiKit.SIZE_BODY, UiKit.WARN)
	sig.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(sig)
	var stats: Dictionary = def["stats"]
	col.add_child(_stat_grid(stats))
	var pick := UiKit.button(tr("CHOOSE"), UiKit.SIZE_HEAD)
	var id := str(def["id"])
	pick.pressed.connect(func() -> void: chosen.emit(id))
	col.add_child(pick)
	return pick


## The turntable preview: the species' model in its own world, lit and framed, spinning.
func _preview(body: Container, def: Dictionary, size: Vector2i) -> void:
	var view := SubViewportContainer.new()
	view.stretch = true
	view.custom_minimum_size = Vector2(size)
	view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(view)
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	view.add_child(viewport)
	var colors: Dictionary = def["colors"]
	var table := Node3D.new()
	table.rotation.y = PREVIEW_YAW
	viewport.add_child(table)
	turntables.append(table)
	var model := KaijuModel.new(str(def["id"]), colors)
	table.add_child(model)
	_centre(model)
	_models.append(model)
	var cam := Camera3D.new()
	cam.fov = PREVIEW_FOV
	viewport.add_child(cam)
	_frame(cam, model, size)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	viewport.add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-6, 6, 8)
	fill.omni_range = 30.0
	fill.light_energy = 0.8
	viewport.add_child(fill)


func _stat_name(english: String) -> String:
	var names := {
		"Health": tr("Health"), "Speed": tr("Speed"), "Power": tr("Power"), "Reach": tr("Reach")
	}
	return str(names.get(english, tr(english)))


## The stat meters: one a row beside the preview; two a row when several cards share the screen.
func _stat_grid(stats: Dictionary) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 1 if _wide else 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 6)
	for entry: Array in COMPARE:
		var line := HBoxContainer.new()
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_theme_constant_override("separation", 12)
		var name_label := UiKit.label(
			_stat_name(str(entry[0])), SIZE_STAT if _wide else SIZE_STAT_NARROW
		)
		name_label.custom_minimum_size = Vector2(STAT_NAME_WIDTH if _wide else NARROW_STAT_NAME, 0)
		line.add_child(name_label)
		var share := Num.f(stats.get(str(entry[1]), 0.0)) / Num.f(entry[2])
		var meter := UiMarks.Cells.new(
			STAT_CELLS,
			clampi(roundi(share * STAT_CELLS), 1, STAT_CELLS),
			MIN_CELL if _wide else NARROW_MIN_CELL,
			22.0 if _wide else 18.0
		)
		meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(meter)
		grid.add_child(line)
	return grid
