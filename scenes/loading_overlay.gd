class_name LoadingOverlay
extends CanvasLayer
## What the player sees while a rampage builds its city (b2-30): the broadcast backdrop, one
## alert header, a meter that moves each time a stage finishes (so the wait never looks like a
## hung game) and the news crawl (tuning "ui" loading_news).
## Each stage the builder reports (advance) is drawn before the next one starts.

const LAYER := 60
## The stages a rampage build reports (Rampage 3, CityView with decor 4); the meter is full at
## this many (pinned by tests/lib/flow_staged_start.gd).
const STAGES := 7
## The meter's size and the gap between the word and the meter (px).
const BAR_SIZE := Vector2(720, 26)
const GAP := 24

var _bar: ProgressBar
var _done := 0


func _init() -> void:
	layer = LAYER


func _ready() -> void:
	add_child(UiKit.backdrop())
	var top := UiKit.tape(18.0)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 18.0
	add_child(top)
	var col := VBoxContainer.new()
	UiKit.full_rect(col)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", GAP)
	add_child(col)
	var word := UiKit.header("INCOMING", UiKit.SIZE_TITLE, false)
	word.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(word)
	_bar = UiKit.bar(UiKit.ACCENT, int(BAR_SIZE.y), true)
	_bar.custom_minimum_size = BAR_SIZE
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bar.max_value = STAGES
	_bar.value = _done
	col.add_child(_bar)
	var news: Array = UiKit.ui()["loading_news"]
	var crawl := NewsTicker.new(PackedStringArray(news))
	crawl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	crawl.offset_top = -NewsTicker.HEIGHT
	add_child(crawl)


## How many stages are built so far.
func done() -> int:
	return _done


## One more stage is built.
func advance() -> void:
	_done += 1
	if _bar != null:
		_bar.value = _done
