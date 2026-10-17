class_name SpeciesSelect
extends Control
## New game: pick one of the species. Each card shows the kaiju turning in a live 3D preview,
## its signature attack and how its body compares, so the choice is about how it plays.

signal chosen(species_id: String)

## Short enough that the whole card (and CHOOSE) fits the TV at the largest UI scale (125%).
const PREVIEW_SIZE := Vector2i(440, 270)
## The preview camera looks down this way (the old fixed camera's view) through a fairly long lens
## (deg; a near limb swinging toward a wide lens would push the kaiju small); the turning kaiju
## fills at most this much of the card's width and keeps this margin (of the height) top and bottom.
const PREVIEW_VIEW := Vector3(0, -2.9, -12.5)
const PREVIEW_FOV := 30.0
const PREVIEW_FILL := 0.92
const PREVIEW_MARGIN := 0.06
## Height bands the skin's reach is measured in (the fit's resolution).
const PROFILE_BANDS := 8
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
	col.add_theme_constant_override("separation", 16)
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


## Frames the preview on everything the turning kaiju sweeps through (its skin's farthest reach
## from the spin axis in each height band, turned through every angle): aimed at its middle and
## stood back along the old camera's view until it fits the card's width and, with a margin top
## and bottom, its height, so no species leaves its card as it turns (a long tail, a tall head).
func _frame(cam: Camera3D, model: KaijuModel) -> void:
	var profile := _profile(model)
	var look := PREVIEW_VIEW.normalized()
	var up := look.cross(Vector3.UP).cross(look).normalized()
	var right := look.cross(up)
	var tan_v := tan(deg_to_rad(cam.fov) * 0.5) * (1.0 - 2.0 * PREVIEW_MARGIN)
	var tan_h := tan(deg_to_rad(cam.fov) * 0.5) * PREVIEW_FILL * PREVIEW_SIZE.x / PREVIEW_SIZE.y
	var aim := Vector3(0, (profile[0].y + profile[profile.size() - 1].y) * 0.5, 0)
	var back := 0.0
	for ring: Vector2 in profile:
		for k: int in 16:
			var a := TAU * k / 16.0
			var r := Vector3(cos(a) * ring.x, ring.y, sin(a) * ring.x) - aim
			var fit := maxf(absf(r.dot(up)) / tan_v, absf(r.dot(right)) / tan_h)
			back = maxf(back, fit - r.dot(look))
	cam.position = model.position + aim - look * back
	cam.look_at(model.position + aim)


## The skin's reach from the spin axis (x) at the bottom and top of PROFILE_BANDS height bands (y),
## bottom first, in the model's own space.
func _profile(model: KaijuModel) -> Array[Vector2]:
	var points: PackedVector3Array = []
	for geo: Node in model.find_children("*", "MeshInstance3D", true, false):
		var g: MeshInstance3D = geo
		if g.mesh != null:
			var to_model := model.global_transform.affine_inverse() * g.global_transform
			for v: Vector3 in g.mesh.get_faces():
				points.append(to_model * v)
	var low := INF
	var high := -INF
	for p: Vector3 in points:
		low = minf(low, p.y)
		high = maxf(high, p.y)
	var reach: Array[float] = []
	reach.resize(PROFILE_BANDS)
	reach.fill(0.0)
	var band := maxf(high - low, 0.001) / PROFILE_BANDS
	for p: Vector3 in points:
		var i := mini(int((p.y - low) / band), PROFILE_BANDS - 1)
		reach[i] = maxf(reach[i], Vector2(p.x, p.z).length())
	var out: Array[Vector2] = []
	for i: int in PROFILE_BANDS:
		out.append(Vector2(reach[i], low + band * i))
		out.append(Vector2(reach[i], low + band * (i + 1)))
	return out


func _card(row: HBoxContainer, def: Dictionary) -> Button:
	var panel := UiKit.panel()
	panel.custom_minimum_size = Vector2(PREVIEW_SIZE.x + 28, 0)
	row.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
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
	cam.fov = PREVIEW_FOV
	viewport.add_child(cam)
	_frame(cam, model)
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
