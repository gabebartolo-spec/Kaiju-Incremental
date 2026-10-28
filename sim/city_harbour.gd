class_name CityHarbour
extends RefCounted
## The bay the kaiju rises from at the start of every run (director 2026-10-26: "move it to the
## bay where a shoreline makes more natural sense ... deploy the kaiju from the bay rather than
## the river"; "Sea bay, real beach"): a crescent of sea cut south from the coast into the city's
## north edge, its city end one continuous sand beach inside the arena, straight quays on its two
## flanks. A rule over the street plan, never fixed coordinates (a random city reuses it):
## centred on the north-south street nearest the city's centre line, as wide as city "harbour"
## "width_share" of the arena (and the stage's biggest body, EmergeReach.fit), its beach "reach_in"
## inside the arena's north edge. Part of CityGen.map, which records it as plan["harbour"]
## {cx, half, mouth, curve_from, apex} and the rise as plan["rise_spawn"] (in the water, on the
## centre line) and plan["rise_bank"] (on the promenade past the beach). Pure.


## Marks the bay on `plan` (CityGen.map's, its streets laid): removes every street that runs
## into its water, turns every block wholly inside it into sea ("harbour"), records the bay and
## the rise. A city without a "harbour" row has none.
static func mark(plan: Dictionary, cfg: Dictionary) -> void:
	if not cfg.has("harbour"):
		return
	var h: Dictionary = cfg["harbour"]
	var edge := CityGen.half_extent(cfg) + Num.f(cfg["arena_margin"])
	var half := maxf(Num.f(h["width_share"]) * edge, Num.f(h.get("fit_width", 0.0)) * 0.5)
	var apex := -edge + Num.f(h["reach_in"])
	var curve := half * Num.f(h["crescent_share"])
	var cx := _centre(plan)
	plan["harbour"] = {
		"cx": cx,
		"half": half,
		"mouth": Num.f(cfg["coast_z"]),
		"curve_from": apex - curve,
		"apex": apex,
	}
	var spawn_z := apex - Num.f(h["beach"]) - Num.f(h["nose_gap"])
	plan["rise_spawn"] = Vector2(cx, spawn_z)
	plan["rise_bank"] = Vector2(cx, apex + Num.f(h["bank_inset"]))
	var water := bands(plan, cfg)
	var side := Num.f(cfg["sidewalk"])
	var nodes: Array[Vector2] = plan["nodes"]
	var kept: Array[Dictionary] = []
	for street: Dictionary in plan["streets"]:
		var a := nodes[Num.i(street["from"])]
		var b := nodes[Num.i(street["to"])]
		var reach := Num.f(street["width"]) * 0.5 + side
		var road := Rect2(a.min(b), (b - a).abs()).grow(reach)
		if not water.any(func(w: Rect2) -> bool: return w.intersects(road)):
			kept.append(street)
	plan["streets"] = kept
	for block: Dictionary in plan["blocks"]:
		var rect: Rect2 = block["rect"]
		var corners := [rect.position, rect.end, Vector2(rect.position.x, rect.end.y)]
		corners.append(Vector2(rect.end.x, rect.position.y))
		if corners.all(func(c: Vector2) -> bool: return holds(plan, c)):  # the bay is convex
			if not block.has("was"):
				block["was"] = block["use"]
			block["use"] = "harbour"


## The north-south street line nearest the city's centre line (x 0): the bay's centre.
static func _centre(plan: Dictionary) -> float:
	var xs: Array[float] = plan["xs"]
	var best := 0.0
	var gap := INF
	for x: float in xs:
		if absf(x) < gap:
			gap = absf(x)
			best = x
	return best


## The bay's water as rects (x, z), each wholly inside it: the straight reach from the coast to
## where the crescent begins, then one band every city "harbour" "step" metres across the
## crescent, each as wide as the curve at its city-side edge, so the land always covers the true
## curve (the beach runs on under it, CityGround). Empty without a bay.
static func bands(plan: Dictionary, cfg: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if not plan.has("harbour"):
		return out
	var b: Dictionary = plan["harbour"]
	var cx := Num.f(b["cx"])
	var half := Num.f(b["half"])
	var mouth := Num.f(b["mouth"])
	var from := Num.f(b["curve_from"])
	var apex := Num.f(b["apex"])
	out.append(Rect2(cx - half, mouth - 1.0, half * 2.0, from - mouth + 1.0))
	var step := Num.f(cfg["harbour"]["step"])
	var z := from
	while z < apex - 0.001:
		var z1 := minf(apex, z + step)
		var w := half * sqrt(maxf(0.0, 1.0 - pow((z1 - from) / (apex - from), 2.0)))
		if w > 0.001:
			out.append(Rect2(cx - w, z, w * 2.0, z1 - z))
		z = z1
	return out


## Whether p lies in the bay's water (the true curve, not the bands).
static func holds(plan: Dictionary, p: Vector2) -> bool:
	if not plan.has("harbour"):
		return false
	var b: Dictionary = plan["harbour"]
	var cx := Num.f(b["cx"])
	var half := Num.f(b["half"])
	var from := Num.f(b["curve_from"])
	var apex := Num.f(b["apex"])
	if absf(p.x - cx) > half or p.y < Num.f(b["mouth"]) or p.y > apex:
		return false
	if p.y <= from:
		return true
	var u := (p.x - cx) / half
	var v := (p.y - from) / (apex - from)
	return u * u + v * v <= 1.0


## The crescent's curve, the beach's waterline-to-street edge, as points from its west end to
## its east end (city "harbour" "arc_points" of them).
static func arc(plan: Dictionary, cfg: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	if not plan.has("harbour"):
		return out
	var b: Dictionary = plan["harbour"]
	var cx := Num.f(b["cx"])
	var half := Num.f(b["half"])
	var from := Num.f(b["curve_from"])
	var depth := Num.f(b["apex"]) - from
	var n := Num.i(cfg["harbour"]["arc_points"])
	for k: int in n + 1:
		var a := PI * float(k) / n  # PI at the west end, 0 at the east: south half of the curve
		out.append(Vector2(cx - cos(a) * half, from + sin(a) * depth))
	return out


## How far p lies from the beach's curve (the arc), metres.
static func from_shore(plan: Dictionary, cfg: Dictionary, p: Vector2) -> float:
	var line := arc(plan, cfg)
	var best := INF
	for k: int in line.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(p, line[k], line[k + 1])
		best = minf(best, p.distance_to(q))
	return best


## The sea's surface (world y): city "harbour" "sea_level".
static func sea(cfg: Dictionary) -> float:
	return Num.f(cfg["harbour"]["sea_level"]) if cfg.has("harbour") else 0.0


## The sea floor at the rise (world y): the sea's surface less city "harbour" "seabed_depth"
## (EmergeReach.fit: the stage's biggest body crouched, plus "seabed_clear"; the data's own
## figure until it is fitted).
static func seabed(cfg: Dictionary) -> float:
	return sea(cfg) - Num.f(cfg["harbour"]["seabed_depth"]) if cfg.has("harbour") else 0.0


## The ground's height at p: 0 (the street) on land; in the bay the sea floor, rising across
## the beach (city "harbour" "beach" metres from its curve) to "sand_top", just under the street.
static func floor_at(plan: Dictionary, cfg: Dictionary, p: Vector2) -> float:
	if not holds(plan, p):
		return 0.0
	var h: Dictionary = cfg["harbour"]
	var share := clampf(from_shore(plan, cfg, p) / Num.f(h["beach"]), 0.0, 1.0)
	return lerpf(Num.f(h["sand_top"]), seabed(cfg), share)


## The buildings of `entries` (CityGen.generate's) clear of the bay's water.
static func dry(plan: Dictionary, cfg: Dictionary, entries: Array[Dictionary]) -> Array[Dictionary]:
	var water := bands(plan, cfg)
	var out: Array[Dictionary] = []
	for e: Dictionary in entries:
		var w := Num.f(e.get("w", 0.0))
		var d := Num.f(e.get("d", 0.0))
		var r := Rect2(Num.f(e["x"]) - w * 0.5, Num.f(e["z"]) - d * 0.5, w, d)
		if not water.any(func(b: Rect2) -> bool: return b.intersects(r)):
			out.append(e)
	return out
