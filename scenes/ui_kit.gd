class_name UiKit
extends RefCounted
## The one UI kit: palette, type sizes and widget builders. Every screen builds its controls
## here so text stays readable on a TV (24 px base at 1080p) and the look stays one look.

const BG := Color("12161c")
const PANEL := Color("1d242d")
const PANEL_EDGE := Color("39444f")
const TEXT := Color("eef1f4")
const MUTED := Color("9aa6b2")
const ACCENT := Color("ff7a2f")
const GOOD := Color("7bd96a")
const WARN := Color("ffd24a")
const BAD := Color("ff4d4d")
const LOCKED := Color("4a535c")

const SIZE_BODY := 24
const SIZE_SMALL := 20
const SIZE_HEAD := 36
const SIZE_TITLE := 72

## The game's own display face (tools/fonts/build_fonts.py) for headings, titles and big buttons.
## The director's pick is this one line: kaiju_claw (B), kaiju_rubble (A) or kaiju_fault (C).
const DISPLAY_FONT_PATH := "res://assets/fonts/kaiju_claw.ttf"
## Below this size text keeps the engine's clean default font: the claw gashes turn to noise.
const DISPLAY_MIN_SIZE := SIZE_HEAD

static var _display_font: Font
static var _arrow: ImageTexture


## The display font for headings at or above DISPLAY_MIN_SIZE, else null (theme default).
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
	color: Color, edge: Color = PANEL_EDGE, border: int = 2, radius: int = 10
) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = edge
	s.set_border_width_all(border)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(14)
	return s


static func panel(color: Color = PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(color))
	return p


static func button(text: String, size: int = SIZE_BODY, fill: Color = ACCENT) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	_apply_font(b, size)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", box(fill.darkened(0.25), fill))
	b.add_theme_stylebox_override("hover", box(fill.darkened(0.05), Color.WHITE))
	b.add_theme_stylebox_override("focus", box(fill.darkened(0.05), Color.WHITE, 4))
	b.add_theme_stylebox_override("pressed", box(fill.darkened(0.4), Color.WHITE))
	b.add_theme_stylebox_override("disabled", box(LOCKED.darkened(0.3), LOCKED))
	return b


static func bar(fill: Color, height: int = 26) -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.custom_minimum_size = Vector2(0, height)
	p.add_theme_stylebox_override("background", box(Color(0, 0, 0, 0.55), PANEL_EDGE, 2, 6))
	p.add_theme_stylebox_override("fill", box(fill, fill.lightened(0.3), 0, 6))
	return p


static func full_rect(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


static func backdrop() -> ColorRect:
	var r := ColorRect.new()
	r.color = BG
	full_rect(r)
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
