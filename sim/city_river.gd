class_name CityRiver
extends RefCounted
## The river the kaiju rises from at the start of every run (D-083, director 2026-10-19: "a
## city caught unaware - have our reptilian emerge from a river to start each run"). It is the
## row of blocks just south of the first district's ring avenue, across the whole street grid,
## so it lies in the same place at every stage: past the young city's edge, then through the
## grown city. Its blocks hold water and no buildings; the streets across it are its bridges.
## The row past it is its far bank, a park (lawn and trees, crushable decor): the young city's
## game camera looks across it as the kaiju rises, so no skyline stand-in stands in that view
## (playtest 2026-10-19: "smaller buildings south of the spawn position dont seem
## destructible?").
## Part of CityGen.map, split out to keep files small.


## Turns the river's row of blocks into "river" and the row past it into a "park" in `plan`
## (CityGen.map's; each keeps its old use under "was", for CityGen.generate), and records the
## river's band (z from, z to) as plan["river"] and the kaiju's rise point as
## plan["river_spawn"]: on the city's north-south axis (x 0), in the river block across it or
## the nearest one, at least city "river_inset" in from its ends, and where it wades to as
## plan["river_bank"]: "river_inset" onto the city side, across the ring avenue from it.
## (Emergence caps the wade at tuning "emerge" "max_seconds", so a bank point that lands in the
## water can never stall the run's start.) Where it rises the river widens into a bay (city
## "river_bay", director 2026-10-21 #17: "the river where he emerges from can be slightly wider
## than the other sections of the river to accomodate him"), centred in that block, with a sand
## shore up to the street on the city side: plan["river_bay"] its centre x, and the rise point
## moves to the bay's open water, straight south of the bank point.
static func mark(plan: Dictionary, zs: Array[float], cfg: Dictionary) -> void:
	var row := river_row(zs, cfg)
	if row < 0:
		return
	var inset := Num.f(cfg["river_inset"])
	var band := Vector2(INF, -INF)
	var spawn := Vector2(INF, INF)
	var off := INF  # how far the chosen block lies from the axis
	var home := Rect2()  # the river block the kaiju rises in
	for block: Dictionary in plan["blocks"]:
		if block.has("site") or not block.has("cell"):
			continue
		var cell: Vector2i = block["cell"]
		if cell.y != row and cell.y != row + 1:
			continue
		block["was"] = block["use"]  # CityGen.generate still draws its lots, and drops them
		block["use"] = "river" if cell.y == row else "park"
		if cell.y != row:
			continue
		var rect: Rect2 = block["rect"]
		band = Vector2(minf(band.x, rect.position.y), maxf(band.y, rect.end.y))
		var gap := absf(clampf(0.0, rect.position.x, rect.end.x))
		if gap < off:
			off = gap
			var x := clampf(0.0, rect.position.x + inset, rect.end.x - inset)
			spawn = Vector2(x, rect.get_center().y)
			home = rect
	if spawn.x < INF:
		var bay: Dictionary = cfg["river_bay"]
		var reach := Num.f(bay["length"]) * 0.5 + Num.f(bay["taper"])
		var cx := clampf(spawn.x, home.position.x + reach, home.end.x - reach)
		if home.size.x < reach * 2.0:
			cx = home.get_center().x
		var north := band.x - Num.f(cfg["sidewalk"])
		plan["river"] = band
		plan["river_bay"] = cx
		var water_from := north + Num.f(bay["beach"])  # the shore's foot
		plan["river_spawn"] = Vector2(cx, lerpf(water_from, north + Num.f(bay["depth"]), 0.5))
		plan["river_bank"] = Vector2(cx, band.x - inset)


## The street-grid row (z cell) the river runs along: the one just south of district 0's ring
## line; -1 without a river. CitySites keeps every landmark's site out of it (sim review FIX
## 2026-10-20 on #88: a landmark in this row would stand in the water).
static func river_row(zs: Array[float], cfg: Dictionary) -> int:
	if not cfg.get("river", false):
		return -1
	var edge := CityGen.districts(cfg)[0]
	var row := -1
	for j: int in zs.size() - 1:
		if is_equal_approx(zs[j], edge):
			row = j
	return row


## The river's open water (x, z): ONE channel from the west end of the street grid to the east
## end, however many blocks and gaps lie along it (a gap is a street or a landmark's site; each
## is carried over the water by CityRiver.bridges, so the water runs on under all of them and is
## never cut short). Empty without a river.
static func channels(plan: Dictionary, cfg: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var spans := _spans(plan, cfg)
	if spans.is_empty():
		return out
	var whole := spans[0]
	for span: Rect2 in spans:
		whole = whole.merge(span)
	out.append(whole)
	return out


## The bay where the kaiju rises (city "river_bay"): a full-depth basin "length" long reaching
## "depth" south of the channel's north edge, and a shallower step "taper" longer at each end,
## half as far past the channel, so the widening tapers back to the river. Empty without one.
static func bay(plan: Dictionary, cfg: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var main := channels(plan, cfg)
	if main.is_empty() or not plan.has("river_bay"):
		return out
	var b: Dictionary = cfg["river_bay"]
	var cx := Num.f(plan["river_bay"])
	var length := Num.f(b["length"])
	var north := main[0].position.y
	var south := north + Num.f(b["depth"])
	out.append(Rect2(cx - length * 0.5, north, length, south - north))
	var past := south - main[0].end.y
	if past > 0.0:
		var wide := length + Num.f(b["taper"]) * 2.0
		out.append(Rect2(cx - wide * 0.5, main[0].end.y - 1.0, wide, past * 0.5 + 1.0))
	return out


## All the river's open water: its channel and its bay.
static func water(plan: Dictionary, cfg: Dictionary) -> Array[Rect2]:
	var out := channels(plan, cfg)
	out.append_array(bay(plan, cfg))
	return out


## The sand shore the kaiju climbs out on: the bay's city-side edge, "beach" deep, sloping from
## the street down to the river's floor (empty Rect2 without a bay).
static func shore(plan: Dictionary, cfg: Dictionary) -> Rect2:
	var basin := bay(plan, cfg)
	if basin.is_empty():
		return Rect2()
	var b: Dictionary = cfg["river_bay"]
	return Rect2(basin[0].position, Vector2(basin[0].size.x, Num.f(b["beach"])))


## How high the ground stands at p, from 0 (the street) down to -"river_depth" (the river's
## floor): the floor anywhere in the water, a straight slope across the shore.
static func floor_at(plan: Dictionary, cfg: Dictionary, p: Vector2) -> float:
	var bed := -Num.f(cfg.get("river_depth", 0.0))
	var sand := shore(plan, cfg)
	if sand.has_area() and sand.has_point(p):
		return bed * (p.y - sand.position.y) / sand.size.y
	for w: Rect2 in water(plan, cfg):
		if w.has_point(p):
			return bed
	return 0.0


## The streets carried over the bay (x, z): each east-west street's carriageway and sidewalks
## where they cross it.
static func bay_bridges(plan: Dictionary, cfg: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var basin := bay(plan, cfg)
	if basin.is_empty():
		return out
	var span := basin[0]
	for r: Rect2 in basin:
		span = span.merge(r)
	var nodes: Array[Vector2] = plan["nodes"]
	var side := Num.f(cfg["sidewalk"])
	for street: Dictionary in plan["streets"]:
		var a := nodes[Num.i(street["from"])]
		var b := nodes[Num.i(street["to"])]
		if not is_equal_approx(a.y, b.y):
			continue
		var half := Num.f(street["width"]) * 0.5 + side
		var road := Rect2(minf(a.x, b.x), a.y - half, absf(b.x - a.x), half * 2.0)
		if road.intersects(span) and a.y > basin[0].position.y + Num.f(cfg["river_bay"]["beach"]):
			out.append(road.intersection(span))
	return out


## The roads across the river (x, z): one deck over the water in every gap between neighbouring
## river blocks, a street's or a site's.
static func bridges(plan: Dictionary, cfg: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var spans := _spans(plan, cfg)
	for n: int in range(1, spans.size()):
		var from := spans[n - 1].end.x
		if spans[n].position.x - from > 0.01:
			out.append(
				Rect2(from, spans[n].position.y, spans[n].position.x - from, spans[n].size.y)
			)
	return out


## Quay sheds (lead check 2026-10-19: the young city's first steps out of the water must hit
## something): small buildings lining the pavement of each bare built block of the first
## district (one whose lots came out empty, a sliver between close street lines) within
## city "quay" "reach" of the bank point. They draw their own numbers, so no other lot moves,
## and stand the same at every stage.
static func sheds(plan: Dictionary, bare: Array[Dictionary], cfg: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not plan.has("river_bank"):
		return out
	var quay: Dictionary = cfg["quay"]
	var bank: Vector2 = plan["river_bank"]
	var widths: Array = quay["width"]
	var heights: Array = quay["height"]
	var gap := Num.i(quay["gap"])
	var rng := RandomNumberGenerator.new()
	rng.seed = Num.i(cfg["map_seed"]) + 3
	var clear := CityGen.width_of(CityGen.DIAGONAL, cfg) * 0.5 + 1.0
	for block: Dictionary in bare:
		var rect: Rect2 = block["rect"]
		var strip := rect.grow(Num.f(cfg["sidewalk"]))
		var along_x := strip.size.x >= strip.size.y
		var length := roundi(maxf(strip.size.x, strip.size.y))
		var deep := floori(minf(strip.size.x, strip.size.y))
		var t := gap
		while deep >= 2:
			var w := rng.randi_range(Num.i(widths[0]), Num.i(widths[1]))
			var h := rng.randi_range(Num.i(heights[0]), Num.i(heights[1]))
			var style := rng.randi_range(0, 3)
			if t + w > length - gap:
				break
			var mid := t + w * 0.5
			var c := (
				strip.position + (Vector2(mid, deep * 0.5) if along_x else Vector2(deep * 0.5, mid))
			)
			t += w + gap
			if c.distance_to(bank) > Num.f(quay["reach"]):
				continue
			if CityGen.diagonal_distance(plan, c) < clear + w:
				continue
			(
				out
				. append(
					{
						"x": c.x,
						"z": c.y,
						"w": w if along_x else deep,
						"d": deep if along_x else w,
						"h": h,
						"tier": CityGen.tier_for_height(h, cfg),
						"style": style,
					}
				)
			)
	return out


## The river blocks with their sidewalks, west to east.
static func _spans(plan: Dictionary, cfg: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for block: Dictionary in plan["blocks"]:
		if str(block["use"]) == "river":
			var rect: Rect2 = block["rect"]
			out.append(rect.grow(Num.f(cfg["sidewalk"])))
	out.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
	return out
