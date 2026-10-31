class_name LoadingOverlay
extends CanvasLayer
## What the player sees while a rampage builds its city (b2-30): the broadcast backdrop, one
## alert header, a meter that moves each time a stage finishes (so the wait never looks like a
## hung game) and the news crawl (tuning "ui" loading_news).
## Behind them, one 4K still of a real dusk rampage, random each load and never the same twice
## in a row (comment #92, D-140, D-427; tools/capture/capture_load_art.gd took them).
## Each stage the builder reports (advance) is drawn before the next one starts.

const LAYER := 60
## The stages a rampage build reports (Rampage 3, CityView with decor 4); the meter is full at
## this many (pinned by tests/lib/flow_staged_start.gd).
const STAGES := 7
## The meter's size and the gap between the word and the meter (px).
const BAR_SIZE := Vector2(720, 26)
const GAP := 24
## The stills (assets/loading), loaded one at a time: each is 4K.
const STILLS: Array[String] = [
	"res://assets/loading/s1_form_side.jpg",
	"res://assets/loading/s1_lash_hero.jpg",
	"res://assets/loading/s2_form_hero.jpg",
	"res://assets/loading/s2_smash_side.jpg",
	"res://assets/loading/s2_breath_side.jpg",
	"res://assets/loading/s2_lash_over.jpg",
	"res://assets/loading/s2_after_pano.jpg",
	"res://assets/loading/s3_form_side.jpg",
	"res://assets/loading/s3_breath_side.jpg",
	"res://assets/loading/s3_lash_over.jpg",
	"res://assets/loading/s3_beam_over.jpg",
	"res://assets/loading/s3_beam_pano.jpg",
]
## The dark band behind the word and the meter, so they read over any still. It sits low, just
## above the crawl, so the kaiju in the middle of the frame stays in view (D-140).
const BAND := Color(0.043, 0.043, 0.051, 0.72)
const BAND_PAD := 28
const BAND_LIFT := 40

## The still shown last, so the next load picks another.
static var _last := -1

var _bar: ProgressBar
var _done := 0


func _init() -> void:
	layer = LAYER


func _ready() -> void:
	add_child(UiKit.backdrop())
	add_child(_still())
	# No tape along the top edge on any screen (director 2026-10-25: "remove yellow bar at top").
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", GAP)
	var band := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = BAND
	box.content_margin_top = BAND_PAD
	box.content_margin_bottom = BAND_PAD
	band.add_theme_stylebox_override("panel", box)
	band.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	band.grow_vertical = Control.GROW_DIRECTION_BEGIN
	band.offset_top = -(NewsTicker.HEIGHT + BAND_LIFT)
	band.offset_bottom = band.offset_top
	band.add_child(col)
	add_child(band)
	var word := UiKit.header(tr("INCOMING"))
	word.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(word)
	_bar = UiKit.bar(UiKit.ACCENT, int(BAR_SIZE.y), true)
	_bar.custom_minimum_size = BAR_SIZE
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bar.max_value = STAGES
	_bar.value = _done
	col.add_child(_bar)
	if FacadeBake.first_load():  # D-415: the first load bakes the facades, up to half a minute
		var note := UiKit.label(
			tr("First load takes longer (up to half a minute). Nothing is frozen.")
		)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(note)
	var news: Array = UiKit.ui()["loading_news"]
	var lines := PackedStringArray()
	for line: Variant in news:
		lines.append(tr(str(line)))
	var crawl := NewsTicker.new(lines)
	crawl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	crawl.offset_top = -NewsTicker.HEIGHT
	add_child(crawl)


## A still other than the last one shown, filling the screen (cropped, never stretched).
func _still() -> TextureRect:
	var pick := randi() % (STILLS.size() - 1)
	if pick >= _last and _last >= 0:
		pick += 1
	_last = pick
	var r := TextureRect.new()
	r.texture = load(STILLS[pick])
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(r)
	return r


## How many stages are built so far.
func done() -> int:
	return _done


## One more stage is built.
func advance() -> void:
	_done += 1
	if _bar != null:
		_bar.value = _done
