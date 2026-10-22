class_name DemoEnd
extends Control
## The demo's thanks screen (D-050, D-145, D-152, D-156). It follows the final upgrade: the adult
## stands beside the tower it would topple, on the reveal's own set and camera (RevealStage), under
## the demo lines and the rampage totals (Demo.rows, counted by the sim). Leave feedback opens the
## invite-only Itch page's comments (D-148), Try Endless mode starts Endless mode (unlocked by the
## final upgrade), Keep playing returns to the tree (normal mode). It roars only from a baked clip
## (ClipGait, D-047): the procedural roar drops the jaw straight down. The save is untouched.

signal keep_pressed
signal endless_pressed
signal feedback_pressed

## Frame-paced like the reveal: a clip roar on arrival, then again every ROAR_EVERY frames (the
## clip gait idles in between).
const ROAR_EVERY := 360
const BUTTON_WIDTH := 400
const STAT_WIDTH := 220

## What the card stages (read by the flow suite).
var species_id: String
var stage: String
## True when the kaiju roars from a baked clip; roars counts the roars asked for, and
## roar_sounds the croc roars heard with them (Sfx.roar, D-055).
var clip_roar := false
var roars := 0
## The 3D frame (read by the flow suite).
var view: SubViewportContainer
var roar_sounds := 0
## Opens a URL (tests swap it so no browser opens).
var opener := Callable(OS, "shell_open")
## The totals shown, and the rows drawn from them (read by the flow suite).
var totals: Dictionary
var stat_values: Array[String] = []
var _colors: Dictionary
var _scale: float
var _floors: int
var _kaiju: KaijuModel
var _frame := 0


## species: the save's species; base_stats: tuning "kaiju" (the thanks size tier goes on top);
## p_totals: the save's demo totals (Demo.add).
func setup(species: Dictionary, base_stats: Dictionary, p_totals: Dictionary) -> void:
	species_id = str(species["id"])
	_colors = species["colors"]
	totals = p_totals
	var stats := base_stats.duplicate()
	stats["size"] = Num.i(Content.section("demo")["thanks_size"])
	var city: Dictionary = CityGrowth.for_stats(stats)["city"]
	stage = KaijuModel.stage_for(Num.i(stats["size"]))
	_scale = Growth.body_scale(stats, city)
	_floors = RevealStage.tower_floors(Num.i(stats["size"]), city)


func _ready() -> void:
	UiKit.full_rect(self)
	add_child(UiKit.backdrop())
	var col := VBoxContainer.new()
	UiKit.full_rect(col)
	col.offset_top = EvolutionReveal.EDGE_MARGIN
	col.offset_bottom = -EvolutionReveal.EDGE_MARGIN
	col.add_theme_constant_override("separation", 12)
	add_child(col)
	view = EvolutionReveal.frame_view(self)  # the reveal's frame, same size and place
	col.add_child(view)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	view.add_child(viewport)
	RevealStage.build(viewport, _scale, _floors)
	_kaiju = KaijuModel.new(species_id, _colors, stage)
	_kaiju.scale = Vector3.ONE * _scale
	_kaiju.rotation.y = PI * 0.8
	viewport.add_child(_kaiju)
	clip_roar = has_clip_roar(_kaiju)
	var demo := Content.section("demo")
	var headline := UiKit.label(str(demo["end_title"]), UiKit.SIZE_TITLE, UiKit.ACCENT)
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(headline)
	var line := UiKit.label(str(demo["end_line"]), UiKit.SIZE_HEAD, UiKit.TEXT)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(line)
	col.add_child(_stats_grid())
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	col.add_child(row)
	_button(row, "LEAVE FEEDBACK", UiKit.PANEL_EDGE).pressed.connect(_on_feedback)
	var endless := _button(row, "TRY ENDLESS MODE", UiKit.ACCENT)
	endless.pressed.connect(func() -> void: endless_pressed.emit())
	_button(row, "KEEP PLAYING", UiKit.PANEL_EDGE).pressed.connect(
		func() -> void: keep_pressed.emit()
	)
	endless.grab_focus.call_deferred()


## The rampage totals, label left and figure right, two columns wide.
func _stats_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 6)
	for row: PackedStringArray in Demo.rows(totals):
		var name_label := UiKit.label(row[0], UiKit.SIZE_BODY, UiKit.MUTED)
		grid.add_child(name_label)
		var value := UiKit.label(row[1], UiKit.SIZE_HEAD, UiKit.TEXT)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.custom_minimum_size = Vector2(STAT_WIDTH, 0)
		grid.add_child(value)
		stat_values.append(row[1])
	return grid


func _on_feedback() -> void:
	feedback_pressed.emit()
	opener.call(Demo.feedback_url())


func _process(delta: float) -> void:
	if clip_roar and _frame % ROAR_EVERY == 0:
		_kaiju.roar()
		roars += 1
		Sfx.roar(self)
		roar_sounds += 1
	_frame += 1
	_kaiju.animate(delta, 0.0)


## True when `model` roars from a baked clip (its rig's gait is ClipGait, D-047). Named, not typed:
## ClipGait lands in its own PR, and until then no rig has one.
static func has_clip_roar(model: KaijuModel) -> bool:
	for node: Node in model.find_children("*", "", true, false):
		if node is KaijuRig:
			var gait: KaijuGait = (node as KaijuRig).gait
			var script: Script = gait.get_script() if gait != null else null
			return script != null and script.get_global_name() == "ClipGait"
	return false


func _button(row: HBoxContainer, text: String, fill: Color) -> Button:
	var b := UiKit.button(text, UiKit.SIZE_HEAD, fill)
	b.custom_minimum_size = Vector2(BUTTON_WIDTH, 0)
	row.add_child(b)
	return b
