class_name NewsTicker
extends Control
## The emergency-broadcast crawl: a red strip along the bottom of a screen with a black
## "BREAKING" tag and the city's news about you scrolling past. Presentation only.

const HEIGHT := 56.0
## Crawl speed in px per second at 1080p (the UI scales with the window).
const SPEED := 120.0
const TAG_WIDTH := 210.0
const SEPARATOR := "   ///   "

var _crawl: Label
var _tag: Label


## lines: the headlines, read left to right and repeated.
func _init(lines: PackedStringArray) -> void:
	custom_minimum_size = Vector2(0, HEIGHT)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var strip := ColorRect.new()
	strip.color = UiKit.ALERT
	UiKit.full_rect(strip)
	add_child(strip)
	_crawl = UiKit.label(SEPARATOR.join(lines) + SEPARATOR, UiKit.SIZE_BODY, Color.WHITE)
	_crawl.position = Vector2(TAG_WIDTH, (HEIGHT - _crawl.get_minimum_size().y) / 2.0)
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


func _process(delta: float) -> void:
	var loop := _crawl.get_minimum_size().x
	_crawl.position.x -= SPEED * delta
	if _crawl.position.x < TAG_WIDTH - loop:
		_crawl.position.x += loop
