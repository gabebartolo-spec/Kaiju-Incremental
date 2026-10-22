extends SceneTree
## Pixel diff of two folders of PNG stills (a before/after pair of capture_graphics.gd runs): for
## every PNG in --a, the PNG of the same name in --b must be the same size and the same bytes.
## Prints one DIFF line per image (differing pixels, the largest channel difference) and a total;
## with --mask=<dir>, writes <name>_mask.png (differing pixels white). Exits 1 on any difference.
##   godot --headless --path . --script tools/capture/image_diff.gd -- --a=<dir> --b=<dir> \
##     [--mask=<dir>] [--noise=<dir1>,<dir2>,...]
## --noise names runs of the SAME build (the "before" several times): a pixel where any two of them
## differ is run-to-run noise (a lit window that blinks), so it is left out of the comparison,
## widened by NOISE_GROW pixels. The 2x crops (narrower than CROP_WIDTH) are never masked.

const NOISE_GROW := 2  # pixels the noise mask is widened by (a speck's soft edge)
const CROP_WIDTH := 1000

var _a := ""
var _b := ""
var _mask := ""
var _noise: PackedStringArray = []


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--a="):
			_a = arg.substr(4)
		elif arg.begins_with("--b="):
			_b = arg.substr(4)
		elif arg.begins_with("--mask="):
			_mask = arg.substr(7)
		elif arg.begins_with("--noise="):
			_noise = arg.substr(8).split(",")
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
	var a := _load(_a.path_join(name))
	var path_b := _b.path_join(name)
	if not FileAccess.file_exists(path_b):
		print("DIFF %s: missing in %s" % [name, _b])
		return -1
	var b := _load(path_b)
	if a.get_size() != b.get_size():
		print("DIFF %s: size %s vs %s" % [name, a.get_size(), b.get_size()])
		return -1
	var da := a.get_data()
	var db := b.get_data()
	if da == db:
		print("DIFF %s: 0 pixels differ (%dx%d)" % [name, a.get_width(), a.get_height()])
		return 0
	var w := a.get_width()
	var noise := _noise_of(name, a.get_size()) if w > CROP_WIDTH else PackedByteArray()
	var mask := Image.create(w, a.get_height(), false, Image.FORMAT_L8)
	var pixels := 0
	var skipped := 0
	var worst := 0
	for y: int in a.get_height():
		for x: int in w:
			var p := (y * w + x) * 4
			var delta := 0
			for c: int in 4:
				delta = maxi(delta, absi(da[p + c] - db[p + c]))
			if delta == 0:
				continue
			if not noise.is_empty() and noise[y * w + x] != 0:
				skipped += 1
				continue
			pixels += 1
			worst = maxi(worst, delta)
			mask.set_pixel(x, y, Color.WHITE)
	var note := "" if noise.is_empty() else " (%d more in the run-to-run noise)" % skipped
	print(
		"DIFF %s: %d pixels differ%s, largest channel difference %d" % [name, pixels, note, worst]
	)
	if _mask != "":
		DirAccess.make_dir_recursive_absolute(_mask)
		mask.save_png(_mask.path_join(name.get_basename() + "_mask.png"))
	return pixels


## One byte per pixel, 1 where the two --noise runs differ or are within NOISE_GROW of such a
## pixel; empty without --noise.
func _noise_of(name: String, size: Vector2i) -> PackedByteArray:
	if _noise.size() < 2:
		return PackedByteArray()
	var first := _load(_noise[0].path_join(name)).get_data()
	var w := size.x
	var h := size.y
	var out := PackedByteArray()
	out.resize(w * h)
	for n: int in range(1, _noise.size()):
		var other := _load(_noise[n].path_join(name)).get_data()
		for py: int in h:
			for px: int in w:
				var p := (py * w + px) * 4
				if first[p] == other[p] and first[p + 1] == other[p + 1] and first[p + 2] == other[p + 2]:
					continue
				for gy: int in range(maxi(py - NOISE_GROW, 0), mini(py + NOISE_GROW + 1, h)):
					for gx: int in range(maxi(px - NOISE_GROW, 0), mini(px + NOISE_GROW + 1, w)):
						out[gy * w + gx] = 1
	return out


func _load(path: String) -> Image:
	var image := Image.load_from_file(path)
	image.convert(Image.FORMAT_RGBA8)
	return image
