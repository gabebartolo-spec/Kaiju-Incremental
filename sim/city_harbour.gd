class_name CityHarbour
extends RefCounted
## The fixed beachfront the kaiju rises from at the start of every run (D-381, board v4, director
## 2026-10-29: "build this as a bespoke, fixed location, its always the same, just have the
## randomzied map connect to these fixed roads and environmental positions"). Everything north of
## the back street (city "harbour" "back_z", the one street line it pins, CityLines) is the
## front, the same at every stage: the sea, a long curved beach (sand, promenade, the beach road),
## hotel blocks squared off between side streets from the road to the back street, and past the
## beach's east end a man-made seawall and the working port (quay, finger piers, yard). The random
## grid meets it on the back street: no grid street, alley or diagonal is laid north of it, and
## no landmark, park or plaza is chosen there. Part of CityGen.map, which records the front as
## plan["bay"] (out to the map's edges, down to the back street's centre line), plan["harbour"]
## (its shapes) and the rise as plan["rise_spawn"] (in the water off the beach at "rise_x") and
## plan["rise_bank"] (on the sand straight up the beach). Pure.


## The front between the street centre lines: the whole map north of the back street; an empty
## Rect2 without one.
static func rect_of(cfg: Dictionary) -> Rect2:
	if not cfg.has("harbour"):
		return Rect2()
	var outer := Num.f(cfg["outer_half"]) + 1.0
	return Rect2(-outer, -outer, outer * 2.0, Num.f(cfg["harbour"]["back_z"]) + outer)


## True when `rect` reaches into the front (CityGen and CitySites keep landmarks, parks and plazas
## out of it).
static func in_any(cfg: Dictionary, rect: Rect2) -> bool:
	var bay := rect_of(cfg)
	return bay.has_area() and bay.intersects(rect.grow(-0.01))


## The street lines every plan pins: {"x": [], "z": [the back street]}.
static func pins(cfg: Dictionary) -> Dictionary:
	var xs: Array[float] = []
	var zs: Array[float] = []
	if cfg.has("harbour"):
		zs.append(Num.f(cfg["harbour"]["back_z"]))
	return {"x": xs, "z": zs}


## True when the street from a to b enters the front (any part within plan["bay"]): it is never
## laid. The back street lies on its south edge and is laid; a grid line on its west, north or
## east edge is not (the 1.5x city's outermost x-line falls on the east edge).
static func inside(plan: Dictionary, a: Vector2, b: Vector2) -> bool:
	var bay: Rect2 = plan.get("bay", Rect2())
	# Any part of the line inside (not only its middle): a long segment can cross the bay's corner
	# with its middle outside. Only the south edge is inset (-0.01): the back street stays.
	var front := bay.grow_individual(0.01, 0.01, 0.01, -0.01)
	return bay.has_area() and front.intersects(Rect2(a.min(b), (b - a).abs()), true)


## True when the street from a to b lies on the front's edge or inside it (CityAlleys: never an
## alley, so the front always meets a street with a pavement).
static func touches(plan: Dictionary, a: Vector2, b: Vector2) -> bool:
	var bay: Rect2 = plan.get("bay", Rect2())
	return bay.has_area() and bay.grow(0.01).has_point((a + b) * 0.5)


## touches() from the city's config alone (CityAlleys: the back street is never an alley).
static func touches_any(cfg: Dictionary, a: Vector2, b: Vector2) -> bool:
	var bay := rect_of(cfg)
	return bay.has_area() and bay.grow(0.01).has_point((a + b) * 0.5)


## True when grid cell (i, j) lies in the front (its centre inside plan["bay"]).
static func covers(plan: Dictionary, i: int, j: int) -> bool:
	var bay: Rect2 = plan.get("bay", Rect2())
	var xs: Array[float] = plan["xs"]
	var zs: Array[float] = plan["zs"]
	var c := Vector2((xs[i] + xs[i + 1]) * 0.5, (zs[j] + zs[j + 1]) * 0.5)
	return bay.has_area() and bay.has_point(c)


## Marks the front on `plan` (CityGen.map's, its blocks laid): every grid block in it becomes sea
## ("harbour", keeping its use under "was" so CityGen.generate draws its lots the same and drops
## them), its own hotel blocks are added, and its shapes and the rise are recorded. avenues_z:
## the plan's avenue line indices, so the back street's carriageway takes an avenue's width there.
static func mark(
	plan: Dictionary, _avenues_x: Dictionary, avenues_z: Dictionary, cfg: Dictionary
) -> void:
	var bay: Rect2 = plan.get("bay", Rect2())
	if not bay.has_area():
		return
	var zs: Array[float] = plan["zs"]
	var back_kind := CityGen.AVENUE if avenues_z.has(zs.find(bay.end.y)) else CityGen.STREET
	var back := CityGen.width_of(back_kind, cfg) * 0.5
	for block: Dictionary in plan["blocks"]:
		if block.has("cell") and not block.has("site"):
			var cell: Vector2i = block["cell"]
			if covers(plan, cell.x, cell.y):
				block["was"] = block.get("was", block["use"])
				block["use"] = "harbour"
	var h: Dictionary = cfg["harbour"]
	var inner := Rect2(bay.position, Vector2(bay.size.x, bay.size.y - back))
	var ends: Array = h["beach_x"]
	var walls: Array[Rect2] = []
	for r: Array in h["seawall"]:
		walls.append(Rect2(Num.f(r[0]), Num.f(r[1]), Num.f(r[2]), Num.f(r[3])))
	var quay := bands(h, Num.f(ends[1]))[2] - Num.f(h["quay_back"])
	var piers: Array[Rect2] = []
	for r: Array in h["piers"]:
		var w := Num.f(r[1])
		piers.append(Rect2(Num.f(r[0]) - w, quay - Num.f(r[2]), w, Num.f(r[2])))
	var light: Array = h["light"]
	var rise := Num.f(h["rise_x"])
	var apex := shore_at(h, rise)
	plan["harbour"] = {
		"rect": inner,
		"h": h,
		"mouth": Num.f(cfg["coast_z"]),
		"apex": apex,
		"beach_east": Num.f(ends[1]),
		"port_x": walls[0].end.x,
		"quay_z": quay,
		"walls": walls,
		"piers": piers,
		"light": Vector2(Num.f(light[0]), Num.f(light[1])),
		"sides": sides(h, inner),
	}
	plan["rise_spawn"] = Vector2(rise, apex - Num.f(h["beach"]) - Num.f(h["nose_gap"]))
	plan["rise_bank"] = Vector2(rise, apex + Num.f(h["bank_inset"]))
	_hotel_blocks(plan, cfg)


## The side streets' x lines, west from city "harbour" "side_streets" [first, spacing] to the
## front's west edge.
static func sides(h: Dictionary, inner: Rect2) -> Array[float]:
	var row: Array = h["side_streets"]
	var out: Array[float] = []
	var x := Num.f(row[0])
	while x > inner.position.x:
		out.append(x)
		x -= Num.f(row[1])
	return out


## The hotel blocks: one between each pair of side streets (the first from the beach's east end),
## from the beach road's far kerb (its furthest point along the block, so the block is square)
## to the back street, inset by the sidewalk; built inside the last district, a stand-in past
## the stage's band (CityBand), "outer" past the last district.
static func _hotel_blocks(plan: Dictionary, cfg: Dictionary) -> void:
	var b: Dictionary = plan["harbour"]
	var h: Dictionary = b["h"]
	var inner: Rect2 = b["rect"]
	var walk := Num.f(cfg["sidewalk"])
	var street := CityGen.width_of(CityGen.STREET, cfg) * 0.5
	var full := CityGen.districts(cfg)[-1]
	var edges: Array[float] = [Num.f(b["beach_east"]) + street]
	var sides: Array[float] = b["sides"]
	edges.append_array(sides)
	edges.append(inner.position.x - street - walk)
	var blocks: Array[Dictionary] = plan["blocks"]
	var held: Array[int] = []
	for k: int in edges.size() - 1:
		var x0 := edges[k + 1] + street + walk
		var x1 := edges[k] - street - walk
		var kerb := -INF
		var x := x0
		while x < x1 + 0.5:
			kerb = maxf(kerb, bands(h, minf(x, x1))[3])
			x += 0.5
		var rect := Rect2(x0, kerb + walk, x1 - x0, inner.end.y - kerb - walk * 2.0)
		if rect.size.y < Num.f(cfg["depth_min"]) or rect.size.x < Num.f(cfg["frontage_min"]):
			continue
		var city := maxf(absf(x0), absf(x1)) < full
		(
			blocks
			. append(
				{
					"rect": rect,
					"use": "built" if city or CityBand.real(rect, cfg) else "outer",
					"district": CityGen.district_of(rect, cfg),
					"front": true,
				}
			)
		)
		if city:
			held.append(blocks.size() - 1)
	CityBand.hold_back(plan, held, cfg)


## u along the beach: 0 at its east end, 1 at its west end (held past them).
static func _u(h: Dictionary, x: float) -> float:
	var ends: Array = h["beach_x"]
	var east := Num.f(ends[1])
	return clampf((east - x) / (east - Num.f(ends[0])), 0.0, 1.0)


## The waterline's z at x (city "harbour" "shore"; h: that dictionary).
static func shore_at(h: Dictionary, x: float) -> float:
	var s: Array = h["shore"]
	var u := _u(h, x)
	var bulge := Num.f(s[1]) * pow(sin(PI * u), Num.f(s[2]))
	return Num.f(h["sea_z"]) + Num.f(s[0]) + bulge + Num.f(s[3]) * u


## The beach's bands at x, landward: [the waterline, the sand's land edge, the promenade's land
## edge (the beach road's near kerb), the road's far kerb] (z). Past the beach's east end the
## road runs on straight along the port.
static func bands(h: Dictionary, x: float) -> PackedFloat32Array:
	var u := _u(h, x)
	var sand: Array = h["sand"]
	var prom: Array = h["promenade"]
	var water := shore_at(h, x)
	var top := water + lerpf(Num.f(sand[0]), Num.f(sand[1]), u)
	var kerb := top + lerpf(Num.f(prom[0]), Num.f(prom[1]), u)
	return PackedFloat32Array([water, top, kerb, kerb + Num.f(h["road"])])


## The front inside its kerbs (plan["harbour"]["rect"]): no land, pavement block or prop of the
## city's own; the front's water, sand, promenade, roads and port stand there (HarbourView). []
## with none.
static func basin(plan: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if plan.has("harbour"):
		out.append(plan["harbour"]["rect"])
	return out


## Whether p lies in the front's water: seaward of the beach's waterline, of the port's quay (bar
## its piers) and of the seawall, south of the coast.
static func holds(plan: Dictionary, p: Vector2) -> bool:
	if not plan.has("harbour"):
		return false
	var b: Dictionary = plan["harbour"]
	var rect: Rect2 = b["rect"]
	if not rect.has_point(p) or p.y < Num.f(b["mouth"]):
		return false
	var walls: Array[Rect2] = b["walls"]
	if walls.any(func(r: Rect2) -> bool: return r.has_point(p)):
		return false
	if p.x >= Num.f(b["port_x"]):
		var piers: Array[Rect2] = b["piers"]
		var dry := piers.any(func(r: Rect2) -> bool: return r.has_point(p))
		return p.y < Num.f(b["quay_z"]) and not dry
	var h: Dictionary = b["h"]
	return p.y < shore_at(h, p.x)


## Whether p lies on the beach's sand: between the waterline and the promenade, west of the
## seawall.
static func on_sand(plan: Dictionary, _cfg: Dictionary, p: Vector2) -> bool:
	if not plan.has("harbour"):
		return false
	var b: Dictionary = plan["harbour"]
	var rect: Rect2 = b["rect"]
	var h: Dictionary = b["h"]
	var at := bands(h, p.x)
	return rect.has_point(p) and p.x <= Num.f(b["beach_east"]) and p.y >= at[0] and p.y <= at[1]


## The waterline from the front's west edge to the beach's east end (city "harbour" "arc_points"
## samples along the beach).
static func arc(plan: Dictionary, cfg: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	if not plan.has("harbour"):
		return out
	var b: Dictionary = plan["harbour"]
	var h: Dictionary = b["h"]
	var ends: Array = h["beach_x"]
	var rect: Rect2 = b["rect"]
	out.append(Vector2(rect.position.x, shore_at(h, rect.position.x)))
	var n := Num.i(cfg["harbour"]["arc_points"])
	for k: int in n + 1:
		var x := lerpf(Num.f(ends[0]), Num.f(ends[1]), float(k) / n)
		out.append(Vector2(x, shore_at(h, x)))
	return out


## How far p lies from the waterline (the arc), metres.
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


## The wading floor (world y): city "wade_depth" under the sea's surface, where the shelf levels
## out (director 2026-10-31: the baby half submerged).
static func shelf_floor(cfg: Dictionary) -> float:
	return sea(cfg) - Num.f(cfg["wade_depth"])


## How far seaward of the shore line the water meets the sand (the shelf's slope crosses the sea).
static func waterline(cfg: Dictionary) -> float:
	var h: Dictionary = cfg["harbour"]
	var top := Num.f(h["sand_top"])
	return Num.f(h["drop"]) * (top - sea(cfg)) / (top - drop_floor(cfg))


## The foot of the drop (world y): city "harbour" "drop_depth" under the sea's surface, "drop"
## metres out from the shore line (director 2026-10-31: steeper near the shore, so a wave's trough
## never bares the seabed), from where the shelf eases on down to the wading floor.
static func drop_floor(cfg: Dictionary) -> float:
	return sea(cfg) - Num.f(cfg["harbour"]["drop_depth"])


## The ground's height at p: 0 (the street) on land; in the water the sea floor, sloping gently
## from "sand_top" (the sand's own height, just under the street) at the shore line, faster over
## the first "drop" metres to drop_floor, then down to the wading floor by "shelf" metres, measured straight out (director 2026-10-31:
## "slowly deeper but never too deep"); only the rise's hollow goes down to the seabed. The
## port's water is deep to its quay.
static func floor_at(plan: Dictionary, cfg: Dictionary, p: Vector2) -> float:
	if not holds(plan, p):
		return 0.0
	var b: Dictionary = plan["harbour"]
	var h: Dictionary = cfg["harbour"]
	if p.x >= Num.f(b["port_x"]):
		return seabed(cfg)
	var out := shore_at(h, p.x) - p.y
	var drop := Num.f(h["drop"])
	var shelf := lerpf(Num.f(h["sand_top"]), drop_floor(cfg), clampf(out / drop, 0.0, 1.0))
	if out > drop:
		var share := clampf((out - drop) / (Num.f(h["shelf"]) - drop), 0.0, 1.0)
		shelf = lerpf(drop_floor(cfg), shelf_floor(cfg), share)
	var hollow := Num.f(h["hollow"])
	var centre := Vector2(Num.f(h["rise_x"]), Num.f(b["apex"]) - Num.f(h["beach"]) - hollow)
	var rim := smoothstep(hollow, hollow + Num.f(h["hollow_edge"]), p.distance_to(centre))
	return minf(shelf, lerpf(seabed(cfg), shelf, rim))
