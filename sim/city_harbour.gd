class_name CityHarbour
extends RefCounted
## The sea bay the kaiju rises from at the start of every run (D-270: a crescent bay on the city's
## north edge, a sand beach at its city end, quays on its flanks; D-373: every run starts in it;
## director 2026-10-28: "if its easier the bay can always be in the same positon on the map,
## fixed location"). It is laid first, as a fixed rectangle of whole blocks centred on x 0: city
## "harbour" "bays" holds one [half, south] per stage (district), its side street lines at x
## +-half and its coast road, the beach promenade, on the z-line at `south`. CityLines pins those
## lines into every plan (every stage's, so the plan is the same at each); no street, alley or
## diagonal is laid inside the stage's bay (the streets that reach it end in a T on its coast road
## or side streets), its blocks are sea ("harbour"), and no landmark, park or plaza is chosen in
## it. The crescent (sand, water) and the straight quays are drawn inside the rectangle; the
## street plan never sees the curve. Part of CityGen.map, which records the bay as plan["bay"]
## (the rectangle between the street centre lines), plan["harbour"] {cx, half, mouth, curve_from,
## apex, rect, quay} and the rise as plan["rise_spawn"] (in the water on the centre line) and
## plan["rise_bank"] (on the sand straight up the beach). Pure.


## The stage's bay row of city "harbour" "bays" ([half, south]): the district whose half-extent
## is the city's own (the stage in play); [] without a bay.
static func row(cfg: Dictionary) -> Array:
	if not cfg.has("harbour"):
		return []
	var bays: Array = cfg["harbour"]["bays"]
	var rings := CityGen.districts(cfg)
	var half := CityGen.half_extent(cfg)
	var k := 0
	while k < rings.size() - 1 and rings[k] < half - 0.001:
		k += 1
	return bays[mini(k, bays.size() - 1)]


## The bay between its street centre lines (x, z): x +-half, from past the outskirts' north edge
## down to the coast road at `south`; an empty Rect2 without a bay.
static func rect_of(cfg: Dictionary) -> Rect2:
	var at := row(cfg)
	if at.is_empty():
		return Rect2()
	var half := Num.f(at[0])
	var top := -Num.f(cfg["outer_half"]) - 1.0
	return Rect2(-half, top, half * 2.0, Num.f(at[1]) - top)


## True when `rect` reaches into any stage's bay (CityGen and CitySites keep landmarks, parks
## and plazas out of every one, so the plan's picks are the same at every stage).
static func in_any(cfg: Dictionary, rect: Rect2) -> bool:
	if not cfg.has("harbour"):
		return false
	var top := -Num.f(cfg["outer_half"]) - 1.0
	for at: Array in cfg["harbour"]["bays"]:
		var half := Num.f(at[0])
		if Num.f(at[1]) <= top:
			continue  # an older stage's bay lies past this young city's north edge
		if Rect2(-half, top, half * 2.0, Num.f(at[1]) - top).intersects(rect.grow(-0.01)):
			return true
	return false


## The street lines every plan pins, from every stage's bay: {"x": [...], "z": [...]}, so the
## street plan is the same at every stage (only the bay in play changes).
static func pins(cfg: Dictionary) -> Dictionary:
	var xs: Array[float] = []
	var zs: Array[float] = []
	if cfg.has("harbour"):
		for at: Array in cfg["harbour"]["bays"]:
			for x: float in [-Num.f(at[0]), Num.f(at[0])]:
				if not x in xs:
					xs.append(x)
			if not Num.f(at[1]) in zs:
				zs.append(Num.f(at[1]))
	return {"x": xs, "z": zs}


## True when the street from a to b enters the bay (any part strictly within plan["bay"]):
## it is never laid. The bay's own side streets and coast road lie on its edge and are laid.
static func inside(plan: Dictionary, a: Vector2, b: Vector2) -> bool:
	var bay: Rect2 = plan.get("bay", Rect2())
	# Any part of the line inside (not only its middle): a long segment can cross the bay's corner
	# with its middle outside. Streets along the bay's edge stay (the -0.01 inset).
	return bay.has_area() and bay.grow(-0.01).intersects(Rect2(a.min(b), (b - a).abs()), true)


## True when the street from a to b lies on the bay's edge or inside it (CityAlleys: never an
## alley, so the bay always meets a street with a pavement).
static func touches(plan: Dictionary, a: Vector2, b: Vector2) -> bool:
	var bay: Rect2 = plan.get("bay", Rect2())
	return bay.has_area() and bay.grow(0.01).has_point((a + b) * 0.5)


## touches() for every stage's bay (CityAlleys: a line that edges a bay at any stage is a street
## with a pavement at every stage, so the young city's blocks keep their kerbs as it grows).
static func touches_any(cfg: Dictionary, a: Vector2, b: Vector2) -> bool:
	if not cfg.has("harbour"):
		return false
	var top := -Num.f(cfg["outer_half"]) - 1.0
	for at: Array in cfg["harbour"]["bays"]:
		var half := Num.f(at[0])
		if Num.f(at[1]) <= top:
			continue  # an older stage's bay lies past this young city's north edge
		if Rect2(-half, top, half * 2.0, Num.f(at[1]) - top).grow(0.01).has_point((a + b) * 0.5):
			return true
	return false


## True when grid cell (i, j) lies in the bay (its centre inside plan["bay"]).
static func covers(plan: Dictionary, i: int, j: int) -> bool:
	var bay: Rect2 = plan.get("bay", Rect2())
	var xs: Array[float] = plan["xs"]
	var zs: Array[float] = plan["zs"]
	var c := Vector2((xs[i] + xs[i + 1]) * 0.5, (zs[j] + zs[j + 1]) * 0.5)
	return bay.has_area() and bay.has_point(c)


## Marks the bay on `plan` (CityGen.map's, its blocks laid): every block in it becomes sea
## ("harbour", keeping its use under "was" so CityGen.generate draws its lots the same and drops
## them), and records its shapes and the rise. avenues_x/avenues_z: the plan's avenue line
## indices, so the side streets' and coast road's carriageways take an avenue's width there.
static func mark(
	plan: Dictionary, avenues_x: Dictionary, avenues_z: Dictionary, cfg: Dictionary
) -> void:
	var bay: Rect2 = plan.get("bay", Rect2())
	if not bay.has_area():
		return
	var xs: Array[float] = plan["xs"]
	var zs: Array[float] = plan["zs"]
	var side_kind := CityGen.AVENUE if avenues_x.has(xs.find(bay.position.x)) else CityGen.STREET
	var coast_kind := CityGen.AVENUE if avenues_z.has(zs.find(bay.end.y)) else CityGen.STREET
	var side := CityGen.width_of(side_kind, cfg) * 0.5
	var coast := CityGen.width_of(coast_kind, cfg) * 0.5
	for block: Dictionary in plan["blocks"]:
		if block.has("cell") and not block.has("site"):
			var cell: Vector2i = block["cell"]
			if covers(plan, cell.x, cell.y):
				block["was"] = block.get("was", block["use"])
				block["use"] = "harbour"
	var h: Dictionary = cfg["harbour"]
	var walk := Num.f(cfg["sidewalk"])
	var inner := Rect2(
		bay.position.x + side, bay.position.y, bay.size.x - side * 2.0, bay.size.y - coast
	)
	var half := inner.size.x * 0.5 - walk - Num.f(h["quay"])
	var apex := inner.end.y - walk - Num.f(h["sand"])
	plan["harbour"] = {
		"cx": inner.get_center().x,
		"half": half,
		"mouth": Num.f(cfg["coast_z"]),
		"curve_from": apex - half * Num.f(h["crescent_share"]),
		"apex": apex,
		"rect": inner,
		"quay": Num.f(h["quay"]) + walk,
	}
	var cx := inner.get_center().x
	plan["rise_spawn"] = Vector2(cx, apex - Num.f(h["beach"]) - Num.f(h["nose_gap"]))
	plan["rise_bank"] = Vector2(cx, apex + Num.f(h["bank_inset"]))


## The bay inside its kerbs (plan["harbour"]["rect"]): no land, pavement block or prop of the
## city's own; the harbour's water, sand, promenade and quays stand there (HarbourView). [] with
## none.
static func basin(plan: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if plan.has("harbour"):
		out.append(plan["harbour"]["rect"])
	return out


## Whether p lies in the bay's water (the crescent's true curve, between the quays, south of the
## coast).
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


## Whether p lies on the bay's sand: inside its kerbs, between the quays, past the promenade's
## pavement and out of the water.
static func on_sand(plan: Dictionary, cfg: Dictionary, p: Vector2) -> bool:
	if not plan.has("harbour"):
		return false
	var b: Dictionary = plan["harbour"]
	var cx := Num.f(b["cx"])
	var shore := Num.f(b["apex"]) + Num.f(cfg["harbour"]["sand"])
	var curve := Num.f(b["curve_from"])
	return (
		absf(p.x - cx) <= Num.f(b["half"]) and p.y >= curve and p.y <= shore and not holds(plan, p)
	)


## The crescent's curve, the waterline, as points from its west end to its east end (city
## "harbour" "arc_points" of them).
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


## The ground's height at p: 0 (the street) on land; in the bay's water the sea floor, rising
## across the beach (city "harbour" "beach" metres from its curve) to "sand_top", the sand's own
## height, just under the street.
static func floor_at(plan: Dictionary, cfg: Dictionary, p: Vector2) -> float:
	if not holds(plan, p):
		return 0.0
	var h: Dictionary = cfg["harbour"]
	var share := clampf(from_shore(plan, cfg, p) / Num.f(h["beach"]), 0.0, 1.0)
	return lerpf(Num.f(h["sand_top"]), seabed(cfg), share)
