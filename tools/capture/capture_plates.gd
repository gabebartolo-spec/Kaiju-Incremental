extends SceneTree
## Captures the title and the settings screen twice for the plates board (#97): A as the game is,
## B with the prototype "worn industrial plates" (PlateBox, plate_text.gdshader) put over every
## button and every text. Nothing in scenes/ changes. Local GPU only:
##   godot --path . --windowed --resolution 3840x2160 --script \
##     tools/capture/capture_plates.gd -- --out=<dir>
## Writes title_A/B.png and settings_A/B.png; tools/ui/plates_board.py lays them out.

const SETTLE := 150
const OUTLINE_SCALE := 1.6
const SHADOW_OFFSET := Vector2i(4, 5)
const MIN_OUTLINE := 8

var _out := "user://plates"
var _shader: Shader


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	_shader = load("res://tools/capture/plate_text.gdshader") as Shader
	_run.call_deferred()


func _run() -> void:
	var title := TitleScreen.new()
	title.setup("Reptilian, 3 rampages")
	root.add_child(title)
	await _shot("title_A", SETTLE)
	_restyle(title)
	await _shot("title_B", 4)
	title.queue_free()
	var settings := SettingsMenu.new()
	root.add_child(settings)
	await _shot("settings_A", 8)
	_restyle(settings)
	await _shot("settings_B", 4)
	quit()


func _shot(label: String, frames: int) -> void:
	for _i: int in frames:
		await process_frame
	root.get_texture().get_image().save_png(_out.path_join(label + ".png"))


func _restyle(node: Node) -> void:
	for found: Node in node.find_children("*", "Button", true, false):
		_plate(found as Button)
	for found: Node in node.find_children("*", "Control", true, false):
		if found is Label or found is Button:
			_text(found as Control)


func _plate(b: Button) -> void:
	for state: String in ["normal", "hover", "focus", "pressed", "disabled"]:
		var old := b.get_theme_stylebox(state) as HazardBox
		if old == null:
			continue
		var plate := PlateBox.new()
		plate.fill = old.fill
		plate.edge = Color("0b0b0d")
		plate.band_size = old.band_size
		plate.tape_on = old.tape_on
		plate.press = 1.0 if state == "pressed" else 0.0
		for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			plate.set_content_margin(side, old.get_content_margin(side))
		b.add_theme_stylebox_override(state, plate)


func _text(c: Control) -> void:
	var size := c.get_theme_font_size("font_size")
	var outline := maxi(MIN_OUTLINE, roundi(size * 0.2 * OUTLINE_SCALE))
	c.add_theme_constant_override("outline_size", outline)
	c.add_theme_color_override("font_outline_color", Color("050507"))
	c.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	c.add_theme_constant_override("shadow_offset_x", SHADOW_OFFSET.x)
	c.add_theme_constant_override("shadow_offset_y", SHADOW_OFFSET.y)
	c.add_theme_constant_override("shadow_outline_size", outline)
	if c is Button:
		# Light letters on every plate, yellow ones too: the thick outline carries the contrast, so
		# the one outline colour works in every state (a dark ink would melt into its own outline).
		for state: String in [
			"font_color",
			"font_hover_color",
			"font_focus_color",
			"font_pressed_color",
			"font_hover_pressed_color"
		]:
			c.add_theme_color_override(state, UiKit.TEXT)
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	c.material = mat
