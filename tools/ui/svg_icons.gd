extends SceneTree
## Rasterises the HUD skill icons from their SVG sources (assets/ui/icons/src/*.svg, built on
## game-icons.net silhouettes by Lorc, CC BY 3.0, see docs/CREDITS.md)
## to square PNGs on a transparent background with Godot's own SVG reader. Headless; no window:
##
##   godot --headless --path . --script tools/ui/svg_icons.gd -- [--src=res://assets/ui/icons/src] \
##     [--out=res://assets/ui/icons] [--size=256]
##
## Each <name>.svg becomes <out>/<name>.png at --size px. Exits 1 if a file cannot be read.

var _src := "res://assets/ui/icons/src"
var _out := "res://assets/ui/icons"
var _size := 256


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--src="):
			_src = arg.substr(6)
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--size="):
			_size = int(arg.substr(7))
	quit(_run())


func _run() -> int:
	DirAccess.make_dir_recursive_absolute(_out)
	var made := 0
	for file: String in DirAccess.get_files_at(_src):
		if file.get_extension() != "svg":
			continue
		var text := FileAccess.get_file_as_string(_src.path_join(file))
		var probe := Image.new()
		if text.is_empty() or probe.load_svg_from_string(text, 1.0) != OK:
			push_error("svg_icons: cannot read %s" % file)
			return 1
		var image := Image.new()
		image.load_svg_from_string(text, float(_size) / probe.get_width())
		var path := _out.path_join(file.get_basename() + ".png")
		image.save_png(path)
		print("svg_icons: %s %dx%d" % [path, image.get_width(), image.get_height()])
		made += 1
	return 0 if made > 0 else 1
