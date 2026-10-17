class_name CityLots
extends RefCounted
## Fills a block of the street plan (CityGen.map) with buildings, New York and Tokyo style: lots
## line each block face and share party walls (terraces, street walls), with a courtyard in a
## deep block; two tower districts (a midtown and a downtown) thin out to low-rise with front
## yards, where now and then a narrow pencil building shoots up. Lots the diagonal avenue cuts
## through are left as little plazas. Part of CityGen; split out to keep files small.


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
	row: Dictionary,
	downtown: float,
	height_scale: float,
	plan: Dictionary,
	cfg: Dictionary
) -> Array[Dictionary]:
	var r: Rect2i = row["r"]
	var along_x: bool = row["along_x"]
	var length := r.size.x if along_x else r.size.y
	var deep := r.size.y if along_x else r.size.x
	if length < 2 or deep < 2:
		return []
	var grow := Num.i(row.get("grow", 0))
	var fmin := Num.i(cfg["frontage_min"]) + grow
	var fmax := Num.i(cfg["frontage_max"]) + (2 if downtown > 0.5 else 0) + grow * 2
	var min_h := Num.i(cfg["min_height"])
	var back: bool = row.get("back", false)
	var row_cap := _height_cap(downtown, cfg)
	if back:
		row_cap = min_h + 2
	var terrace_h := rng.randi_range(min_h, maxi(min_h, (row_cap + min_h) >> 1))
	var terrace_style := rng.randi_range(0, 3)
	var yards := downtown < 0.15 and rng.randf() < Num.f(cfg["yard_chance"]) and not back
	var out: Array[Dictionary] = []
	var t := 0
	while t < length:
		var span := rng.randi_range(fmin, fmax)
		if length - (t + span) < fmin:
			span = length - t
		var mid := (
			Vector2(r.position)
			+ (
				Vector2(t + span * 0.5, deep * 0.5)
				if along_x
				else Vector2(deep * 0.5, t + span * 0.5)
			)
		)
		var town := town_share(mid, cfg)
		var cap := row_cap if back else _height_cap(town, cfg)
		var h := mini(terrace_h + rng.randi_range(-1, 1), cap)
		var roll := rng.randf()
		# Both heights are always drawn, so a stage's tower chance or height cap (D-039) never
		# shifts the numbers the lots after this one draw.
		var tower_h := rng.randi_range(maxi(min_h, roundi(cap * 0.6)), maxi(min_h, cap))
		var pencil: Array = cfg["pencil_height"]
		var pencil_h := rng.randi_range(Num.i(pencil[0]), Num.i(pencil[1]))
		if back:
			pass
		elif roll < sqrt(town) * Num.f(cfg["tower_chance"]):
			h = tower_h
		elif span <= 3 and roll > 1.0 - Num.f(cfg["pencil_chance"]):
			h = pencil_h  # a Tokyo pencil building shoots up among the low-rise
		h = maxi(2, roundi(h * height_scale))
		var style := terrace_style if rng.randf() < 0.6 else rng.randi_range(0, 3)
		var lot_deep := deep
		var shift := 0  # a front yard: the house steps back off the street
		if yards and lot_deep >= 3 and rng.randf() < 0.6:
			lot_deep -= 1
			shift = 1 if Num.i(row["front"]) < 0 else 0
		var lot := Rect2i()
		if along_x:
			lot = Rect2i(r.position.x + t, r.position.y + shift, span, lot_deep)
		else:
			lot = Rect2i(r.position.x + shift, r.position.y + t, lot_deep, span)
		t += span
		var centre := Vector2(lot.position) + Vector2(lot.size) * 0.5
		if _on_diagonal(plan, centre, Vector2(lot.size), cfg):
			continue  # cut by the diagonal avenue: the leftover corner is a plaza
		(
			out
			. append(
				{
					"x": centre.x,
					"z": centre.y,
					"w": lot.size.x,
					"d": lot.size.y,
					"h": h,
					"tier": CityGen.tier_for_height(h, cfg),
					"style": style,
				}
			)
		)
	return out


## Whether a footprint (centre, size) reaches into the diagonal avenue or its sidewalks.
static func _on_diagonal(plan: Dictionary, centre: Vector2, size: Vector2, cfg: Dictionary) -> bool:
	var diag: Dictionary = plan["diagonal"]
	var dir: Vector2 = diag["dir"]
	var normal := Vector2(-dir.y, dir.x)
	var reach := absf(normal.x) * size.x * 0.5 + absf(normal.y) * size.y * 0.5
	var clear := CityGen.width_of(CityGen.DIAGONAL, cfg) * 0.5 + Num.f(cfg["sidewalk"]) + reach
	return CityGen.diagonal_distance(plan, centre) < clear
