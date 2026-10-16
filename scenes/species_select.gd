class_name SpeciesSelect
extends Control
## New game: pick one of the species. Each card shows the kaiju turning in a live 3D preview,
## its signature attack and how its body compares, so the choice is about how it plays.

signal chosen(species_id: String)

const PREVIEW_SIZE := Vector2i(460, 380)
const COMPARE: Array[Array] = [
	["Health", "hp", 150.0],
	["Speed", "speed", 8.0],
	["Power", "stomp_damage", 12.0],
	["Reach", "stomp_radius", 4.0]
]

var _models: Array[KaijuModel] = []


func _ready() -> void:
	UiKit.full_rect(self)
	add_child(UiKit.backdrop())
	var col := VBoxContainer.new()
	UiKit.full_rect(col)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 28)
	add_child(col)
	var title := UiKit.label("CHOOSE YOUR KAIJU", UiKit.SIZE_TITLE, UiKit.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 32)
	col.add_child(row)
	var first: Button = null
	for def: Dictionary in Content.species():
		var pick := _card(row, def)
		if first == null:
			first = pick
	if first != null:
		first.grab_focus.call_deferred()


func _process(delta: float) -> void:
	for model: KaijuModel in _models:
		model.rotation.y += delta * 0.35
		model.animate(delta, 0.3)


func _card(row: HBoxContainer, def: Dictionary) -> Button:
	var panel := UiKit.panel()
	panel.custom_minimum_size = Vector2(PREVIEW_SIZE.x + 28, 0)
	row.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	var view := SubViewportContainer.new()
	view.stretch = true
	view.custom_minimum_size = Vector2(PREVIEW_SIZE)
	col.add_child(view)
	var viewport := SubViewport.new()
	viewport.size = PREVIEW_SIZE
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	view.add_child(viewport)
	var colors: Dictionary = def["colors"]
	var model := KaijuModel.new(str(def["id"]), colors)
	viewport.add_child(model)
	model.rotation.y = PI * 0.75
	_models.append(model)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 6.5, 12.5)
	cam.fov = 45.0
	viewport.add_child(cam)
	cam.look_at(Vector3(0, 3.6, 0))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	viewport.add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-6, 6, 8)
	fill.omni_range = 30.0
	fill.light_energy = 0.8
	viewport.add_child(fill)

	col.add_child(UiKit.label(str(def["name"]).to_upper(), UiKit.SIZE_HEAD, UiKit.TEXT))
	var blurb := UiKit.label(str(def["blurb"]), UiKit.SIZE_SMALL, UiKit.MUTED)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(blurb)
	var ability: Dictionary = def["ability"]
	col.add_child(UiKit.label("Signature: %s" % str(ability["name"]), UiKit.SIZE_BODY, UiKit.WARN))
	var hint := UiKit.label(str(ability["hint"]), UiKit.SIZE_SMALL, UiKit.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(hint)

	var stats: Dictionary = def["stats"]
	for entry: Array in COMPARE:
		var line := HBoxContainer.new()
		var name_label := UiKit.label(str(entry[0]), UiKit.SIZE_SMALL)
		name_label.custom_minimum_size = Vector2(110, 0)
		line.add_child(name_label)
		var meter := UiKit.bar(UiKit.ACCENT, 18)
		meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		meter.max_value = Num.f(entry[2])
		meter.value = Num.f(stats.get(str(entry[1]), 0.0))
		line.add_child(meter)
		col.add_child(line)

	var pick := UiKit.button("CHOOSE", UiKit.SIZE_HEAD)
	var id := str(def["id"])
	pick.pressed.connect(func() -> void: chosen.emit(id))
	col.add_child(pick)
	return pick
