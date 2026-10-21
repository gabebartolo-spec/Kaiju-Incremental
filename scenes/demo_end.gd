class_name DemoEnd
extends Control
## The demo's last screen (D-050). After the demo's end evolution and its reveal (and on every
## Continue after it), the stage the full game holds next (data "demo.tease_size": the adult)
## stands beside the tower it would topple, on the reveal's own set and camera (RevealStage),
## under the demo lines from data/tuning.json "demo". It roars only from a baked clip (ClipGait,
## D-047): the procedural roar drops the jaw straight down, so a rig without clips stands idle.
## Title or Quit; the save is untouched.

signal title_pressed

## Frame-paced like the reveal: a clip roar on arrival, then again every ROAR_EVERY frames (the
## clip gait idles in between).
const ROAR_EVERY := 360
const BUTTON_WIDTH := 320
## The card draws the scene at 80% and shifted right by this share of the picture, so the croc
## keeps a clear margin on every side (critic r2: head cut at the left, feet at the bottom).
const VIEW_BACK := 1.25
const VIEW_SHIFT := 0.1

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
	col.add_theme_constant_override("separation", 12)
	add_child(col)
	view = EvolutionReveal.frame_view(self)  # the reveal's frame, same size and place
	col.add_child(EvolutionReveal.frame_around(view))
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	view.add_child(viewport)
	RevealStage.build(viewport, _scale, _floors, VIEW_BACK, VIEW_SHIFT)
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
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	col.add_child(row)
	var title := _button(row, "MAIN MENU", UiKit.ACCENT)
	title.pressed.connect(func() -> void: title_pressed.emit())
	if not OS.has_feature("web"):
		_button(row, "QUIT", UiKit.PANEL_EDGE).pressed.connect(
			func() -> void: QuitGame.now(get_tree())
		)
	title.grab_focus.call_deferred()


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
