class_name NewsTicker
extends Control
## The emergency-broadcast crawl: a red strip along the bottom of a screen with a black
## "BREAKING" tag and the city's news about you scrolling past. Presentation only.

const HEIGHT := 56.0
## Crawl speed in px per second at 1080p (the UI scales with the window).
const SPEED := 120.0
## The black tag bleeds off the screen's edge and its label is centred in it (director 2026-10-25:
## "centre the text in black rectangle"), so the tag is the label's width plus the TV title-safe
## margin (UiKit.safe_margin: 96 px at 1080p, 192 at 4K) on each side.
const TAG_WIDTH := 350.0
const SEPARATOR := "   ///   "
## The strip shows two cycles of headlines; each cycle is padded to at least the strip's width,
## so a short list never shows a headline twice at once and the loop has no empty stretch.
const REPEAT := 2

## The strip behind the text (read by the flow suite's contrast check).
var strip: ColorRect
var _crawl: Label
var _unit := ""
var _headlines := ""
var _tag: Label


## lines: the headlines, read left to right and repeated.
func _init(lines: PackedStringArray) -> void:
	custom_minimum_size = Vector2(0, HEIGHT)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip = ColorRect.new()
	strip.color = UiKit.CRAWL_RED
	UiKit.full_rect(strip)
	add_child(strip)
	_headlines = SEPARATOR.join(lines) + SEPARATOR
	_unit = _headlines
	_crawl = UiKit.label(_unit.repeat(REPEAT), UiKit.SIZE_BODY, Color.WHITE)
	resized.connect(_fit_cycle)
	# The strip's full height with the text centred in it (the font is only known in the tree).
	_crawl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_crawl.position = Vector2(TAG_WIDTH, 0.0)
	_crawl.size.y = HEIGHT
	add_child(_crawl)
	var tag_box := ColorRect.new()
	tag_box.color = UiKit.BG
	tag_box.size = Vector2(TAG_WIDTH, HEIGHT)
	add_child(tag_box)
	_tag = UiKit.label("BREAKING", UiKit.SIZE_HEAD, UiKit.ACCENT)
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tag.size = Vector2(TAG_WIDTH, HEIGHT)
	tag_box.add_child(_tag)


## A strip sized before it entered the tree never heard its own resize: pad the cycle now.
func _ready() -> void:
	_fit_cycle()


func _process(delta: float) -> void:
	var loop := _crawl.get_minimum_size().x / REPEAT
	_crawl.position.x -= SPEED * delta
	if _crawl.position.x < TAG_WIDTH - loop:
		_crawl.position.x += loop


## Pads one cycle with spaces until it spans the strip, then shows REPEAT cycles.
func _fit_cycle() -> void:
	if not is_inside_tree():
		return
	_unit = _headlines
	var space := (
		_crawl
		. get_theme_font("font")
		. get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.SIZE_BODY)
		. x
	)
	var short := visible_width() - unit_width()
	if short > 0.0 and space > 0.0:
		_unit += " ".repeat(ceili(short / space))
	_crawl.text = _unit.repeat(REPEAT)


## The width of one cycle of headlines (px): at least the visible strip, so no headline shows
## twice on screen at once.
func unit_width() -> float:
	var font := _crawl.get_theme_font("font")
	return font.get_string_size(_unit, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.SIZE_BODY).x


## The width of the headlines once, without the padding (px).
func headlines_width() -> float:
	var font := _crawl.get_theme_font("font")
	return font.get_string_size(_headlines, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.SIZE_BODY).x


## The width of strip the text crawls across (px).
func visible_width() -> float:
	return size.x - TAG_WIDTH
