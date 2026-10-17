class_name EvolutionReveal
extends Control
## Plays when an evolution is bought: the kaiju as it was stands beside a tower, shakes, a flash,
## and it is the next stage (baby -> adolescent -> adult, KaijuModel.stage_for) at its new size,
## roaring. The tower is the tallest the new body topples without undermining it (its size tier
## x the city's tier height), so the comparison is a play fact. Skippable; reports `done`.

signal done

## Frame-paced (captures and tests see the same thing on any machine).
const SWAP_FRAME := 54
const GROW_FRAMES := 24
const END_FRAME := 230
const SKIP_AFTER := 8
## The 3D view fills what the text leaves, at most this big (so the lines below it stay on
## screen at every UI scale).
const VIEW_MAX := Vector2(1200, 760)
const EDGE_MARGIN := 48.0

var frame := 0
var stage_before: String
var stage_after: String
var scale_before: float
var scale_after: float
## The tallest tower (floors) the new body brings down without undermining it.
var tower_floors: int
## The size lines under the headline (read by the flow suite's on-screen check).
var lines: Label
var _species: Dictionary
var _viewport: SubViewport
var _kaiju: KaijuModel
var _camera: Camera3D
var _flash: ColorRect
var _headline: Label
var _finished := false


## before / after: run stats either side of the purchase; city: the new stage's tuning "city"
## (CityGrowth.for_stats(after)["city"]): its height cap is the tallest tower there is.
func setup(species: Dictionary, before: Dictionary, after: Dictionary, city: Dictionary) -> void:
	_species = species
	stage_before = KaijuModel.stage_for(Num.i(before.get("size", 1)))
	stage_after = KaijuModel.stage_for(Num.i(after.get("size", 1)))
	scale_before = Growth.body_scale(before, city)
	scale_after = Growth.body_scale(after, city)
	tower_floors = RevealStage.tower_floors(Num.i(after.get("size", 1)), city)


func _ready() -> void:
	UiKit.full_rect(self)
	# The reveal holds focus (and keeps it), so a confirm skips it instead of reaching the tree
	# underneath and buying the node again.
	focus_mode = Control.FOCUS_ALL
	for side: String in ["left", "top", "right", "bottom"]:
		set("focus_neighbor_" + side, NodePath("."))
	focus_next = NodePath(".")
	focus_previous = NodePath(".")
	add_child(UiKit.backdrop())
	var col := VBoxContainer.new()
	UiKit.full_rect(col)
	col.offset_top = EDGE_MARGIN
	col.offset_bottom = -EDGE_MARGIN  # keeps the skip hint off the bottom edge
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)
	add_child(col)
	var view := SubViewportContainer.new()
	view.stretch = true
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	view.resized.connect(func() -> void: _fit_view(view))
	col.add_child(view)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	view.add_child(_viewport)
	_camera = RevealStage.build(_viewport, scale_after, tower_floors)
	_headline = UiKit.label("EVOLVING...", UiKit.SIZE_TITLE, UiKit.ACCENT)
	_headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_headline)
	lines = UiKit.label("", UiKit.SIZE_HEAD, UiKit.TEXT)
	lines.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(lines)
	var hint := UiKit.label("Enter / A to skip", UiKit.SIZE_BODY, UiKit.MUTED.lightened(0.45))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(_flash)
	add_child(_flash)
	_place_kaiju(stage_before, scale_before)
	grab_focus.call_deferred()


## Keeps the view at the screen's spare height (capped at VIEW_MAX), wide in the same ratio.
func _fit_view(view: SubViewportContainer) -> void:
	var h := minf(VIEW_MAX.y, view.size.y)
	view.custom_minimum_size.x = h * VIEW_MAX.x / VIEW_MAX.y


func _process(delta: float) -> void:
	if _finished:
		return
	frame += 1
	if frame == SWAP_FRAME:
		_swap()
	var shake := 0.0
	if frame < SWAP_FRAME:
		shake = 0.25 * float(frame) / SWAP_FRAME
	elif frame < SWAP_FRAME + GROW_FRAMES:
		var t := float(frame - SWAP_FRAME) / GROW_FRAMES
		_kaiju.scale = Vector3.ONE * lerpf(scale_before, scale_after, ease(t, 0.3))
		shake = 0.4 * (1.0 - t)
	_flash.color.a = maxf(0.0, _flash.color.a - delta * 1.6)
	_kaiju.position.x = sin(frame * 1.9) * shake
	_kaiju.animate(delta, 0.0)
	if frame >= END_FRAME:
		finish()


func _gui_input(event: InputEvent) -> void:
	var click := event is InputEventMouseButton and event.is_pressed()
	if click or event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		accept_event()
		_try_skip()


## True once the new stage is on screen.
func revealed() -> bool:
	return frame >= SWAP_FRAME


func finish() -> void:
	if _finished:
		return
	_finished = true
	done.emit()
	queue_free()


func _try_skip() -> void:
	if frame >= SKIP_AFTER:
		finish()


func _swap() -> void:
	_place_kaiju(stage_after, scale_before)
	_kaiju.roar()
	_flash.color.a = 0.9
	_headline.text = "%s  %s" % [str(_species["name"]).to_upper(), stage_after.to_upper()]
	var floors_before := roundi(KaijuModel.MODEL_HEIGHT * scale_before)
	var floors_after := roundi(KaijuModel.MODEL_HEIGHT * scale_after)
	lines.text = (
		"Stands %d floors tall (was %d)\nTowers up to %d floors now fall to you"
		% [floors_after, floors_before, tower_floors]
	)


func _place_kaiju(stage: String, body_scale: float) -> void:
	if _kaiju != null:
		_kaiju.queue_free()
	var colors: Dictionary = _species["colors"]
	_kaiju = KaijuModel.new(str(_species["id"]), colors, stage)
	_kaiju.scale = Vector3.ONE * body_scale
	_kaiju.rotation.y = PI * 0.8
	_viewport.add_child(_kaiju)
