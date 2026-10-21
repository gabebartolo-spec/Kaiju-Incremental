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
## The news crawl's strip: alert red dark enough that white body text reads at 5:1 (ALERT gives
## 3.6:1, fine for the big clock digits, not for 24 px text).
const CRAWL_RED := Color("d42a1f")
const GOOD := Color("7dff6a")
const WARN := Color("ffd84a")
const BAD := Color("ff3b30")
const LOCKED := Color("7c7c84")
## Text on a fill this bright or brighter is dark (BG), else light.
const BRIGHT_FILL := 0.45
## The hazard band along a button's left edge and a panel's top (px at 1080p).
const BUTTON_BAND := 22.0
const PANEL_BAND := 14.0
## A card's content sits this far inside its corner brackets.
const CARD_PAD := 12.0
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
static var _grabbers: Dictionary = {}


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
	text_style(l, size)
	_apply_font(l, size)
	return l


## The one outlined text style (R 15.4): a near-black outline about a fifth of the size and a
## soft drop shadow (tuning "ui" text), so any of the kit's colours reads at 4.5:1 or more over
## the brightest fire behind it: the outline, not the scene, is what the letters sit on.
static func text_style(control: Control, size: int) -> void:
	var cfg: Dictionary = ui()["text"]
	control.add_theme_color_override("font_outline_color", outline_color())
	control.add_theme_constant_override("outline_size", outline_px(size))
	control.add_theme_color_override(
		"font_shadow_color", Color(0, 0, 0, Num.f(cfg["shadow_alpha"]))
	)
	var shadow := Num.i(cfg["shadow_px"])
	control.add_theme_constant_override("shadow_offset_x", shadow)
	control.add_theme_constant_override("shadow_offset_y", shadow)
	control.add_theme_constant_override("shadow_outline_size", outline_px(size))


## The text outline's width at `size` (px at 1080p).
static func outline_px(size: int) -> int:
	var cfg: Dictionary = ui()["text"]
	return maxi(Num.i(cfg["outline_min"]), roundi(size * Num.f(cfg["outline_share"])))


static func outline_color() -> Color:
	return Color(BG, Num.f(ui()["text"]["outline_alpha"]))


## tuning "ui": margins, the HUD's sizes and timings, the hurt vignette.
static func ui() -> Dictionary:
	return Content.section("ui")


## The TV title-safe margin (px at 1080p, x then y): nothing the player reads sits outside it.
static func safe_margin() -> Vector2:
	var m: Array = ui()["safe_margin"]
	return Vector2(Num.f(m[0]), Num.f(m[1]))


## Insets `container` to the title-safe area.
static func safe_area(container: MarginContainer) -> void:
	var m := safe_margin()
	container.add_theme_constant_override("margin_left", roundi(m.x))
	container.add_theme_constant_override("margin_right", roundi(m.x))
	container.add_theme_constant_override("margin_top", roundi(m.y))
	container.add_theme_constant_override("margin_bottom", roundi(m.y))


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


## WCAG contrast ratio of two colours (1..21); body text wants 4.5 or more.
static func contrast(a: Color, b: Color) -> float:
	var la := _relative_luminance(a)
	var lb := _relative_luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _relative_luminance(c: Color) -> float:
	var l := c.srgb_to_linear()
	return 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b


## Dark text on bright fills, light text on dark ones.
static func ink(fill: Color) -> Color:
	return BG if fill.get_luminance() >= BRIGHT_FILL else TEXT


## A panel with hazard tape across its top and a yellow edge.
static func panel(color: Color = PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_box(color))
	return p


## How far a card's content sits inside its edge on the sides and bottom (px).
static func panel_inset() -> float:
	return HazardBox.CORNER_GAP + HazardBox.CORNER_WIDTH + 3.0 + CARD_PAD


## A card's box: hazard tape across the top, a yellow edge, brackets in the lower corners.
static func panel_box(color: Color = PANEL) -> HazardBox:
	var s := hazard(color, ACCENT, 3.0, HazardBox.Band.TOP)
	s.corners = true
	var clear := panel_inset()
	s.content_margin_left = clear
	s.content_margin_right = clear
	s.content_margin_bottom = clear
	return s


## A card's alert header: a red broadcast strip with a warning tag on its left and the heading
## in white Kaiju Claw (white on CRAWL_RED reads at 5:1).
static func header(text: String, size: int = SIZE_TITLE) -> PanelContainer:
	var strip := PanelContainer.new()
	var s := hazard(CRAWL_RED, CRAWL_RED, 0.0)
	s.set_content_margin_all(0)
	s.content_margin_right = 24
	strip.add_theme_stylebox_override("panel", s)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	strip.add_child(row)
	var tag := UiMarks.AlertTag.new()
	row.add_child(tag)
	var l := label(text, size, Color.WHITE)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	tag.custom_minimum_size = Vector2.ONE * (l.get_combined_minimum_size().y + 8.0)
	return strip


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
	focus.chevron = true
	hover.chevron = true
	hover.ring_color = ink(lit)
	# Every state keeps room on the right for the focus pointer, so focus never shifts the text.
	for state: HazardBox in [normal, hover, focus, pressed, off]:
		state.content_margin_right = HazardBox.CHEVRON_INSET + HazardBox.CHEVRON_WIDTH + 10.0
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
	b.pressed.connect(func() -> void: Sfx.ui("ui_click"))
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
	var ticks := UiMarks.Ticks.new()
	full_rect(ticks)
	ticks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(ticks)
	return p


## A slider in the broadcast look: a white-edged black track filled hazard yellow, and a square
## yellow grabber that turns white-ringed when the slider has focus.
static func slider_look(s: HSlider) -> void:
	var track := box(Color(0, 0, 0, 0.75), TEXT, 2)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	s.add_theme_stylebox_override("slider", track)
	var fill := box(ACCENT, ACCENT, 0)
	fill.content_margin_top = 6
	fill.content_margin_bottom = 6
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	s.add_theme_icon_override("grabber", _grabber(BG))
	s.add_theme_icon_override("grabber_highlight", _grabber(Color.WHITE))


## A square grabber: hazard yellow with an `ring` coloured edge (cached per colour).
static func _grabber(ring: Color) -> Texture2D:
	var key := ring.to_html()
	if not _grabbers.has(key):
		var side := 28
		var edge := 4
		var img := Image.create(side, side, false, Image.FORMAT_RGBA8)
		img.fill(ring)
		img.fill_rect(Rect2i(edge, edge, side - 2 * edge, side - 2 * edge), ACCENT)
		_grabbers[key] = ImageTexture.create_from_image(img)
	var tex: Texture2D = _grabbers[key]
	return tex


## A full-width strip of hazard tape, `height` tall (screen edges, dividers).
static func tape(height: float = PANEL_BAND) -> Control:
	var t := UiMarks.Tape.new()
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
	var lines := UiMarks.Scanlines.new()
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
