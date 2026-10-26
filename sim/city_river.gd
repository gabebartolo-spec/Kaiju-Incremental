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
## water can never stall the run's start.)
static func mark(plan: Dictionary, zs: Array[float], cfg: Dictionary) -> void:
	var row := river_row(zs, cfg)
	if row < 0:
		return
	var inset := Num.f(cfg["river_inset"])
	var band := Vector2(INF, -INF)
	var spawn := Vector2(INF, INF)
	var off := INF  # how far the chosen block lies from the axis
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
	if spawn.x < INF:
		plan["river"] = band
		plan["river_spawn"] = spawn
		plan["river_bank"] = Vector2(spawn.x, band.x - inset)
		_dig_inlets(plan, band, cfg)


## A bridge landmark's water (D-254): an inlet off the river's far bank, its span's length less a
## landing at each end wide, from the river's open water to a landing short of its plaza's far
## kerb, so the bridge meets land at both ends (#12). Sets the site's "water" (Rect2) and "at"
## (where the bridge stands: across the inlet's middle).
static func _dig_inlets(plan: Dictionary, band: Vector2, cfg: Dictionary) -> void:
	var walk := Num.f(cfg["sidewalk"])
	for site: Dictionary in plan.get("sites", []):
		var spec: Dictionary = site["spec"]
		if str(spec.get("kind", "")) != "bridge":
			continue
		var shape: Dictionary = site["shape"]
		var rect: Rect2 = site["rect"]
		var landing := Num.f(spec["landing"])
		var wide := Num.f(shape["w"]) - 2.0 * landing
		var top := band.y + walk  # where the river's open water ends (a sidewalk past its blocks)
		var water := Rect2(
			rect.get_center().x - wide * 0.5, top, wide, rect.end.y - landing - top
		)
		site["water"] = water
		site["at"] = Vector2(rect.get_center().x, water.get_center().y)


## Every bridge inlet's water (empty without one).
static func inlets(plan: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for site: Dictionary in plan.get("sites", []):
		if site.has("water"):
			out.append(site["water"])
	return out


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
## never cut short), first; then each bridge landmark's inlet off it. Empty without a river.
static func channels(plan: Dictionary, cfg: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var spans := _spans(plan, cfg)
	if spans.is_empty():
		return out
	var whole := spans[0]
	for span: Rect2 in spans:
		whole = whole.merge(span)
	out.append(whole)
	out.append_array(inlets(plan))
	return out


## The roads across the river (x, z): one deck over the water in every gap between neighbouring
## river blocks, a street's or a site's, from bank to bank of the whole channel (its blocks are
## not all as deep, so a deck as deep as the block beside it stopped short of the bank: director,
## build 4 comments 2026-10-21 #12, "bridge is not connected to land").
static func bridges(plan: Dictionary, cfg: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var spans := _spans(plan, cfg)
	var water := channels(plan, cfg)
	if water.is_empty():
		return out
	var z0 := water[0].position.y
	var deep := water[0].size.y
	var mouths: Array[Rect2] = []  # no road bridge where an inlet opens (its streets are cut)
	for site: Dictionary in plan.get("sites", []):
		if site.has("water"):
			mouths.append(site["outer"])
	for n: int in range(1, spans.size()):
		var from := spans[n - 1].end.x
		if spans[n].position.x - from > 0.01:
			var deck := Rect2(from, z0, spans[n].position.x - from, deep)
			var cut := false
			for mouth: Rect2 in mouths:
				var mid := deck.get_center().x
				cut = cut or (mid > mouth.position.x and mid < mouth.end.x)
			if not cut:
				out.append(deck)
	return out


## The diagonal avenue's own bridge over the river (roads suite R2: no road crosses open water
## off a deck): its centre line from where its carriageway first reaches over the water to where
## it last does, {from, to, width}; {} when it never crosses.
static func diagonal_deck(plan: Dictionary, cfg: Dictionary) -> Dictionary:
	var water := channels(plan, cfg)
	var diag: Dictionary = plan["diagonal"]
	var at: Vector2 = diag["at"]
	var dir: Vector2 = diag["dir"]
	if water.is_empty() or absf(dir.y) < 0.01:
		return {}
	var width := CityGen.width_of(CityGen.DIAGONAL, cfg)
	var lean := width * 0.5 * absf(dir.x)  # how far the carriageway's edges reach past its centre in z
	var ends: Array[Vector2] = []
	for z: float in [water[0].position.y - lean, water[0].end.y + lean]:
		ends.append(at + dir * ((z - at.y) / dir.y))
	var mid := (ends[0] + ends[1]) * 0.5
	if mid.x < water[0].position.x or mid.x > water[0].end.x:
		return {}
	return {"from": ends[0], "to": ends[1], "width": width}


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
