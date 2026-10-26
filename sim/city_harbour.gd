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
	var rail := Num.f(plan.get("rail_x", 0.0))  # the railway's avenue (CitySites.find)
	var xs: Array[float] = plan["xs"]
	var cx := centre(xs, rail)
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
	_drop_streets(plan, water, Num.f(cfg["sidewalk"]))
	_mark_blocks(plan, water)


## Removes every street of `plan` that runs into the bay's `water` (side: the sidewalk's width).
static func _drop_streets(plan: Dictionary, water: Array[Rect2], side: float) -> void:
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


## Turns every block of `plan` wholly in the bay's `water` into sea ("harbour"); one the bay
## partly covers keeps its largest dry part (its lots fill it: no bare remainder).
static func _mark_blocks(plan: Dictionary, water: Array[Rect2]) -> void:
	for block: Dictionary in plan["blocks"]:
		var rect: Rect2 = block["rect"]
		var corners := [rect.position, rect.end, Vector2(rect.position.x, rect.end.y)]
		corners.append(Vector2(rect.end.x, rect.position.y))
		var dry := _dry_part(rect, water)
		if corners.all(func(c: Vector2) -> bool: return holds(plan, c)) or not dry.has_area():
			if not block.has("was"):  # the bay is convex: all four corners in, all of it in
				block["was"] = block["use"]
			block["use"] = "harbour"
		elif dry != rect:
			block["rect"] = dry  # its lots fill what the bay leaves (no bare remainder)


## The largest part of `rect` clear of the bay's `water` (bands): south of it, or beside it to the
## east or west; rect itself when the bay misses it, an empty Rect2 when no part is left.
static func _dry_part(rect: Rect2, water: Array[Rect2]) -> Rect2:
	var hit := water.filter(func(w: Rect2) -> bool: return w.intersects(rect))
	if hit.is_empty():
		return rect
	var south := rect.position.y
	var east := rect.position.x
	var west := rect.end.x
	for w: Rect2 in hit:
		south = maxf(south, w.end.y)
		east = maxf(east, w.end.x)
		west = minf(west, w.position.x)
	var best := Rect2()
	for part: Rect2 in [
		Rect2(rect.position.x, south, rect.size.x, rect.end.y - south),
		Rect2(east, rect.position.y, rect.end.x - east, rect.size.y),
		Rect2(rect.position.x, rect.position.y, west - rect.position.x, rect.size.y),
	]:
		if part.size.x > 0.0 and part.size.y > 0.0 and part.get_area() > best.get_area():
			best = part
	return best


## The north-south street line nearest the city's centre line (x 0), never the railway's avenue
## (`rail`): the bay's centre, so the viaduct never runs up the kaiju's way out of the water.
static func centre(xs: Array[float], rail: float) -> float:
	var best := 0.0
	var gap := INF
	for x: float in xs:
		if absf(x) < gap and not is_equal_approx(x, rail):
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


## The railway's avenue (Rail): the north-south avenue line (`avenues`: CityGen's x-line indices)
## nearest the city's centre line, inside the city's half; 0 without one.
static func rail_line(xs: Array[float], avenues: Dictionary, cfg: Dictionary) -> float:
	var half := CityGen.half_extent(cfg)
	var best := INF
	for i: int in avenues:
		if absf(xs[i]) < half - 1.0 and absf(xs[i]) < absf(best):
			best = xs[i]
	return 0.0 if best == INF else best


## Where the bay can reach at any stage (one box, x and z, per district ring of city "districts":
## that stage's beach width, from its apex north), for CitySites to keep landmarks off: a site
## clear of every box stays clear of the bay as the city grows, so it never moves between stages.
static func reaches(xs: Array[float], rail: float, cfg: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if not cfg.has("harbour"):
		return out
	var h: Dictionary = cfg["harbour"]
	var cx := centre(xs, rail)
	var far := Num.f(cfg["outer_half"]) * 2.0
	for ring: float in CityGen.districts(cfg):
		var edge := ring + Num.f(cfg["arena_margin"])
		var half := Num.f(h["width_share"]) * edge
		if is_equal_approx(ring, CityGen.half_extent(cfg)):
			half = maxf(half, Num.f(h.get("fit_width", 0.0)) * 0.5)
		var apex := -edge + Num.f(h["reach_in"])
		out.append(Rect2(cx - half, -far, half * 2.0, apex + far))
	return out


## Where the kaiju rises in this city's bay before the blocks are laid (CitySpread keeps the
## landmarks off it): on the bay's centre line, off the foot of its beach. INF without a bay.
static func rise_estimate(xs: Array[float], rail: float, cfg: Dictionary) -> Vector2:
	if not cfg.has("harbour"):
		return Vector2(INF, INF)
	var h: Dictionary = cfg["harbour"]
	var edge := CityGen.half_extent(cfg) + Num.f(cfg["arena_margin"])
	var apex := -edge + Num.f(h["reach_in"])
	return Vector2(centre(xs, rail), apex - Num.f(h["beach"]) - Num.f(h["nose_gap"]))
