extends RefCounted
## Window filtering on the stand-in and skyline facades (tuning render_opt.facade_aa; director
## 10-27 on the window-bars clip: "didnt solve the issue, theres still flashing/stuttering lit
## windows"). facade.gdshaderinc paints the windows per pixel; one point sample per pixel made a
## window thinner than the pixel pop in and out as the camera moved (measured on the game route).
## Headless has no GPU, so this reads the shader and redoes its filter on the CPU:
##  - the flag is ON by default, and both facade materials (near and hazed far) carry it and the
##    data's footprint values;
##  - the shader takes the filtered path: the fwidth footprint, every facade cell under the pixel
##    weighted by the share it covers;
##  - with the data's values, a lit window (2 x 2 cells, as the brick facade's) keeps its
##    brightness within JUMP frame to frame under a slow sub-pixel camera drift, at footprints from
##    a quarter of a cell to FOOTS' last, at most MAX_SHARE of the flashes one point sample makes.
## Seeded by design: fixed windows, a fixed drift, no random numbers.

## Pixel footprints, in facade cells (0.25 m each): a near street to the far shore at 1080p.
const FOOTS: Array[float] = [0.3, 0.5, 0.8, 1.2, 1.6, 2.0, 3.0, 4.0, 6.0]
const FRAMES := 120
## Camera drift per frame, in pixels (slower than a pixel, so every landing is seen).
const DRIFT := Vector2(0.29, 0.17)
## A flash: the window's summed brightness jumps by more than this share from one frame.
const JUMP := 0.3
## The brief's bar: flashes down at least 90%.
const MAX_SHARE := 0.1
## Lines the shader must hold for the filtered path.
const SHADER_LINES: Array[String] = [
	"uniform bool filter_windows",
	"vec2 foot = max(fwidth(at) * grain, vec2(1e-5));",
	"if (filter_windows && max(foot.x, foot.y) > filter_start) {",
	"vec2 w = min(foot, vec2(filter_cells));",
	"float k = max(x1 - x0, 0.0) * max(y1 - y0, 0.0);",
]

var _check: Callable


## check: the runner's check.
func _init(p_check: Callable) -> void:
	_check = p_check


func run() -> void:
	var cfg := Content.section("render_opt")
	var on: bool = cfg.get("facade_aa", false) == true
	_check.call(on, "render_opt.facade_aa is ON by default")
	if not cfg.has("facade_aa_start") or not cfg.has("facade_aa_cells"):
		_check.call(false, "render_opt holds facade_aa_start and facade_aa_cells")
		return
	var start := Num.f(cfg["facade_aa_start"])
	var cells := Num.f(cfg["facade_aa_cells"])
	for haze: float in [0.0, 0.004]:
		var mat := CitySkyline.facade_material(haze)
		var carried: bool = (
			mat.get_shader_parameter("filter_windows") == on
			and is_equal_approx(Num.f(mat.get_shader_parameter("filter_start")), start)
			and is_equal_approx(Num.f(mat.get_shader_parameter("filter_cells")), cells)
		)
		_check.call(carried, "the facade material (haze %s) carries render_opt.facade_aa" % haze)
	var src := FileAccess.get_file_as_string("res://scenes/facade.gdshaderinc")
	var missing: Array[String] = []
	for line: String in SHADER_LINES:
		if not src.contains(line):
			missing.append(line)
	_check.call(missing.is_empty(), "facade.gdshaderinc box-filters the windows (missing %s)" % [missing])
	var point := 0
	var filtered := 0
	var worst := ""
	for foot: float in FOOTS:
		var p := _flashes(foot, INF, cells)
		var f := _flashes(foot, start if on else INF, cells)
		point += p
		filtered += f
		if f > 0:
			worst += " foot %s: %d" % [foot, f]
	_check.call(point > 0, "one point sample per pixel flashes in the model (%d)" % point)
	_check.call(
		filtered <= point * MAX_SHARE,
		"filtered windows flash at most %d%% as often as point-sampled (%d vs %d;%s)" % [
			roundi(MAX_SHARE * 100.0), filtered, point, worst]
	)


## Frames on which a window's summed brightness jumps by more than JUMP, over the test windows,
## with pixels `foot` cells wide; past `start` the pixel box-filters a footprint held to `cells`.
func _flashes(foot: float, start: float, cells: float) -> int:
	var count := 0
	for c: int in 6:
		for r: int in 4:
			# 2 x 2 cells, one lit window pair of a floor, each at its own offset to the pixels.
			var lo := Vector2(c * 3.0 + 0.11 * c, r * 4.0 + 1.0 + 0.07 * r)
			var win := Rect2(lo, Vector2(2.0, 2.0))
			var prev := -1.0
			for t: int in FRAMES:
				var e := _energy(win, foot, DRIFT * float(t) * foot, start, cells)
				if prev >= 0.0 and maxf(e, prev) > 0.0 and absf(e - prev) > JUMP * maxf(e, prev):
					count += 1
				prev = e
	return count


## The window's brightness summed over the pixels (pixel k spans cells [k, k + 1) * foot + off):
## the share of each pixel it covers, as the shader's filter takes it, or one point at the middle.
func _energy(win: Rect2, foot: float, off: Vector2, start: float, cells: float) -> float:
	var filter := foot > start
	var w := minf(foot, cells)
	var k0 := Vector2i(floori((win.position.x - off.x) / foot) - 1, floori((win.position.y - off.y) / foot) - 1)
	var k1 := Vector2i(ceili((win.end.x - off.x) / foot) + 1, ceili((win.end.y - off.y) / foot) + 1)
	var sum := 0.0
	for kx: int in range(k0.x, k1.x + 1):
		for ky: int in range(k0.y, k1.y + 1):
			var mid := Vector2((kx + 0.5) * foot, (ky + 0.5) * foot) + off
			if not filter:
				sum += 1.0 if win.has_point(mid) else 0.0
				continue
			var box := Rect2(mid - Vector2(w, w) * 0.5, Vector2(w, w))
			sum += box.intersection(win).get_area() / (w * w)
	return sum
