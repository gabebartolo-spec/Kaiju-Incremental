class_name UiKit
extends RefCounted
## The one UI kit: palette, type sizes and widget builders. Every screen builds its controls
## here so text stays readable on a TV (24 px base at 1080p) and the look stays one look.
## The look is the director's pick A, "emergency broadcast": the city's civil-defence alarm
## system is screaming about you. Hazard yellow on near-black, alert red, square edges, tape.

const BG := Color("0b0b0d")
const PANEL := Color("16161a")
const PANEL_EDGE := Color("3a3a40")
const TEXT := Color("f2efe6")
const MUTED := Color("b9b4a6")
## Hazard yellow: titles, the primary button, focus.
const ACCENT := Color("ffcc00")
## Alert red: evolutions, the clock running out, the news crawl.
const ALERT := Color("ff3b30")
const GOOD := Color("7dff6a")
const WARN := Color("ffd84a")
const BAD := Color("ff3b30")
const LOCKED := Color("55555c")
## Text on a fill this bright or brighter is dark (BG), else light.
const BRIGHT_FILL := 0.45
## The hazard band along a button's left edge and a panel's top (px at 1080p).
const BUTTON_BAND := 22.0
const PANEL_BAND := 14.0
## Scanlines over a backdrop: one line every SCANLINE_STEP px, this faint.
const SCANLINE_STEP := 4.0
const SCANLINE_ALPHA := 0.035

const SIZE_BODY := 24
const SIZE_SMALL := 20
const SIZE_HEAD := 36
const SIZE_TITLE := 72

## Our own faces (tools/fonts/build_fonts.py), capitals only (D-058). Body text is Kaiju Block,
## the project's default font (project.godot gui/theme/custom_font), so every label, button and
## tree node uses it with no override. Headings, titles and big buttons use the display face:
## The director's pick is this one line: kaiju_claw (B), kaiju_rubble (A) or kaiju_fault (C).
const DISPLAY_FONT_PATH := "res://assets/fonts/kaiju_claw.ttf"
## Below this size text stays in Kaiju Block: the claw gashes turn to noise.
const DISPLAY_MIN_SIZE := SIZE_HEAD

static var _display_font: Font
static var _arrow: ImageTexture


## The display font for headings at or above DISPLAY_MIN_SIZE, else null (Kaiju Block, the
## project's default font).
static func font_for(size: int) -> Font:
	if size < DISPLAY_MIN_SIZE:
		return null
	if _display_font == null:
		_display_font = load(DISPLAY_FONT_PATH)
	return _display_font


static func _apply_font(control: Control, size: int) -> void:
	var font := font_for(size)
	if font != null:
		control.add_theme_font_override("font", font)


static func label(text: String, size: int = SIZE_BODY, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", maxi(4, Num.i(size / 6.0)))
	_apply_font(l, size)
	return l


static func box(
	color: Color, edge: Color = PANEL_EDGE, border: int = 2, radius: int = 0
) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = edge
	s.set_border_width_all(border)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(14)
	return s


## A broadcast box: square, `edge` `border` px thick, hazard tape on `band`'s side.
static func hazard(
	fill: Color, edge: Color, border: float = 2.0, band: HazardBox.Band = HazardBox.Band.NONE
) -> HazardBox:
	var s := HazardBox.new()
	s.fill = fill
	s.edge = edge
	s.border = border
	s.band = band
	s.band_size = BUTTON_BAND if band == HazardBox.Band.LEFT else PANEL_BAND
	s.set_content_margin_all(14)
	if band == HazardBox.Band.LEFT:
		s.content_margin_left = BUTTON_BAND + 14.0
	elif band == HazardBox.Band.TOP:
		s.content_margin_top = PANEL_BAND + 14.0
	return s


## Dark text on bright fills, light text on dark ones.
static func ink(fill: Color) -> Color:
	return BG if fill.get_luminance() >= BRIGHT_FILL else TEXT


## A panel with hazard tape across its top and a yellow edge.
static func panel(color: Color = PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", hazard(color, ACCENT, 3.0, HazardBox.Band.TOP))
	return p


## A button with hazard tape down its left edge. Focus (and hover) lights a dark button up in
## hazard yellow; focus adds a dark ring inside its edge, so the pad always shows where you are.
static func button(text: String, size: int = SIZE_BODY, fill: Color = ACCENT) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	_apply_font(b, size)
	var lit := ACCENT if fill.get_luminance() < 0.3 else fill
	var left := HazardBox.Band.LEFT
	var normal := hazard(fill, fill.lightened(0.15), 2.0, left)
	var hover := hazard(lit, lit, 2.0, left)
	var focus := hazard(lit, lit, 2.0, left)
	focus.ring = true
	focus.ring_color = ink(lit)
	var pressed := hazard(lit.darkened(0.25), lit, 2.0, left)
	pressed.ring = true
	pressed.ring_color = ink(lit.darkened(0.25))
	var off := hazard(PANEL, LOCKED, 2.0, left)
	off.dashed = true
	off.tape_on = LOCKED
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", focus)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", off)
	b.add_theme_color_override("font_color", ink(fill))
	b.add_theme_color_override("font_hover_color", ink(lit))
	b.add_theme_color_override("font_focus_color", ink(lit))
	b.add_theme_color_override("font_hover_pressed_color", ink(lit))
	b.add_theme_color_override("font_pressed_color", ink(lit.darkened(0.25)))
	b.add_theme_color_override("font_disabled_color", LOCKED.lightened(0.3))
	return b


## A meter: square, white-edged on black. `taped` fills it with hazard tape in `fill`.
static func bar(fill: Color, height: int = 26, taped: bool = false) -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.custom_minimum_size = Vector2(0, height)
	p.add_theme_stylebox_override("background", box(Color(0, 0, 0, 0.75), TEXT, 2))
	var inner := hazard(fill, fill, 0.0)
	if taped:
		inner.band = HazardBox.Band.TOP
		inner.band_size = height
		inner.tape_on = fill
		inner.tape_off = fill.darkened(0.2)
	inner.set_content_margin_all(0)
	p.add_theme_stylebox_override("fill", inner)
	return p


## A full-width strip of hazard tape, `height` tall (screen edges, dividers).
static func tape(height: float = PANEL_BAND) -> Control:
	var t := Tape.new()
	t.custom_minimum_size = Vector2(0, height)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func full_rect(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## The screen behind a menu: near-black with faint broadcast scanlines.
static func backdrop() -> ColorRect:
	var r := ColorRect.new()
	r.color = BG
	full_rect(r)
	var lines := Scanlines.new()
	full_rect(lines)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(lines)
	return r


## Body text that can carry inline images (UiKit.arrow()): wraps, grows to fit, never scrolls.
static func rich(size: int = SIZE_BODY, color: Color = TEXT) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_color_override("default_color", color)
	return r


## A right arrow, drawn here because neither the body font nor Kaiju Claw has U+2192 and the
## web build has no system font to fall back on. White; tint it with add_image's color.
static func arrow() -> Texture2D:
	if _arrow == null:
		var w := 30
		var half := 10  # half the height; the head is a right triangle this deep
		var img := Image.create(w, half * 2, false, Image.FORMAT_RGBA8)
		for y: int in half * 2:
			var off := absi(y - half)
			for x: int in w:
				var shaft := x < w - half and off <= 2
				var head := x >= w - half - 2 and x - (w - half - 2) <= half - off
				if shaft or head:
					img.set_pixel(x, y, Color.WHITE)
		_arrow = ImageTexture.create_from_image(img)
	return _arrow


## Hazard tape filling the control.
class Tape:
	extends Control

	func _draw() -> void:
		HazardBox.tape(get_canvas_item(), Rect2(Vector2.ZERO, size), ACCENT, Color("111114"))


## Faint horizontal lines, like an old broadcast monitor.
class Scanlines:
	extends Control

	func _draw() -> void:
		var y := 0.0
		var line := Color(1, 1, 1, SCANLINE_ALPHA)
		while y < size.y:
			draw_rect(Rect2(0.0, y, size.x, SCANLINE_STEP / 2.0), line)
			y += SCANLINE_STEP
