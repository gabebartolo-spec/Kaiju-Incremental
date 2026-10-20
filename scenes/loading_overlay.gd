class_name LoadingOverlay
extends CanvasLayer
## What the player sees while a rampage builds its city (b2-30): the backdrop, one word and a
## meter that moves each time a stage finishes, so the wait never looks like a hung game.
## Each stage the builder reports (advance) is drawn before the next one starts.

const LAYER := 60
## The stages a rampage build reports (CityView and Rampage); the meter is full at this many.
const STAGES := 12

var _bar: ProgressBar
var _done := 0


func _init() -> void:
	layer = LAYER


func _ready() -> void:
	add_child(UiKit.backdrop())
	var col := VBoxContainer.new()
	UiKit.full_rect(col)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 24)
	add_child(col)
	var word := UiKit.label("LOADING", UiKit.SIZE_TITLE, UiKit.ACCENT)
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(word)
	_bar = UiKit.bar(UiKit.ACCENT, 26, true)
	_bar.custom_minimum_size = Vector2(720, 26)
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bar.max_value = STAGES
	_bar.value = _done
	col.add_child(_bar)


## One more stage is built.
func advance() -> void:
	_done += 1
	if _bar != null:
		_bar.value = _done
