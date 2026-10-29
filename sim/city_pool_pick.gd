class_name CityPoolPick
extends RefCounted
## CityPool's model search: which pool model a space takes (its district and role, fits the space,
## suits its height, no copy of itself near, the least used first), and the counts and spots
## that keep copies apart. Works on CityPool.place's ctx. Pure.


## The baked rows' floors by id.
static func heights(book: Dictionary) -> Dictionary:
	var pool: Dictionary = book["pool"]
	var out: Dictionary = {}
	for id: String in pool:
		var row: Dictionary = pool[id]
		out[id] = Num.i(row.get("h", 0))
	return out


## The baked ids of each "district|role", sorted.
static func by_kind(book: Dictionary) -> Dictionary:
	var pool: Dictionary = book["pool"]
	var ids: Array = pool.keys()
	ids.sort()
	var out: Dictionary = {}
	for id: Variant in ids:
		var row: Dictionary = pool[id]
		if not row.has("w"):
			continue
		var key := "%s|%s" % [row["district"], row["role"]]
		var list: Array = out.get(key, [])
		list.append(str(id))
		out[key] = list
	return out


## The id CityPool._choose takes, or "": the least used of the suited ids with no copy near.
static func best(rect: Rect2, want: Dictionary, ctx: Dictionary) -> String:
	var counts: Dictionary = ctx["count"]
	var heights: Dictionary = ctx["heights"]
	var pl: Dictionary = ctx["pl"]
	var span := _height_span(want, pl)
	var at := rect.get_center()
	var best: Array[String] = []
	var best_uses := 1 << 30
	for id: String in _suited(rect, want, ctx):
		var h: int = heights[id]
		if h < span.x or h > span.y or _crowded(id, at, ctx):
			continue
		var uses := Num.i(counts.get(id, 0))
		if uses < best_uses:
			best_uses = uses
			best.clear()
		if uses == best_uses:
			best.append(id)
	return "" if best.is_empty() else best[Num.i(want["pick"]) % best.size()]


## The ids of want's district and role that fit `rect` (and are big enough for a block, when
## want.big), sorted; kept in ctx per kind of space, as lots repeat their sizes.
static func _suited(rect: Rect2, want: Dictionary, ctx: Dictionary) -> Array:
	var key := [
		want["district"],
		want["role"],
		floori(rect.size.x + 0.001),
		floori(rect.size.y + 0.001),
		want.get("slack", -1),
		want.get("big", false),
	]
	var memo: Dictionary = ctx["suited"]
	var known: Variant = memo.get(key)
	if known != null:
		var hit: Array = known
		return hit
	var book: Dictionary = ctx["book"]
	var pool: Dictionary = book["pool"]
	var pl: Dictionary = ctx["pl"]
	var by: Dictionary = ctx["by"]
	var ids: Array = by.get("%s|%s" % [want["district"], want["role"]], [])
	var out: Array = []
	for id: Variant in ids:
		var row: Dictionary = pool[id]
		if (
			want.get("big", false)
			and mini(Num.i(row["w"]), Num.i(row["d"])) < Num.i(pl["big_side"])
		):
			continue
		if _fits_any(row, key):
			out.append(id)
	memo[key] = out
	return out


## Whether `row` fits the space of a _suited key (w, d, slack) in either turn.
static func _fits_any(row: Dictionary, key: Array) -> bool:
	var w: int = key[2]
	var d: int = key[3]
	var slack: int = key[4]
	var rw := Num.i(row["w"])
	var rd := Num.i(row["d"])
	for turn: bool in [false, true]:
		var a := rd if turn else rw
		var b := rw if turn else rd
		if a <= w and b <= d and (slack < 0 or (w - a <= slack and d - b <= slack)):
			return true
	return false


static func count(id: String, at: Vector2, ctx: Dictionary) -> void:
	var counts: Dictionary = ctx["count"]
	counts[id] = Num.i(counts.get(id, 0)) + 1
	var used: Dictionary = ctx["used"]
	var spots: Array = used.get(id, [])
	spots.append(at)
	used[id] = spots


static func _crowded(id: String, at: Vector2, ctx: Dictionary) -> bool:
	var reuse := Num.f(ctx["pl"]["reuse_m"])
	var used: Dictionary = ctx["used"]
	var spots: Array = used.get(id, [])
	for spot: Vector2 in spots:
		if spot.distance_squared_to(at) < reuse * reuse:
			return true
	return false


## The floors (lowest, highest) a model may have to suit want.h: within height_fit of them (a
## share, never under height_fit_min floors); a block model (hero or big filler) any height up to
## hero_rise times the block's tallest lot.
static func _height_span(want: Dictionary, pl: Dictionary) -> Vector2:
	var lot_h := Num.f(want["h"])
	if want.has("big"):
		return Vector2(
			0.0, maxf(lot_h * Num.f(pl["hero_rise"]), Num.f(pl["height_fit_min"]) + lot_h)
		)
	var slack := maxf(Num.f(pl["height_fit_min"]), lot_h * Num.f(pl["height_fit"]))
	return Vector2(lot_h - slack, lot_h + slack)
