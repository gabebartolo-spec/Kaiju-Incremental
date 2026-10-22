class_name TitleScreen
extends Control
## The main menu: Continue (when a save exists), New Kaiju (asks first if it would replace a
## save), Settings and Quit. Reports the choice by signal; main.gd owns the save.

signal continue_pressed
signal new_game_pressed

## summary: "" for no save, else what Continue resumes (e.g. "Reptilian, 3 rampages").
var summary := ""
## The live dusk city behind the menu (tests that build a title without a renderer turn it off).
var live_city := true
var _col: VBoxContainer
var _buttons: VBoxContainer
var _first: Button
var _crawl: NewsTicker


func setup(p_summary: String) -> void:
	summary = p_summary


func _ready() -> void:
	UiKit.full_rect(self)
	add_child(UiKit.backdrop())
	if live_city and DisplayServer.get_name() != "headless":
		_add_live_city()
	_add_broadcast_frame()
	_col = VBoxContainer.new()
	UiKit.full_rect(_col)
	_col.alignment = BoxContainer.ALIGNMENT_CENTER
	_col.add_theme_constant_override("separation", 24)
	add_child(_col)
	var title := UiKit.label("KAIJU EVOLUTION", 104, UiKit.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(title)
	_buttons = VBoxContainer.new()
	_buttons.custom_minimum_size = Vector2(560, 0)
	_buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_buttons.add_theme_constant_override("separation", 16)
	_col.add_child(_buttons)
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
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5 + Num.f(cfg["radius"]), 0.5)
	var rect := TextureRect.new()
	rect.texture = tex
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(rect)
	add_child(rect)
	var ambience := TitleAmbience.new()
	ambience.stomped.connect(backdrop.stomp)
	ambience.shot.connect(backdrop.shot)
	ambience.boomed.connect(backdrop.boom)
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
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		var blob := TextureRect.new()
		blob.texture = tex
		blob.stretch_mode = TextureRect.STRETCH_SCALE
		blob.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blob.anchor_left = Num.f(g[0]) - Num.f(g[2])
		blob.anchor_right = Num.f(g[0]) + Num.f(g[2])
		blob.anchor_top = Num.f(g[1]) - Num.f(g[2]) * 1.78
		blob.anchor_bottom = Num.f(g[1]) + Num.f(g[2]) * 1.78
		add_child(blob)


## Hazard tape along the top edge and the news crawl along the bottom: the city has seen you.
func _add_broadcast_frame() -> void:
	var top := UiKit.tape(18.0)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 18.0
	add_child(top)
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
	if summary != "":
		_add("CONTINUE", UiKit.ACCENT, func() -> void: continue_pressed.emit())
		_note(summary)
	var fresh_fill := UiKit.PANEL_EDGE if summary != "" else UiKit.ACCENT
	_add("NEW KAIJU", fresh_fill, _on_new)
	_add("SETTINGS", UiKit.PANEL_EDGE, _open_settings)
	if not OS.has_feature("web"):
		_add("QUIT", UiKit.PANEL_EDGE, func() -> void: QuitGame.now(get_tree()))


func _on_new() -> void:
	if summary == "":
		new_game_pressed.emit()
		return
	_clear()
	_note("Start over? Your %s and every evolution are lost." % summary)
	_add("KEEP MY KAIJU", UiKit.ACCENT, _show_main)
	_add("YES, START OVER", UiKit.BAD, func() -> void: new_game_pressed.emit())


func _open_settings() -> void:
	var settings := SettingsMenu.new()
	_col.visible = false  # nothing behind the settings can take focus
	_crawl.visible = false  # nor show dimmed under its panel
	settings.closed.connect(
		func() -> void:
			_col.visible = true
			_crawl.visible = true
			_show_main()
	)
	add_child(settings)


func _clear() -> void:
	for child: Node in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()
	_first = null


func _add(text: String, fill: Color, action: Callable) -> Button:
	var b := UiKit.button(text, UiKit.SIZE_HEAD, fill)
	b.custom_minimum_size = Vector2(0, 80)
	b.pressed.connect(action)
	_buttons.add_child(b)
	if _first == null:
		_first = b
		b.grab_focus.call_deferred()
	return b


func _note(text: String) -> void:
	var l := UiKit.label(text, UiKit.SIZE_BODY, UiKit.MUTED)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_buttons.add_child(l)
