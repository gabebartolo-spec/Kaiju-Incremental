extends SceneTree
## Pixel diff of two folders of PNG stills (a before/after pair of capture_graphics.gd runs): for
## every PNG in --a, the PNG of the same name in --b must be the same size and the same bytes.
## Prints one DIFF line per image (differing pixels, the largest channel difference) and a total;
## with --mask=<dir>, writes <name>_mask.png (differing pixels white). Exits 1 on any difference.
##   godot --headless --path . --script tools/capture/image_diff.gd -- --a=<dir> --b=<dir> \
##     [--mask=<dir>] [--ignore=x,y,w,h ...]
## --ignore skips a rectangle (4K pixels; repeatable): a known run-to-run speck, found by diffing two
## runs of the same build, never a region of the change under test.

var _a := ""
var _b := ""
const CROP_WIDTH := 1000  # the 2x crops are narrower than this and are never ignored
var _mask := ""
var _ignore: Array[Rect2i] = []


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--a="):
			_a = arg.substr(4)
		elif arg.begins_with("--b="):
			_b = arg.substr(4)
		elif arg.begins_with("--mask="):
			_mask = arg.substr(7)
		elif arg.begins_with("--ignore="):
			var n := arg.substr(9).split_floats(",")
			_ignore.append(Rect2i(int(n[0]), int(n[1]), int(n[2]), int(n[3])))
	var names := Array(DirAccess.get_files_at(_a)).filter(
		func(n: String) -> bool: return n.get_extension() == "png"
	)
	var bad := 0
	for name: String in names:
		var differ := _compare(name)
		bad += 1 if differ != 0 else 0
	print("DIFF total: %d of %d images differ" % [bad, names.size()])
	quit(1 if bad > 0 or names.is_empty() else 0)


## Prints the image's DIFF line; returns its differing pixels (-1: missing or another size).
func _compare(name: String) -> int:
	var a := Image.load_from_file(_a.path_join(name))
	var path_b := _b.path_join(name)
	if not FileAccess.file_exists(path_b):
		print("DIFF %s: missing in %s" % [name, _b])
		return -1
	var b := Image.load_from_file(path_b)
	if a.get_size() != b.get_size():
		print("DIFF %s: size %s vs %s" % [name, a.get_size(), b.get_size()])
		return -1
	a.convert(Image.FORMAT_RGBA8)
	b.convert(Image.FORMAT_RGBA8)
	var da := a.get_data()
	var db := b.get_data()
	if da == db:
		print("DIFF %s: 0 pixels differ (%dx%d)" % [name, a.get_width(), a.get_height()])
		return 0
	var mask := Image.create(a.get_width(), a.get_height(), false, Image.FORMAT_L8)
	var pixels := 0
	var worst := 0
	var w := a.get_width()
	for y: int in a.get_height():
		for x: int in w:
			var p := (y * w + x) * 4
			var delta := 0
			for c: int in 4:
				delta = maxi(delta, absi(da[p + c] - db[p + c]))
			if delta > 0 and not (w > CROP_WIDTH and _ignored(x, y)):
				pixels += 1
				worst = maxi(worst, delta)
				mask.set_pixel(x, y, Color.WHITE)
	print("DIFF %s: %d pixels differ%s, largest channel difference %d" % [name, pixels, " (outside --ignore)" if not _ignore.is_empty() else "", worst])
	if _mask != "":
		DirAccess.make_dir_recursive_absolute(_mask)
		mask.save_png(_mask.path_join(name.get_basename() + "_mask.png"))
	return pixels


func _ignored(x: int, y: int) -> bool:
	for rect: Rect2i in _ignore:
		if rect.has_point(Vector2i(x, y)):
			return true
	return false
