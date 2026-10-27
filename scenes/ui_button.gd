class_name UiButton
extends RefCounted
## The kit's button (UiKit.button, moved here to keep ui_kit.gd under the size cap): hazard tape
## down both edges, one plate per state, worn industrial plates (director #97), the label centred
## on the plate's face, and one highlight shared by the mouse and the keyboard.


## A button with hazard tape down both edges. Focus (and hover) lights a dark button up in
## hazard yellow; focus adds a dark ring inside its edge, so the pad always shows where you are.
static func build(text: String, size: int, fill: Color, taped: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	var font := UiKit.font_for(size)
	if font != null:
		b.add_theme_font_override("font", font)
	var lit := UiKit.ACCENT if fill.get_luminance() < 0.3 else fill
	var plates := _plates(fill, lit, taped)
	b.material = HazardBox.text_material()
	for state: String in plates:
		var plate: StyleBox = plates[state]
		b.add_theme_stylebox_override(state, plate)
	_colours(b, fill, lit)
	b.pressed.connect(func() -> void: Sfx.ui("ui_click"))
	# The mouse and the keyboard share one highlight: hovering moves the focus, so two buttons are
	# never lit at once (director 2026-10-22: CONTINUE focused and SETTINGS hovered, both yellow).
	b.mouse_entered.connect(
		func() -> void:
			if not b.disabled:
				b.grab_focus()
	)
	return b


## The five plates of a button by theme name (normal, hover, focus, pressed, disabled).
static func _plates(fill: Color, lit: Color, taped: bool) -> Dictionary:
	var taped_band := HazardBox.Band.SIDES if taped else HazardBox.Band.NONE
	var normal := UiKit.hazard(fill, fill.lightened(0.15), 2.0, taped_band)
	var hover := UiKit.hazard(lit, lit, 2.0, taped_band)
	var focus := UiKit.hazard(lit, lit, 2.0, taped_band)
	focus.ring = true
	focus.ring_color = UiKit.ink(lit)
	var pressed := UiKit.hazard(lit.darkened(0.25), lit, 2.0, taped_band)
	pressed.ring = true
	pressed.ring_color = UiKit.ink(lit.darkened(0.25))
	var off := UiKit.hazard(UiKit.PANEL, UiKit.LOCKED, 2.0, taped_band)
	off.dashed = true
	off.tape_on = UiKit.LOCKED
	focus.chevron = taped
	hover.chevron = taped
	hover.ring_color = UiKit.ink(lit)
	# Worn industrial plates (director #97): every button of every menu shares the look.
	for plate: HazardBox in [normal, hover, focus, pressed, off]:
		plate.plated = true
	pressed.press = 1.0
	# Every state keeps room inside the right tape for the focus pointer, so focus never shifts the
	# text; the left matches it, so the label sits in the middle.
	var room := UiKit.BUTTON_BAND + HazardBox.CHEVRON_GAP + HazardBox.CHEVRON_WIDTH + 6.0
	if not taped:
		room = 10.0
	# The plate's face stands PLATE_SHADOW short of its rect on the right and bottom: that much more
	# room there centres the label on the face (director 2026-10-25: "centre the text").
	for state: HazardBox in [normal, hover, focus, pressed, off]:
		state.content_margin_left = room
		state.content_margin_right = room + HazardBox.PLATE_SHADOW.x
		state.content_margin_bottom = state.content_margin_top + HazardBox.PLATE_SHADOW.y
	return {"normal": normal, "hover": hover, "focus": focus, "pressed": pressed, "disabled": off}


## The label colour of each state.
static func _colours(b: Button, fill: Color, lit: Color) -> void:
	b.add_theme_color_override("font_color", UiKit.ink(fill))
	b.add_theme_color_override("font_hover_color", UiKit.ink(lit))
	b.add_theme_color_override("font_focus_color", UiKit.ink(lit))
	b.add_theme_color_override("font_hover_pressed_color", UiKit.ink(lit))
	b.add_theme_color_override("font_pressed_color", UiKit.ink(lit.darkened(0.25)))
	b.add_theme_color_override("font_disabled_color", UiKit.LOCKED.lightened(0.3))
