extends RefCounted
## A top-down PNG of one stage's real city (CityBand.extent) for the city audits: blocks by use,
## the river, every road piece at its width, and each violation as a red box with a ring. Headless
## (Image only, no renderer). Palette here, tools only.

const MAX_PX := 1400
const COLORS := {
	"ground": Color("20242a"),
	"built": Color("6a6e72"),
	"park": Color("3f6a3a"),
	"plaza": Color("8a8478"),
	"landmark": Color("7a6a90"),
	"parking": Color("50545a"),
	"river": Color("2a5a6c"),
	"outer": Color("3a3e44"),
	"road": Color("16181a"),
	"alley": Color("2c2e30"),
	"bad": Color("ff2020"),
}


static func save(plan: Dictionary, cfg: Dictionary, violations: Array, path: String) -> int:
	var extent := CityBand.extent(cfg)
	var scale := floorf(MAX_PX / (2.0 * extent))
	var size := roundi(2.0 * extent * scale)
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	img.fill(COLORS["ground"])
	var view := {"img": img, "extent": extent, "scale": scale}
	for block: Dictionary in plan["blocks"]:
		var use := str(block["use"])
		var fill: Color = COLORS.get(use, COLORS["built"])
		_rect(view, CityGen.pavement(block, cfg), fill)
	var nodes: Array[Vector2] = plan["nodes"]
	for s: Dictionary in plan["streets"]:
		var kind := str(s["kind"])
		var color: Color = COLORS["alley"] if kind == CityGen.ALLEY else COLORS["road"]
		var a := nodes[Num.i(s["from"])]
		var b := nodes[Num.i(s["to"])]
		_line(view, [a, b], Num.f(s["width"]), color)
	for v: Dictionary in violations:
		var at: Vector2 = v["at"]
		_rect(view, Rect2(at - Vector2(1.5, 1.5), Vector2(3, 3)), COLORS["bad"])
		_ring(view, at, 5.0, COLORS["bad"])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	return img.save_png(path)


static func _px(view: Dictionary, p: Vector2) -> Vector2i:
	var s: float = view["scale"]
	var e: float = view["extent"]
	return Vector2i(roundi((p.x + e) * s), roundi((p.y + e) * s))


static func _rect(view: Dictionary, r: Rect2, color: Color) -> void:
	var img: Image = view["img"]
	var a := _px(view, r.position)
	var b := _px(view, r.end)
	var clip := Rect2i(Vector2i.ZERO, img.get_size())
	var box := Rect2i(a, b - a).intersection(clip)
	if box.has_area():
		img.fill_rect(box, color)


## A road piece from ends[0] to ends[1], `width` m wide, as stamped squares along its line.
static func _line(view: Dictionary, ends: Array, width: float, color: Color) -> void:
	var a: Vector2 = ends[0]
	var b: Vector2 = ends[1]
	var step := 0.5
	var n := maxi(1, ceili(a.distance_to(b) / step))
	var half := Vector2(width, width) * 0.5
	for i: int in n + 1:
		var p := a.lerp(b, float(i) / n)
		_rect(view, Rect2(p - half, half * 2.0), color)


static func _ring(view: Dictionary, at: Vector2, radius: float, color: Color) -> void:
	var img: Image = view["img"]
	var clip := Rect2i(Vector2i.ZERO, img.get_size())
	for i: int in 64:
		var p := _px(view, at + Vector2.from_angle(TAU * i / 64.0) * radius)
		if clip.has_point(p):
			img.set_pixelv(p, color)
