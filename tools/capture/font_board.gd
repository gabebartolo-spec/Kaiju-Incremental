extends SceneTree
## Renders the display-font comparison board: each candidate as the title, a HUD line, the
## EVOLVE button and small body text, on the game's own UI background. Needs a window (no
## --headless); run with an untracked override.cfg that sets no_focus and an off-screen position.
##
##   APPDATA=<scratch> godot --path . --resolution 1920x1080 --windowed \
##     --script tools/capture/font_board.gd -- --out=<dir>

const FONTS := [
	["A", "RUBBLE", "res://assets/fonts/kaiju_rubble.ttf"],
	["B", "CLAW", "res://assets/fonts/kaiju_claw.ttf"],
	["C", "FAULT", "res://assets/fonts/kaiju_fault.ttf"],
]

var _out := "user://font_board"


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var screen := Control.new()
	screen.size = Vector2(1920, 1080)
	root.add_child(screen)
	screen.add_child(UiKit.backdrop())
	var col := VBoxContainer.new()
	col.position = Vector2(48, 24)
	col.size = Vector2(1824, 1032)
	col.add_theme_constant_override("separation", 10)
	screen.add_child(col)
	for entry: Array in FONTS:
		var path: String = entry[2]
		var font: Font = load(path)
		var picked := path == UiKit.DISPLAY_FONT_PATH
		var tag := UiKit.label(
			"%s  %s%s" % [entry[0], entry[1], "   (in game now)" if picked else ""],
			UiKit.SIZE_SMALL,
			UiKit.ACCENT if picked else UiKit.MUTED
		)
		col.add_child(tag)
		var title := UiKit.label("KAIJU EVOLUTION", 96, UiKit.ACCENT)
		title.add_theme_font_override("font", font)
		col.add_child(title)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 48)
		col.add_child(row)
		var hud := UiKit.label("RUBBLE 1,250  CITY DESTROYED 34%", UiKit.SIZE_HEAD, UiKit.WARN)
		hud.add_theme_font_override("font", font)
		row.add_child(hud)
		var go := UiKit.button("EVOLVE  >", UiKit.SIZE_HEAD)
		go.add_theme_font_override("font", font)
		row.add_child(go)
		var small := UiKit.label(
			"Smash towers to earn rubble. Spend it to evolve: claws, hide, breath.",
			UiKit.SIZE_BODY,
			UiKit.TEXT
		)
		small.add_theme_font_override("font", font)
		col.add_child(small)
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 6)
		col.add_child(spacer)
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := _out.path_join("font_board.png")
	root.get_texture().get_image().save_png(path)
	print("font board -> ", path)
	quit()
