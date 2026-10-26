class_name ThreatBadge
extends PanelContainer
## The threat badge beside the clock (D-259 "A small threat icon", 1-5): an emergency-broadcast box
## with the word THREAT, the level as a number and a five-bar meter that lights one bar per level,
## so the level reads by number and shape, never by colour alone (accessibility "Colour-blind safe
## cues"). From tuning "ui" threat_badge alert_from the box turns alert red; a rise pops it.
## Reads RunNews.level through `show_level`; presentation only.

var level := 0
var digit: Label
var meter: Bars
var _cfg: Dictionary
var _style: HazardBox
var _pop: Tween


func _init() -> void:
	_cfg = UiKit.ui()["threat_badge"]
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style = UiKit.hazard(UiKit.BG, UiKit.ACCENT, Num.f(_cfg["border"]))
	var pad: Array = _cfg["pad"]
	_style.content_margin_left = Num.f(pad[0])
	_style.content_margin_right = Num.f(pad[0])
	_style.content_margin_top = Num.f(pad[1])
	_style.content_margin_bottom = Num.f(pad[1])
	add_theme_stylebox_override("panel", _style)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", Num.i(_cfg["gap"]))
	add_child(row)
	var word := UiKit.label("THREAT", UiKit.SIZE_BODY, UiKit.TEXT)
	word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(word)
	digit = UiKit.label("1", Num.i(_cfg["digit_size"]), UiKit.ACCENT)
	digit.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(digit)
	meter = Bars.new(_cfg)
	meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(meter)
	resized.connect(func() -> void: pivot_offset = size / 2.0)
	show_level(1, false)


## Shows `n`; `pop`: the level just rose (the badge swells and settles back).
func show_level(n: int, pop := true) -> void:
	if n == level:
		return
	level = n
	digit.text = str(n)
	meter.lit = n
	meter.queue_redraw()
	var colour := UiKit.ALERT if n >= Num.i(_cfg["alert_from"]) else UiKit.ACCENT
	_style.edge = colour
	digit.add_theme_color_override("font_color", colour)
	meter.colour = colour
	queue_redraw()
	if not pop:
		return
	if _pop != null:
		_pop.kill()
	scale = Vector2.ONE * Num.f(_cfg["pop_scale"])
	_pop = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pop.tween_property(self, "scale", Vector2.ONE, Num.f(_cfg["pop_s"]))


## A signal meter: one bar per level, each taller than the last; the first `lit` are filled, the
## rest only outlined.
class Bars:
	extends Control

	var lit := 1
	var colour := UiKit.ACCENT
	var _heights: Array
	var _width := 0.0
	var _gap := 0.0

	func _init(cfg: Dictionary) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_heights = cfg["bar_heights"]
		_width = Num.f(cfg["bar_width"])
		_gap = Num.f(cfg["bar_gap"])
		var tallest := 0.0
		for h: Variant in _heights:
			tallest = maxf(tallest, Num.f(h))
		var n := _heights.size()
		custom_minimum_size = Vector2(n * _width + (n - 1) * _gap, tallest)

	func _draw() -> void:
		var outline := UiKit.outline_color()
		for i: int in _heights.size():
			var h := Num.f(_heights[i])
			var bar := Rect2(i * (_width + _gap), size.y - h, _width, h)
			draw_rect(bar.grow(1.0), outline)
			draw_rect(bar, colour if i < lit else UiKit.BG)
			if i >= lit:
				draw_rect(bar, UiKit.LOCKED, false, 1.0)
