class_name DemoEnd
extends Control
## The demo's last screen (D-050). After the demo's end evolution and its reveal (and on every
## Continue after it), the stage the full game holds next (data "demo.tease_size": the adult)
## roars beside the tower it would topple, on the reveal's own set and camera (RevealStage),
## under the demo lines from data/tuning.json "demo". Title or Quit; the save is untouched.

signal title_pressed

## Frame-paced like the reveal: the kaiju roars on arrival, then again every ROAR_EVERY frames.
const ROAR_EVERY := 240
const BUTTON_WIDTH := 320

## What the card stages (read by the flow suite).
var species_id: String
var stage: String
var roars := 0
var _colors: Dictionary
var _scale: float
var _floors: int
var _kaiju: KaijuModel
var _frame := 0


## species: the save's species; base_stats: tuning "kaiju" (the tease's size tier goes on top).
func setup(species: Dictionary, base_stats: Dictionary) -> void:
	species_id = str(species["id"])
	_colors = species["colors"]
	var stats := base_stats.duplicate()
	stats["size"] = Num.i(Content.section("demo")["tease_size"])
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
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)
	add_child(col)
	var view := SubViewportContainer.new()
	view.stretch = true
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	view.resized.connect(func() -> void: _fit_view(view))
	col.add_child(view)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	view.add_child(viewport)
	RevealStage.build(viewport, _scale, _floors)
	_kaiju = KaijuModel.new(species_id, _colors, stage)
	_kaiju.scale = Vector3.ONE * _scale
	_kaiju.rotation.y = PI * 0.8
	viewport.add_child(_kaiju)
	var demo := Content.section("demo")
	var headline := UiKit.label(str(demo["end_title"]), UiKit.SIZE_TITLE, UiKit.ACCENT)
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(headline)
	var line := UiKit.label(str(demo["end_line"]), UiKit.SIZE_HEAD, UiKit.TEXT)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(line)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	col.add_child(row)
	var title := _button(row, "TITLE", UiKit.ACCENT)
	title.pressed.connect(func() -> void: title_pressed.emit())
	if not OS.has_feature("web"):
		_button(row, "QUIT", UiKit.PANEL_EDGE).pressed.connect(func() -> void: get_tree().quit())
	title.grab_focus.call_deferred()


func _process(delta: float) -> void:
	if _frame % ROAR_EVERY == 0:
		_kaiju.roar()
		roars += 1
	_frame += 1
	_kaiju.animate(delta, 0.0)


func _button(row: HBoxContainer, text: String, fill: Color) -> Button:
	var b := UiKit.button(text, UiKit.SIZE_HEAD, fill)
	b.custom_minimum_size = Vector2(BUTTON_WIDTH, 0)
	row.add_child(b)
	return b


## Keeps the view at the screen's spare height (capped like the reveal's), wide in its ratio.
func _fit_view(view: SubViewportContainer) -> void:
	var cap := EvolutionReveal.VIEW_MAX
	view.custom_minimum_size.x = minf(cap.y, view.size.y) * cap.x / cap.y
