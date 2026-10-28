class_name CityRiver
extends RefCounted
## The city's river (D-083; the kaiju rose from it until the director moved the rise to the sea
## bay, 2026-10-26: CityHarbour). It is the
## row of blocks just south of the first district's ring avenue, across the whole street grid,
## so it lies in the same place at every stage: past the young city's edge, then through the
## grown city. Its blocks hold water and no buildings; the streets across it are its bridges.
## The row past it is its far bank, a park (lawn and trees, crushable decor): the young city's
## game camera looks across it, so no skyline stand-in stands in that view (playtest 2026-10-19).
## Part of CityGen.map, split out to keep files small.


## Turns the river's row of blocks into "river" and the row past it into a "park" in `plan`
## (CityGen.map's; each keeps its old use under "was", for CityGen.generate), and records the
## river's band (z from, z to) as plan["river"].
static func mark(plan: Dictionary, zs: Array[float], cfg: Dictionary) -> void:
	var row := river_row(zs, cfg)
	if row < 0:
		return
	var band := Vector2(INF, -INF)
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
	if band.x < INF:
		plan["river"] = band


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
	for n: int in range(1, spans.size()):
		var from := spans[n - 1].end.x
		if spans[n].position.x - from > 0.01:
			out.append(Rect2(from, z0, spans[n].position.x - from, deep))
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
## something; lead 2026-10-26, once blocks grew, D-265: "blocks within quay reach of the bank
## build the 2 m sheds on their river face, so the start plays as before"): every built block of
## the first district within city "quay" "reach" of the bank point drops the lots that reach
## within it (off_quay) and lines that ground with small sheds instead, in rows "depth" deep
## from its river face inward. They draw their own numbers, so no other lot moves, and stand the
## same at every stage.
static func on_quay(plan: Dictionary, block: Dictionary, cfg: Dictionary) -> bool:
	if not plan.has("rise_bank"):
		return false
	var rect: Rect2 = block["rect"]
	var bank: Vector2 = plan["rise_bank"]
	return _gap(rect, bank) <= Num.f(cfg["quay"]["reach"])


## The lots of a quay block that stand clear of the quay (every one, without a river).
static func off_quay(
	plan: Dictionary, lots: Array[Dictionary], cfg: Dictionary
) -> Array[Dictionary]:
	if not plan.has("rise_bank"):
		return lots
	var reach := Num.f(cfg["quay"]["reach"])
	var bank: Vector2 = plan["rise_bank"]
	var out: Array[Dictionary] = []
	for b: Dictionary in lots:
		if _gap(_foot(b), bank) > reach:
			out.append(b)
	return out


## The sheds of the quay blocks (on_quay), clear of the diagonal and of `standing` (the city's
## other buildings).
static func sheds(
	plan: Dictionary, quay: Array[Dictionary], standing: Array[Dictionary], cfg: Dictionary
) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not plan.has("rise_bank"):
		return out
	var q: Dictionary = cfg["quay"]
	var bank: Vector2 = plan["rise_bank"]
	var rng := RandomNumberGenerator.new()
	rng.seed = Num.i(cfg["map_seed"]) + 3
	var clear := CityGen.width_of(CityGen.DIAGONAL, cfg) * 0.5 + 1.0
	for block: Dictionary in quay:
		var rect: Rect2 = block["rect"]
		for shed: Dictionary in _rows(rng, rect, bank, q):
			var foot := _foot(shed)
			if _gap(foot, bank) > Num.f(q["reach"]):
				continue
			if CityGen.diagonal_distance(plan, foot.get_center()) < clear + foot.size.x:
				continue
			if standing.any(func(b: Dictionary) -> bool: return _foot(b).intersects(foot)):
				continue
			shed["tier"] = CityGen.tier_for_height(Num.i(shed["h"]), cfg)
			out.append(shed)
	return out


## Rows of sheds along a block's face toward the bank, "depth" deep each, back to back inward;
## along each row, widths and gaps drawn from `rng` (every shed draws, kept or not).
static func _rows(
	rng: RandomNumberGenerator, rect: Rect2, bank: Vector2, q: Dictionary
) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var depth := Num.i(q["depth"])
	var gap := Num.i(q["gap"])
	var widths: Array = q["width"]
	var heights: Array = q["height"]
	var south := bank.y >= rect.get_center().y  # rows start at the face toward the bank
	for k: int in floori(rect.size.y / depth):
		var z := rect.end.y - depth * (k + 0.5) if south else rect.position.y + depth * (k + 0.5)
		var t := float(gap)
		while true:
			var w := rng.randi_range(Num.i(widths[0]), Num.i(widths[1]))
			var h := rng.randi_range(Num.i(heights[0]), Num.i(heights[1]))
			var style := rng.randi_range(0, 3)
			if t + w > rect.size.x - gap:
				break
			out.append(
				{
					"x": rect.position.x + t + w * 0.5,
					"z": z,
					"w": w,
					"d": depth,
					"h": h,
					"style": style
				}
			)
			t += w + gap
	return out


static func _foot(b: Dictionary) -> Rect2:
	var w := Num.f(b["w"])
	var d := Num.f(b["d"])
	return Rect2(Num.f(b["x"]) - w * 0.5, Num.f(b["z"]) - d * 0.5, w, d)


## How far `p` lies from `rect` (0 inside it).
static func _gap(rect: Rect2, p: Vector2) -> float:
	return p.clamp(rect.position, rect.end).distance_to(p)


## The river blocks with their sidewalks, west to east.
static func _spans(plan: Dictionary, cfg: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for block: Dictionary in plan["blocks"]:
		if str(block["use"]) == "river":
			var rect: Rect2 = block["rect"]
			out.append(rect.grow(Num.f(cfg["sidewalk"])))
	out.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
	return out
