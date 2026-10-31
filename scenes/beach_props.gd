class_name BeachProps
extends RefCounted
## The crowded sand of the fixed beachfront (D-381, board v4): an umbrella with a lounger under it
## on a grid along and across the sand, and volleyball courts (lines, posts and a
## net) with the grid kept off them; city "harbour" "props". Their own PropField, finer than the
## street props' and set on the sand (a court's lines lie flush, everything else stands on it),
## crushed by the kaiju like the street props (CityDecor), an umbrella folding shut and
## falling over rather than flattening to a coloured disc (director 10-30: "Skittles").
## Presentation only; no RNG.


## The beach's props within the decor's view, in their own field (not yet built), or null with
## no beachfront.
static func plant(decor: CityDecor) -> PropField:
	var plan := decor.plan
	if not plan.has("harbour"):
		return null
	var h: Dictionary = plan["harbour"]["h"]
	var cfg: Dictionary = h["props"]
	var field := PropField.new(Num.f(cfg["voxel"]))
	for at: Vector2 in courts(plan):
		if absf(at.x) <= decor._view:
			field.add(Vector3(at.x, 0, at.y), _lines.bind(cfg))
			field.add(Vector3(at.x, 0, at.y), _net.bind(cfg))
	var n := 0
	var folds: Array[String] = ["pole", "umbrella0", "umbrella1", "umbrella2", "umbrella3"]
	for at: Vector2 in spots(plan, decor._view):
		field.add(Vector3(at.x, 0, at.y), _umbrella.bind(cfg, n % 4), false, folds)
		n += 1
	return field


## Each umbrella's pole (x, z) within `view` of the centre (|x|): a grid every spacing along and
## across the sand, from_east in from the beach's east end, from_water past the waterline to
## from_edge short of the promenade, kept court_clear off the courts. Empty with no beachfront.
static func spots(plan: Dictionary, view: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if not plan.has("harbour"):
		return out
	var b: Dictionary = plan["harbour"]
	var h: Dictionary = b["h"]
	var cfg: Dictionary = h["props"]
	var rect: Rect2 = b["rect"]
	var step := Num.f(cfg["spacing"])
	var near := courts(plan)
	var clear: Array = cfg["court_clear"]
	var keep := Vector2(Num.f(clear[0]), Num.f(clear[1]))
	var x := Num.f(b["beach_east"]) - Num.f(cfg["from_east"])
	while x > rect.position.x:
		var band := CityHarbour.bands(h, x)
		var z := band[0] + Num.f(cfg["from_water"])
		while z < band[1] - Num.f(cfg["from_edge"]):
			var at := Vector2(x, z)
			var busy := near.any(
				func(c: Vector2) -> bool:
					return absf(at.x - c.x) < keep.x and absf(at.y - c.y) < keep.y
			)
			if not busy and absf(x) <= view:
				out.append(at)
			z += step
		x -= step
	return out


## Each volleyball court's centre (x, z): at its x, court_shift landward of the sand's middle.
## Empty with no beachfront.
static func courts(plan: Dictionary) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if not plan.has("harbour"):
		return out
	var h: Dictionary = plan["harbour"]["h"]
	var cfg: Dictionary = h["props"]
	for x: float in cfg["courts"]:
		var band := CityHarbour.bands(h, x)
		out.append(Vector2(x, (band[0] + band[1]) * 0.5 + Num.f(cfg["court_shift"])))
	return out


## The palette of the beach's props (city "harbour" "props" "colors").
static func palette(plan: Dictionary) -> Dictionary:
	var out := {}
	var b: Dictionary = plan["harbour"]
	var h: Dictionary = b["h"]
	var colors: Dictionary = h["props"]["colors"]
	for key: String in colors:
		out[key] = Color(str(colors[key]))
	return out


## The field's height: its first cells lie in the sand, line_proud above it.
static func floor_y(plan: Dictionary) -> float:
	var b: Dictionary = plan["harbour"]
	var h: Dictionary = b["h"]
	var cfg: Dictionary = h["props"]
	return Num.f(h["sand_top"]) - Num.f(cfg["voxel"]) + Num.f(cfg["line_proud"])


## An umbrella (a pole and a two-tier canopy in one of four colours) with its lounger under the
## canopy beside the pole, its back raised landward.
static func _umbrella(v: VoxelBuilder, cfg: Dictionary, paint: int) -> void:
	var size: Array = cfg["umbrella"]
	var r := Num.i(size[0])
	var pole := Num.i(size[1])
	var key := "umbrella%d" % paint
	v.box(Vector3i(0, 1, 0), Vector3i(0, pole, 0), "pole")
	v.blob(Vector3(0, pole + 1, 0), Vector3(r + 0.5, 0.5, r + 0.5), key)
	v.blob(Vector3(0, pole + 2, 0), Vector3(r - 0.5, 0.5, r - 0.5), key)
	var lounger: Array = cfg["lounger"]
	var length := Num.i(lounger[0])
	var width := Num.i(lounger[1])
	var back := length / 2  # centred along z under the canopy, beside the pole
	v.box(Vector3i(1, 1, -back), Vector3i(width, 1, length - 1 - back), "lounger")
	v.box(Vector3i(1, 2, length - 1 - back), Vector3i(width, 2, length - 1 - back), "lounger")


## A court's lines, flush with the sand: its edge and the centre line under the net.
static func _lines(v: VoxelBuilder, cfg: Dictionary) -> void:
	var half := _half_cells(cfg)
	for z: int in [-half.y, half.y]:
		v.box(Vector3i(-half.x, 0, z), Vector3i(half.x, 0, z), "court_line")
	for x: int in [-half.x, 0, half.x]:
		v.box(Vector3i(x, 0, -half.y), Vector3i(x, 0, half.y), "court_line")


## A court's net across its middle: a post past each side line and the net between them.
static func _net(v: VoxelBuilder, cfg: Dictionary) -> void:
	var half := _half_cells(cfg)
	var net: Array = cfg["net"]
	var top := Num.i(net[0])
	for z: int in [-half.y - 1, half.y + 1]:
		v.box(Vector3i(0, 1, z), Vector3i(0, top, z), "post")
	v.box(Vector3i(0, top - Num.i(net[1]) + 1, -half.y), Vector3i(0, top, half.y), "net")


## A court's half length (x) and half width (z), cells.
static func _half_cells(cfg: Dictionary) -> Vector2i:
	var court: Array = cfg["court"]
	var voxel := Num.f(cfg["voxel"])
	return Vector2i(roundi(Num.f(court[0]) * 0.5 / voxel), roundi(Num.f(court[1]) * 0.5 / voxel))
