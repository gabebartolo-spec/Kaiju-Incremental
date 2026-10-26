class_name TitleScreen
extends Control
## The main menu (the director's own layout, 2026-10-23): the logo and, under it, one row with a
## wide Continue Game button (the save's kaiju and rampages) and a smaller New Kaiju? (which asks
## first if it would replace the save); with no save one wide New Kaiju takes Continue's place. A
## settings gear sits top-left and "Run for your life!?" (it quits) bottom-right above the news
## ticker, so the burning city stays open. Focus order: Continue, New Kaiju, gear, exit.
## Continue and New Kaiju? open the save slots in the same column (SlotList, director 2026-10-26:
## "Three slots (Recommended)"); with every slot empty New Kaiju starts in slot 1 at once.
## Reports the choice by signal; main.gd owns the saves.

signal continue_pressed(slot: int)
signal new_game_pressed(slot: int)
signal delete_pressed(slot: int)

## The button row: Continue's width and New Kaiju?'s (px at 1080p), the gap between them and the
## height of a button.
const ROW_GAP := 12
## A plate's face is 104 px (9.6% of the screen's height, 208 px at 4K): the rect less its shadow.
const BUTTON_HEIGHT := 110.0
## The row starts this far in from the logo's box: the plates' outline (1 px out from the edge)
## lands on the logo's yellow letters (the ink starts at x=127 on a 4K capture, 128 for the plates),
## so they share one left edge. The gear and the exit button stand the same distance from their
## screen edges.
const ROW_INSET := 6.0
## Continue takes three shares of the row and New Kaiju? one.
const CONTINUE_SHARE := 3.0
## The settings gear's side and how far it stands in from the top-left corner (director
## 2026-10-25: "shift the settings button further into the corner"), and how far the exit button
## stands above the ticker.
const GEAR_SIZE := 76.0
const GEAR_CORNER := 32.0
const EXIT_LIFT := 20.0
## With no save, New Kaiju stands alone at this share of the row's width and this height
## (director 2026-10-25: "make the 'new kaiju' button significantly smaller").
const ALONE_SHARE := 0.42
const ALONE_HEIGHT := 80.0
## The logo's size: its width is the button row's and ends clear of the skyline.
const LOGO_SIZE := 86
## The gap between the logo and the row.
const LOGO_GAP := 10
## The exit button's wording.
const EXIT_TEXT := "RUN FOR YOUR LIFE!?"
## The left column's width (px); it stands the TV title-safe margin in from the screen's edge.
const COLUMN_WIDTH := 800.0
## The logo stands this share of the screen's height down (the buttons follow it).
const COLUMN_TOP := 0.21
## Texels along a side of the sky's glow textures (a coarse one shows as blocks when stretched).
const GLOW_TEXELS := 512

## summary: "" for no save to continue, else the latest one (e.g. "Reptilian, 3 rampages").
var summary := ""
## The save slots (SlotList.slots) and the one played last (its plate takes focus first).
var slots: Array[Dictionary] = []
var latest_slot := 0
## The live dusk city behind the menu (tests that build a title without a renderer turn it off).
var live_city := true
var _col: VBoxContainer
var _buttons: VBoxContainer
var _first: Button
var _crawl: NewsTicker
var _corners: Control
var _gear: Button
var _exit: Button


func setup(p_summary: String, p_slots: Array[Dictionary] = [], p_latest := 0) -> void:
	summary = p_summary
	slots = p_slots
	latest_slot = p_latest


## After a slot is deleted: the new slots and summary, the slot list shown again.
func refresh(
	p_summary: String, p_slots: Array[Dictionary], p_latest: int, mode: SlotList.Mode
) -> void:
	setup(p_summary, p_slots, p_latest)
	show_slots(mode)


func _ready() -> void:
	UiKit.full_rect(self)
	add_child(UiKit.backdrop())
	if live_city and DisplayServer.get_name() != "headless":
		_add_live_city()
	_add_broadcast_frame()
	_col = VBoxContainer.new()
	UiKit.full_rect(_col)
	# One column down the left (director 2026-10-22): the logo above the buttons, left-aligned with
	# them, a safe margin in from the edge and centred in the space above the news ticker; the
	# whole right side is the burning skyline.
	var width := get_viewport_rect().size.x
	_col.offset_left = UiKit.safe_margin().x  # inside the TV title-safe area (192 px at 4K)
	_col.offset_right = -(width - UiKit.safe_margin().x - COLUMN_WIDTH)
	_col.offset_bottom = -NewsTicker.HEIGHT
	_col.alignment = BoxContainer.ALIGNMENT_BEGIN
	_col.offset_top = get_viewport_rect().size.y * COLUMN_TOP
	_col.add_theme_constant_override("separation", LOGO_GAP)
	add_child(_col)
	_add_corner_buttons()
	var title := UiKit.label("KAIJU EVOLUTION", LOGO_SIZE, UiKit.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_col.add_child(title)
	_buttons = VBoxContainer.new()
	# The row ends where the logo does and starts at the logo's yellow, ROW_INSET in.
	var inset := MarginContainer.new()
	inset.add_theme_constant_override("margin_left", int(ROW_INSET))
	inset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_col.add_child(inset)
	_buttons.custom_minimum_size = Vector2(title.get_combined_minimum_size().x - ROW_INSET, 0)
	_buttons.add_theme_constant_override("separation", 16)
	inset.add_child(_buttons)
	_show_main()


## The burning city at night behind the menu, a dark pool of shade behind the logo and buttons so
## they stay readable, and the faint sound of the city under attack.
func _add_live_city() -> void:
	_add_sky()
	var backdrop := TitleBackdrop.new()
	add_child(backdrop)
	var cfg: Dictionary = Content.section("title")["shade"]
	var shade := Gradient.new()
	var colour := Color(str(cfg["color"]))
	shade.set_color(0, Color(colour, Num.f(cfg["centre_alpha"])))
	shade.set_color(1, Color(colour, Num.f(cfg["edge_alpha"])))
	var tex := GradientTexture2D.new()
	tex.gradient = shade
	tex.fill = GradientTexture2D.FILL_RADIAL
	var centre_x := Num.f(cfg["centre_x"])
	tex.fill_from = Vector2(centre_x, 0.5)
	tex.fill_to = Vector2(centre_x + Num.f(cfg["radius"]), 0.5)
	var rect := TextureRect.new()
	rect.texture = tex
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(rect)
	add_child(rect)
	var ambience := TitleAmbience.new()
	ambience.shot.connect(backdrop.shot)
	ambience.boomed.connect(backdrop.boom)
	ambience.stomped.connect(backdrop.stomp)
	backdrop.ready_to_show.connect(ambience.flashes_begin)
	add_child(ambience)


## The night sky and the fires' glow, there from the first frame: the city fades in over them.
func _add_sky() -> void:
	var cfg: Dictionary = Content.section("title")["sky"]
	var fade := Gradient.new()
	fade.set_color(0, Color(str(cfg["top"])))
	fade.set_color(1, Color(str(cfg["bottom"])))
	var sky := GradientTexture2D.new()
	sky.gradient = fade
	sky.fill_from = Vector2(0.5, 0.0)
	sky.fill_to = Vector2(0.5, 1.0)
	var rect := TextureRect.new()
	rect.texture = sky
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(rect)
	add_child(rect)
	var glow_colour := Color(str(cfg["glow_color"]), Num.f(cfg["glow_alpha"]))
	var glows: Array = cfg["glows"]
	for g: Array in glows:
		var spot := Gradient.new()
		spot.set_color(0, glow_colour)
		spot.set_color(1, Color(glow_colour, 0.0))
		var tex := GradientTexture2D.new()
		tex.gradient = spot
		tex.width = GLOW_TEXELS
		tex.height = GLOW_TEXELS
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		var blob := TextureRect.new()
		blob.texture = tex
		blob.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		blob.stretch_mode = TextureRect.STRETCH_SCALE
		blob.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blob.anchor_left = Num.f(g[0]) - Num.f(g[2])
		blob.anchor_right = Num.f(g[0]) + Num.f(g[2])
		blob.anchor_top = Num.f(g[1]) - Num.f(g[2]) * 1.78
		blob.anchor_bottom = Num.f(g[1]) + Num.f(g[2]) * 1.78
		add_child(blob)


## The news crawl along the bottom: the city has seen you. No tape along the top (director
## 2026-10-25: "remove the yellow bar at the top").
func _add_broadcast_frame() -> void:
	var news := Content.section("news")
	var title_lines: Array = news.get("title", [])
	var lines := PackedStringArray(title_lines)
	if summary != "":
		var who := summary.get_slice(",", 0).to_upper()
		lines.insert(0, str(news.get("at_large", "")).replace("{species}", who))
	_crawl = NewsTicker.new(lines)
	_crawl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_crawl.offset_top = -NewsTicker.HEIGHT
	add_child(_crawl)


func _show_main() -> void:
	_clear()
	var new_button: Button
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ROW_GAP)
	_buttons.add_child(row)
	if summary != "":
		var label := "CONTINUE GAME\n%s" % summary.to_upper()
		var cont := _add(label, UiKit.ACCENT, show_slots.bind(SlotList.Mode.CONTINUE), row)
		cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cont.size_flags_stretch_ratio = CONTINUE_SHARE
		new_button = _add("NEW KAIJU?", UiKit.PANEL_EDGE, _on_new, row)
		new_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_wire_focus(cont, new_button)
	else:
		new_button = _add("NEW KAIJU", UiKit.ACCENT, _on_new, row)
		new_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		new_button.custom_minimum_size = Vector2(
			_buttons.custom_minimum_size.x * ALONE_SHARE, ALONE_HEIGHT
		)
		_wire_focus(null, new_button)


## Keyboard and pad order: Continue, New Kaiju, the gear, the exit button; the arrows go where the
## buttons are (the gear above, the exit below).
func _wire_focus(cont: Button, new_button: Button) -> void:
	var order: Array[Button] = [new_button, _gear, _exit]
	var main_row: Array[Button] = [new_button]
	if cont != null:
		order.push_front(cont)
		main_row.push_front(cont)
	for i: int in order.size():
		var here := order[i]
		here.focus_next = here.get_path_to(order[(i + 1) % order.size()])
		here.focus_previous = here.get_path_to(order[(i + order.size() - 1) % order.size()])
	for b: Button in main_row:
		b.focus_neighbor_top = b.get_path_to(_gear)
		b.focus_neighbor_bottom = b.get_path_to(_exit)
	if cont != null:
		cont.focus_neighbor_right = cont.get_path_to(new_button)
		new_button.focus_neighbor_left = new_button.get_path_to(cont)
	_gear.focus_neighbor_bottom = _gear.get_path_to(main_row[0])
	_gear.focus_neighbor_right = _gear.get_path_to(new_button)
	_exit.focus_neighbor_top = _exit.get_path_to(new_button)
	_exit.focus_neighbor_left = _exit.get_path_to(main_row[0])


## The settings gear top-left and the exit button bottom-right, above the ticker.
func _add_corner_buttons() -> void:
	_corners = Control.new()
	UiKit.full_rect(_corners)
	_corners.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_corners)
	_gear = UiKit.button("", UiKit.SIZE_BODY, UiKit.PANEL_EDGE, false)
	_gear.name = "Gear"
	_gear.tooltip_text = "SETTINGS"
	_gear.custom_minimum_size = Vector2(GEAR_SIZE, GEAR_SIZE)
	_gear.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_gear.offset_left = GEAR_CORNER
	_gear.offset_top = GEAR_CORNER
	_gear.offset_right = GEAR_CORNER + GEAR_SIZE
	_gear.offset_bottom = GEAR_CORNER + GEAR_SIZE
	var icon := GearIcon.new()
	icon.color = UiKit.TEXT
	UiKit.full_rect(icon)
	icon.offset_left = 8.0
	icon.offset_top = 6.0
	icon.offset_right = -12.0
	icon.offset_bottom = -14.0
	_gear.add_child(icon)
	_gear.pressed.connect(_open_settings)
	_corners.add_child(_gear)
	_exit = UiKit.button(EXIT_TEXT, UiKit.SIZE_BODY, UiKit.PANEL_EDGE)
	_exit.name = "Exit"
	_exit.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_exit.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_exit.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var side := _col.offset_left + ROW_INSET
	_exit.offset_right = -(side - HazardBox.PLATE_SHADOW.x)  # the plate's face, not its shadow
	_exit.offset_bottom = -(NewsTicker.HEIGHT + EXIT_LIFT)
	_exit.pressed.connect(func() -> void: QuitGame.now(get_tree()))
	_exit.visible = not OS.has_feature("web")
	_corners.add_child(_exit)


## New Kaiju: the slots to pick from, or slot 1 at once when every slot is empty.
func _on_new() -> void:
	if slots.all(func(info: Dictionary) -> bool: return info.get("taken", false) != true):
		new_game_pressed.emit(1)
		return
	show_slots(SlotList.Mode.NEW)


## The save slots in the button column; BACK (or Esc) returns to the main row.
func show_slots(mode: SlotList.Mode) -> void:
	_clear()
	var list := SlotList.new()
	list.setup(mode, slots, latest_slot)
	list.picked.connect(
		func(n: int) -> void:
			if mode == SlotList.Mode.CONTINUE:
				continue_pressed.emit(n)
			else:
				new_game_pressed.emit(n)
	)
	list.delete_confirmed.connect(func(n: int) -> void: delete_pressed.emit(n))
	list.back_pressed.connect(_show_main)
	_buttons.add_child(list)


## The slot list on show (tests and captures read it), or null.
func slot_list() -> SlotList:
	for child: Node in _buttons.get_children():
		if child is SlotList:
			return child
	return null


func _open_settings() -> void:
	var settings := SettingsMenu.new()
	_col.visible = false  # nothing behind the settings can take focus
	_corners.visible = false
	_crawl.visible = false  # nor show dimmed under its panel
	settings.closed.connect(
		func() -> void:
			_col.visible = true
			_corners.visible = true
			_crawl.visible = true
			_show_main()
	)
	add_child(settings)


func _clear() -> void:
	for child: Node in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()
	_first = null


## One button in `into` (the row or the column).
func _add(text: String, fill: Color, action: Callable, into: Container) -> Button:
	var b := UiKit.button(text, UiKit.SIZE_BODY, fill)
	HazardBox.drop_pointer(b)
	b.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	b.pressed.connect(action)
	into.add_child(b)
	if _first == null:
		_first = b
		b.grab_focus.call_deferred()
	return b
