class_name CityLots
extends RefCounted
## Fills a block of the street plan (CityGen.map) with buildings, New York and Tokyo style: lots
## line each block face and share party walls (terraces, street walls), with a courtyard in a
## deep block; two tower districts (a midtown and a downtown) thin out to low-rise with front
## yards, where now and then a narrow pencil building shoots up. Lots the diagonal avenue cuts
## through are left as little plazas. Part of CityGen; split out to keep files small.


## One row of lots along a street face: what its terrace shares, drawn once, then each lot.
class Row:
	extends RefCounted
	var r: Rect2i
	var along_x: bool
	var length: int  ## along the street face
	var deep: int  ## across it
	var front: int  ## the street side (-1/+1), 0 for a courtyard
	var back: bool  ## a courtyard row: low buildings behind the street wall
	var cap: int  ## tallest a lot may be here (a courtyard row's; others cap by their own town share)
	var terrace_h: int
	var terrace_style: int
	var yards: bool  ## the lots step back off the street
	var fmin: int  ## narrowest and widest frontage
	var fmax: int
	var height_scale: float


## The buildings of one block. height_scale shrinks them (the outskirts use it).
static func fill_block(
	rng: RandomNumberGenerator,
	plan: Dictionary,
	block: Dictionary,
	cfg: Dictionary,
	height_scale: float
) -> Array[Dictionary]:
	var rect: Rect2 = block["rect"]
	var x0 := ceili(rect.position.x)
	var z0 := ceili(rect.position.y)
	var w := floori(rect.end.x) - x0
	var d := floori(rect.end.y) - z0
	if w < 2 or d < 2:
		return []
	var downtown := town_share(rect.get_center(), cfg)
	var grow := lot_grow(block, cfg)
	var depth := rng.randi_range(Num.i(cfg["depth_min"]), Num.i(cfg["depth_max"])) + grow
	if downtown > 0.6:
		depth += 1
	var rows: Array[Dictionary] = []  # each: rect (Rect2i), along_x, street side (-1/+1)
	if w >= 2 * depth + 2 and d >= 2 * depth + 2:  # a perimeter of lots round a courtyard
		rows.append({"r": Rect2i(x0, z0, w, depth), "along_x": true, "front": -1})
		rows.append({"r": Rect2i(x0, z0 + d - depth, w, depth), "along_x": true, "front": 1})
		rows.append(
			{"r": Rect2i(x0, z0 + depth, depth, d - 2 * depth), "along_x": false, "front": -1}
		)
		rows.append(
			{
				"r": Rect2i(x0 + w - depth, z0 + depth, depth, d - 2 * depth),
				"along_x": false,
				"front": 1
			}
		)
	elif w >= d:  # back to back rows along the long side
		var north := d >> 1
		rows.append({"r": Rect2i(x0, z0, w, north), "along_x": true, "front": -1})
		rows.append({"r": Rect2i(x0, z0 + north, w, d - north), "along_x": true, "front": 1})
	else:
		var west := w >> 1
		rows.append({"r": Rect2i(x0, z0, west, d), "along_x": false, "front": -1})
		rows.append({"r": Rect2i(x0 + west, z0, w - west, d), "along_x": false, "front": 1})
	if rows.size() == 4:  # the courtyard: low buildings behind the street wall, no open pad
		var yard := Rect2i(x0 + depth, z0 + depth, w - 2 * depth, d - 2 * depth)
		rows.append({"r": yard, "along_x": yard.size.x >= yard.size.y, "front": 0, "back": true})
	var out: Array[Dictionary] = []
	for row: Dictionary in rows:
		row["grow"] = grow
		out.append_array(_fill_row(rng, row, downtown, height_scale, plan, cfg))
	return out


## How much bigger than the first district's the lots of a block's district are (D-039: the
## districts a grown kaiju opens are blocks of bigger, denser buildings). Past the last
## district (the outskirts): 0.
static func lot_grow(block: Dictionary, cfg: Dictionary) -> int:
	var grows: Array = cfg.get("district_lot_grow", [])
	var k := Num.i(block.get("district", 0))
	return Num.i(grows[k]) if k < grows.size() else 0


## Tallest a building may be at this much downtown.
static func _height_cap(town: float, cfg: Dictionary) -> int:
	var lo := Num.f(cfg["min_height"]) + 3.0
	return roundi(lerpf(lo, Num.f(cfg["max_height"]), sqrt(town)))


## 0 at the edge of town .. 1 at the core.
static func town_share(p: Vector2, cfg: Dictionary) -> float:
	var best := 0.0
	for c: Vector3 in CityGen.cores(cfg):
		best = maxf(best, 1.0 - p.distance_to(Vector2(c.x, c.y)) / c.z)
	return clampf(best, 0.0, 1.0)


## Cuts a row of lots along its street face; neighbours in a row read as one terrace.
static func _fill_row(
	rng: RandomNumberGenerator,
	spec: Dictionary,
	downtown: float,
	height_scale: float,
	plan: Dictionary,
	cfg: Dictionary
) -> Array[Dictionary]:
	var row := _row(rng, spec, downtown, height_scale, cfg)
	if row == null:
		return []
	var out: Array[Dictionary] = []
	var t := 0
	while t < row.length:
		var span := _span(rng, row, t)
		var town := town_share(_mid(row, t, span), cfg)
		var h := _lot_height(rng, row, town, span, cfg)
		var style := row.terrace_style if rng.randf() < 0.6 else rng.randi_range(0, 3)
		var lot := _lot_rect(rng, row, t, span)
		t += span
		var centre := Vector2(lot.position) + Vector2(lot.size) * 0.5
		if _on_diagonal(plan, centre, Vector2(lot.size), cfg):
			continue  # cut by the diagonal avenue: the leftover corner is a plaza
		out.append(_entry(lot, centre, h, style, cfg))
	return out


## The row's shared numbers, or null when it is too small for a lot. The terrace's height and
## style, and whether it has yards, are drawn here, in that order.
static func _row(
	rng: RandomNumberGenerator,
	spec: Dictionary,
	downtown: float,
	height_scale: float,
	cfg: Dictionary
) -> Row:
	var row := Row.new()
	row.r = spec["r"]
	row.along_x = spec["along_x"]
	row.length = row.r.size.x if row.along_x else row.r.size.y
	row.deep = row.r.size.y if row.along_x else row.r.size.x
	if row.length < 2 or row.deep < 2:
		return null
	var grow := Num.i(spec.get("grow", 0))
	row.front = Num.i(spec["front"])
	row.back = spec.get("back", false)
	row.height_scale = height_scale
	row.fmin = Num.i(cfg["frontage_min"]) + grow
	row.fmax = Num.i(cfg["frontage_max"]) + (2 if downtown > 0.5 else 0) + grow * 2
	var min_h := Num.i(cfg["min_height"])
	row.cap = min_h + 2 if row.back else _height_cap(downtown, cfg)
	row.terrace_h = rng.randi_range(min_h, maxi(min_h, (row.cap + min_h) >> 1))
	row.terrace_style = rng.randi_range(0, 3)
	row.yards = downtown < 0.15 and rng.randf() < Num.f(cfg["yard_chance"]) and not row.back
	return row


## The next lot's frontage from `t` along the row; the last lot takes what is left.
static func _span(rng: RandomNumberGenerator, row: Row, t: int) -> int:
	var span := rng.randi_range(row.fmin, row.fmax)
	if row.length - (t + span) < row.fmin:
		span = row.length - t
	return span


## The middle of the lot at `t` with frontage `span`, in the plan's coordinates.
static func _mid(row: Row, t: int, span: int) -> Vector2:
	var along := t + span * 0.5
	var across := row.deep * 0.5
	return (
		Vector2(row.r.position)
		+ (Vector2(along, across) if row.along_x else Vector2(across, along))
	)


## A lot's height in floors, scaled for the outskirts. Both heights are always drawn, so a
## stage's tower chance or height cap (D-039) never shifts the numbers the lots after this one
## draw.
static func _lot_height(
	rng: RandomNumberGenerator, row: Row, town: float, span: int, cfg: Dictionary
) -> int:
	var min_h := Num.i(cfg["min_height"])
	var cap := row.cap if row.back else _height_cap(town, cfg)
	var h := mini(row.terrace_h + rng.randi_range(-1, 1), cap)
	var roll := rng.randf()
	var tower_h := rng.randi_range(maxi(min_h, roundi(cap * 0.6)), maxi(min_h, cap))
	var pencil: Array = cfg["pencil_height"]
	var pencil_h := rng.randi_range(Num.i(pencil[0]), Num.i(pencil[1]))
	if row.back:
		pass
	elif roll < sqrt(town) * Num.f(cfg["tower_chance"]):
		h = tower_h
	elif span <= 3 and roll > 1.0 - Num.f(cfg["pencil_chance"]):
		h = pencil_h  # a Tokyo pencil building shoots up among the low-rise
	return maxi(2, roundi(h * row.height_scale))


## The lot at `t` along the row; with yards, now and then a house steps back off the street.
static func _lot_rect(rng: RandomNumberGenerator, row: Row, t: int, span: int) -> Rect2i:
	var lot_deep := row.deep
	var shift := 0  # a front yard: the house steps back off the street
	if row.yards and lot_deep >= 3 and rng.randf() < 0.6:
		lot_deep -= 1
		shift = 1 if row.front < 0 else 0
	if row.along_x:
		return Rect2i(row.r.position.x + t, row.r.position.y + shift, span, lot_deep)
	return Rect2i(row.r.position.x + shift, row.r.position.y + t, lot_deep, span)


static func _entry(lot: Rect2i, centre: Vector2, h: int, style: int, cfg: Dictionary) -> Dictionary:
	return {
		"x": centre.x,
		"z": centre.y,
		"w": lot.size.x,
		"d": lot.size.y,
		"h": h,
		"tier": CityGen.tier_for_height(h, cfg),
		"style": style,
	}


## Whether a footprint (centre, size) reaches into the diagonal avenue or its sidewalks.
static func _on_diagonal(plan: Dictionary, centre: Vector2, size: Vector2, cfg: Dictionary) -> bool:
	var diag: Dictionary = plan["diagonal"]
	var dir: Vector2 = diag["dir"]
	var normal := Vector2(-dir.y, dir.x)
	var reach := absf(normal.x) * size.x * 0.5 + absf(normal.y) * size.y * 0.5
	var clear := CityGen.width_of(CityGen.DIAGONAL, cfg) * 0.5 + Num.f(cfg["sidewalk"]) + reach
	return CityGen.diagonal_distance(plan, centre) < clear
