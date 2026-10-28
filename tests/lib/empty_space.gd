extends RefCounted
## "No empty space" measured (director 2026-10-18: "there should never be vast empty spaces with
## nothing to smash or kill"; R 6.1). Pure measures over a stage's street plan, its layout and
## what the decor put down, so tests/run_empty_space_tests.gd checks them and a throwaway run can
## feed them a planted empty block or a stripped street to see each go red.

## How finely a street's centre line is walked for the gap measure (world units).
const STEP := 0.5
## Bucket size of the smashables' spatial hash (world units).
const BUCKET := 8.0


## Per district (block "district"), over the plan's "built" blocks: {k: {"blocks", "area",
## "built", "share", "empty": [Rect2]}}, where "built" is the buildings' footprint inside the
## block (a building belongs to the block holding its centre) and "empty" lists the built blocks
## that could hold a lot (dry_holds_a_lot, off the diagonal) and hold no building at all.
static func districts(plan: Dictionary, layout: Array[Dictionary], cfg: Dictionary) -> Dictionary:
	var built: Array[Dictionary] = []
	for block: Dictionary in plan["blocks"]:
		if str(block["use"]) == "built":
			built.append(block)
	var lots: Array[int] = []
	var area: Array[float] = []
	for block: Dictionary in built:
		lots.append(0)
		area.append(0.0)
	for e: Dictionary in layout:
		var w := Num.f(e["w"])
		var d := Num.f(e["d"])
		var at := Vector2(Num.f(e["x"]), Num.f(e["z"]))
		var foot := Rect2(at - Vector2(w, d) * 0.5, Vector2(w, d))
		for n: int in built.size():
			var rect: Rect2 = built[n]["rect"]
			if rect.grow(0.01).has_point(at):
				lots[n] += 1
				area[n] += rect.intersection(foot).get_area()
				break
	var out := {}
	for n: int in built.size():
		var k := Num.i(built[n]["district"])
		if not out.has(k):
			out[k] = {"blocks": 0, "area": 0.0, "built": 0.0, "share": 0.0, "empty": []}
		var row: Dictionary = out[k]
		var rect: Rect2 = built[n]["rect"]
		row["blocks"] = Num.i(row["blocks"]) + 1
		row["area"] = Num.f(row["area"]) + rect.get_area()
		row["built"] = Num.f(row["built"]) + area[n]
		if lots[n] == 0 and dry_holds_a_lot(plan, rect) and not on_diagonal(plan, rect, cfg):
			var empty: Array = row["empty"]
			empty.append(rect)
	for k: int in out:
		var row: Dictionary = out[k]
		row["share"] = Num.f(row["built"]) / maxf(Num.f(row["area"]), 0.001)
	return out


## True when CityLots.fill_block can put a lot on the block: its whole-unit span is at least 3
## both ways (a row of lots needs 2 deep and the block splits back to back; 2 deep or less is a
## kerb sliver between two close street lines, not ground left bare).
static func holds_a_lot(rect: Rect2) -> bool:
	var w := floori(rect.end.x) - ceili(rect.position.x)
	var d := floori(rect.end.y) - ceili(rect.position.y)
	return mini(w, d) >= 3


## holds_a_lot for the block's dry ground: a block the sea bay (CityHarbour) reaches holds a lot
## when some whole-unit square 3 by 3 of it is dry (CityHarbour.dry drops the lots in the water;
## a beach-front sliver too thin for a lot is not ground left bare).
static func dry_holds_a_lot(plan: Dictionary, rect: Rect2) -> bool:
	if not holds_a_lot(rect):
		return false
	if CityHarbour.south_at(plan, rect.position.x, rect.end.x) < rect.position.y:
		return true  # the bay never reaches it
	var x0 := ceili(rect.position.x)
	var z0 := ceili(rect.position.y)
	var nx := floori(rect.end.x) - x0
	var nz := floori(rect.end.y) - z0
	var dry: Array[bool] = []
	for j: int in nz:
		for i: int in nx:
			var cell := Rect2(x0 + i, z0 + j, 1.0, 1.0)
			var spots := [cell.position, cell.end, cell.get_center()]
			spots.append_array(
				[Vector2(cell.end.x, cell.position.y), Vector2(cell.position.x, cell.end.y)]
			)
			dry.append(not spots.any(func(q: Vector2) -> bool: return CityHarbour.holds(plan, q)))
	for j: int in nz - 2:
		for i: int in nx - 2:
			var all := true
			for dj: int in 3:
				for di: int in 3:
					all = all and dry[(j + dj) * nx + i + di]
			if all:
				return true
	return false


## True when the diagonal avenue (its carriageway and sidewalks) reaches into the block: its lots
## there are left as little plazas (CityLots), and the diagonal's own kerbs fill what it leaves
## (parked cars, trees), which the street gap measures.
static func on_diagonal(plan: Dictionary, rect: Rect2, cfg: Dictionary) -> bool:
	var diag: Dictionary = plan["diagonal"]
	var dir: Vector2 = diag["dir"]
	var normal := Vector2(-dir.y, dir.x)
	var reach := absf(normal.x) * rect.size.x * 0.5 + absf(normal.y) * rect.size.y * 0.5
	var clear := CityGen.width_of(CityGen.DIAGONAL, cfg) * 0.5 + Num.f(cfg["sidewalk"]) + reach
	return CityGen.diagonal_distance(plan, rect.get_center()) < clear


## The longest stretch of street centre line inside the arena with nothing to smash within
## reach: {"max", "at" (the stretch's middle), "kind"}. A sample is lined when a building
## footprint, a parked car's footprint or a prop (tree, bush, lamp, bench...) lies within the
## street's half width + sidewalk + pad of it. Water (river channels, the bay past coast_z) and
## everything past the arena's edge cut a stretch: a bridge is no gap.
static func street_gap(
	plan: Dictionary,
	cfg: Dictionary,
	arena_half: float,
	rects: Array[Rect2],
	points: Array[Vector2],
	pad: float
) -> Dictionary:
	var hash := {}
	for r: Rect2 in rects:
		_bucket_rect(hash, r, r)
	for p: Vector2 in points:
		_bucket_rect(hash, Rect2(p, Vector2.ZERO), p)
	var water := CityRiver.channels(plan, cfg)
	var coast := Num.f(cfg["coast_z"])
	var walk := Num.f(cfg["sidewalk"])
	var nodes: Array[Vector2] = plan["nodes"]
	var best := {"max": 0.0, "at": Vector2.ZERO, "kind": ""}
	for s: Dictionary in plan["streets"]:
		var a := nodes[Num.i(s["from"])]
		var b := nodes[Num.i(s["to"])]
		var reach := Num.f(s["width"]) * 0.5 + walk + pad
		var steps := maxi(1, ceili(a.distance_to(b) / STEP))
		var run := 0
		var run_from := a
		for i: int in steps + 1:
			var p := a.lerp(b, float(i) / steps)
			var cut := maxf(absf(p.x), absf(p.y)) > arena_half or p.y < coast
			for w: Rect2 in water:
				cut = cut or w.grow(1.0).has_point(p)
			if cut or _lined(hash, p, reach):
				run = 0
				continue
			if run == 0:
				run_from = p
			run += 1
			var length := run * a.distance_to(b) / steps
			if length > Num.f(best["max"]):
				best = {"max": length, "at": (run_from + p) * 0.5, "kind": str(s["kind"])}
	return best


static func _bucket_rect(hash: Dictionary, r: Rect2, item: Variant) -> void:
	var c0 := Vector2i(floori(r.position.x / BUCKET), floori(r.position.y / BUCKET))
	var c1 := Vector2i(floori(r.end.x / BUCKET), floori(r.end.y / BUCKET))
	for x: int in range(c0.x, c1.x + 1):
		for z: int in range(c0.y, c1.y + 1):
			var key := Vector2i(x, z)
			if not hash.has(key):
				hash[key] = []
			var list: Array = hash[key]
			list.append(item)


static func _lined(hash: Dictionary, p: Vector2, reach: float) -> bool:
	var c0 := Vector2i(floori((p.x - reach) / BUCKET), floori((p.y - reach) / BUCKET))
	var c1 := Vector2i(floori((p.x + reach) / BUCKET), floori((p.y + reach) / BUCKET))
	for x: int in range(c0.x, c1.x + 1):
		for z: int in range(c0.y, c1.y + 1):
			for item: Variant in hash.get(Vector2i(x, z), []):
				if item is Vector2:
					var q: Vector2 = item
					if q.distance_to(p) <= reach:
						return true
				else:
					var r: Rect2 = item
					var near := p.clamp(r.position, r.end)
					if near.distance_to(p) <= reach:
						return true
	return false
