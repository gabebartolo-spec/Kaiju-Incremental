class_name CityPool
extends RefCounted
## Puts the pool's buildings (data/city_buildings.json: Tripo heroes and fillers, D-256) in the
## city, until the districts layer lands (D-255, D-261). Every neighbourhood (a square of
## placement.patch_m) takes one district style its town share allows. Heroes go first, rarer: a
## block (CityGen.map) now and then takes one of its style that fits it in some facing, set into
## one of its corners, and the lots under it give way. Then a share of the remaining lots each
## take a filler of their style that fits the lot (no more than fill_slack units short of it on
## either side). Every copy picks a facing, a mirror, a floor stretch toward the lots' height and
## a palette shift; a model never stands within placement.reuse_m of another copy of itself, so
## no two copies touch and none crowds a view. Procedural buildings keep every other lot.
## The public interface the city-blocks and districts work will build on:
##   rows(cfg) -> the pool rows by id (empty when off); fits(row, w, d) -> the facings that fit;
##   place(entries, rng, cfg, plan) -> puts pool entries into the layout in place.
## Seeded from its own stream (Seeds.derive), so the lots' own draws never shift. Pure.

const SALT := 0x7095
## The side of the squares the lots are filed under for the block pass (metres).
const INDEX_CELL := 8.0


## The pool's baked rows by id (empty when the pool is off or missing).
static func rows(cfg: Dictionary) -> Dictionary:
	var book: Dictionary = cfg.get("building_pool", {})
	var placement: Dictionary = book.get("placement", {})
	if not placement.get("on", false):
		return {}
	return book.get("pool", {})


## The facings (0..3) in which `row` stands inside a w x d space.
static func fits(row: Dictionary, w: int, d: int) -> Array[int]:
	var out: Array[int] = []
	var rw := Num.i(row["w"])
	var rd := Num.i(row["d"])
	for facing: int in 4:
		var turned := facing % 2 == 1
		if (rd if turned else rw) <= w and (rw if turned else rd) <= d:
			out.append(facing)
	return out


## A layout entry's footprint (x, z centre; w, d).
static func footprint(e: Dictionary) -> Rect2:
	var w := Num.f(e["w"])
	var d := Num.f(e["d"])
	return Rect2(Num.f(e["x"]) - w * 0.5, Num.f(e["z"]) - d * 0.5, w, d)


## Puts block models (heroes, and fillers too big for a lot) on blocks and fillers on lots of
## `entries` (CityGen.generate's), in place.
static func place(
	entries: Array[Dictionary], rng: RandomNumberGenerator, cfg: Dictionary, plan: Dictionary
) -> void:
	if rows(cfg).is_empty():
		return
	var book: Dictionary = cfg["building_pool"]
	var ctx := {
		"cfg": cfg,
		"book": book,
		"pl": book["placement"],
		"r": Seeds.derive(rng, SALT),
		"used": {},
		"count": {},
		"patches": {},
		"gone": {},
		"index": _index(entries),
	}
	var blocks: Array[Dictionary] = []
	for block: Dictionary in plan["blocks"]:
		if str(block["use"]) == "built":
			var got := _block(entries, block, ctx)
			if not got.is_empty():
				blocks.append(got)
	var gone: Dictionary = ctx["gone"]
	var out: Array[Dictionary] = []
	for n: int in entries.size():
		if gone.has(n):
			continue
		var got := _filler(entries[n], ctx)
		out.append(entries[n] if got.is_empty() else got)
	out.append_array(blocks)
	entries.assign(out)


## Entry indices by INDEX_CELL square (a footprint is filed under every square it touches).
static func _index(entries: Array[Dictionary]) -> Dictionary:
	var out: Dictionary = {}
	for n: int in entries.size():
		for cell: Vector2i in _cells(footprint(entries[n])):
			var list: Array = out.get(cell, [])
			list.append(n)
			out[cell] = list
	return out


static func _cells(rect: Rect2) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var lo := Vector2i((rect.position / INDEX_CELL).floor())
	var hi := Vector2i((rect.end / INDEX_CELL).floor())
	for x: int in range(lo.x, hi.x + 1):
		for z: int in range(lo.y, hi.y + 1):
			out.append(Vector2i(x, z))
	return out


## A block's draw: now and then a hero of the block's style (or, less often, a filler too big for
## a lot) set into one of its corners; the lots under it give way. Returns the entry or {}.
## Every block draws the same two numbers, taken or not.
static func _block(entries: Array[Dictionary], block: Dictionary, ctx: Dictionary) -> Dictionary:
	var r: RandomNumberGenerator = ctx["r"]
	var pl: Dictionary = ctx["pl"]
	var roll := r.randf()
	var pick := r.randi()
	var hero := roll < Num.f(pl["hero_chance"])
	if not hero and roll >= Num.f(pl["hero_chance"]) + Num.f(pl["big_chance"]):
		return {}
	var rect: Rect2 = block["rect"]
	var under := _under(entries, rect, ctx)
	if under.is_empty():
		return {}
	var tallest := 0
	for n: int in under:
		tallest = maxi(tallest, Num.i(entries[n]["h"]))
	var want := {"district": _district(rect.get_center(), ctx), "pick": pick, "h": tallest}
	want["role"] = "hero" if hero else "filler"
	want["big"] = not hero
	var placed := _choose(rect, want, Num.i(entries[under[0]]["style"]), ctx)
	if placed.is_empty():
		return {}
	var spot := _corner(rect, placed, pick)
	placed["x"] = spot.get_center().x
	placed["z"] = spot.get_center().y
	_count(str(placed["model"]), spot.get_center(), ctx)
	var gone: Dictionary = ctx["gone"]
	for n: int in under:
		if spot.grow(-0.01).intersects(footprint(entries[n])):
			gone[n] = true
	return placed


## The lots (not landmarks, not already given way) whose footprints meet `rect`.
static func _under(entries: Array[Dictionary], rect: Rect2, ctx: Dictionary) -> Array[int]:
	var index: Dictionary = ctx["index"]
	var gone: Dictionary = ctx["gone"]
	var seen: Dictionary = {}
	var out: Array[int] = []
	for cell: Vector2i in _cells(rect):
		var list: Array = index.get(cell, [])
		for n: int in list:
			if seen.has(n) or gone.has(n):
				continue
			seen[n] = true
			if not entries[n].has("landmark") and rect.intersects(footprint(entries[n])):
				out.append(n)
	out.sort()
	return out


## The hero's footprint set into one of the block's corners (pick chooses which).
static func _corner(rect: Rect2, placed: Dictionary, pick: int) -> Rect2:
	var size := Vector2(Num.f(placed["w"]), Num.f(placed["d"]))
	var corner := (pick >> 12) % 4
	var x := rect.position.x if corner % 2 == 0 else rect.end.x - size.x
	var z := rect.position.y if corner < 2 else rect.end.y - size.y
	return Rect2(x, z, size.x, size.y)


## A lot's filler draw: the pool entry that replaces it, or {}. Every lot draws the same two
## numbers, taken or not; landmarks and heroes are left alone.
static func _filler(lot: Dictionary, ctx: Dictionary) -> Dictionary:
	var r: RandomNumberGenerator = ctx["r"]
	var roll := r.randf()
	var pick := r.randi()
	if lot.has("landmark") or lot.has("model") or roll >= Num.f(ctx["pl"]["share"]):
		return {}
	var rect := footprint(lot)
	var at := rect.get_center()
	var want := {"district": _district(at, ctx), "pick": pick, "h": Num.i(lot["h"])}
	want["role"] = "filler"
	want["slack"] = Num.i(ctx["pl"]["fill_slack"])
	var placed := _choose(rect, want, Num.i(lot["style"]), ctx)
	if not placed.is_empty():
		_count(str(placed["model"]), at, ctx)
	return placed


## The district style round `at`: drawn once per patch among those whose town range holds the
## patch's town share (CityLots.town_share), "residential" when none does.
static func _district(at: Vector2, ctx: Dictionary) -> String:
	var book: Dictionary = ctx["book"]
	var size := Num.f(ctx["pl"]["patch_m"])
	var patch := Vector2i(floori(at.x / size), floori(at.y / size))
	var patches: Dictionary = ctx["patches"]
	if patches.has(patch):
		return str(patches[patch])
	var cfg: Dictionary = ctx["cfg"]
	var town := CityLots.town_share((Vector2(patch) + Vector2(0.5, 0.5)) * size, cfg)
	var districts: Dictionary = book["districts"]
	var names: Array = districts.keys()
	names.sort()
	var allowed: Array[String] = []
	for name: Variant in names:
		var district: Dictionary = districts[name]
		var span: Array = district["town"]
		if town >= Num.f(span[0]) and town <= Num.f(span[1]):
			allowed.append(str(name))
	var r: RandomNumberGenerator = ctx["r"]
	var pick := "residential" if allowed.is_empty() else allowed[r.randi() % allowed.size()]
	patches[patch] = pick
	return pick


## The pool entry for a model that stands in `rect` (centred): want.district and want.role, fits
## in some facing (with no more than want.slack units to spare a side, when set), suits want.h
## floors and has no copy within reuse_m; the least used first (ties by id), want.pick choosing
## among equals and the facing, mirror and palette. {} when none qualifies.
static func _choose(rect: Rect2, want: Dictionary, style: int, ctx: Dictionary) -> Dictionary:
	var id := _best(rect, want, ctx)
	if id == "":
		return {}
	var book: Dictionary = ctx["book"]
	var row: Dictionary = book["pool"][id]
	var pick := Num.i(want["pick"])
	var facings := _facings(row, rect, want)
	var v := {"facing": facings[(pick >> 4) % facings.size()], "mirror": false, "stretch": 0}
	if Num.i(row.get("stretch_floor", -1)) >= 0:
		var room := Num.i(want["h"]) - Num.i(row["h"])
		v["stretch"] = clampi(room, 0, Num.i(ctx["pl"]["max_stretch"]))
	var dims := ModelVariant.size(row, v)
	var cfg: Dictionary = ctx["cfg"]
	var districts: Dictionary = book["districts"]
	var district: Dictionary = districts[str(row["district"])]
	var shifts: Array = district["shifts"]
	return {
		"x": rect.get_center().x,
		"z": rect.get_center().y,
		"w": dims.x,
		"d": dims.z,
		"h": dims.y,
		"tier": CityGen.tier_for_height(dims.y, cfg),
		"style": style,
		"model": id,
		"facing": v["facing"],
		"mirror": (pick >> 8) % 2 == 1,
		"stretch": v["stretch"],
		"palette": (pick >> 9) % shifts.size(),
	}


## The facings in which `row` fits `rect`, short of it by at most want.slack a side when set.
static func _facings(row: Dictionary, rect: Rect2, want: Dictionary) -> Array[int]:
	var w := floori(rect.size.x + 0.001)
	var d := floori(rect.size.y + 0.001)
	var out := fits(row, w, d)
	if not want.has("slack"):
		return out
	var slack := Num.i(want["slack"])
	var tight: Array[int] = []
	for facing: int in out:
		var turned := facing % 2 == 1
		var rw := Num.i(row["d"] if turned else row["w"])
		var rd := Num.i(row["w"] if turned else row["d"])
		if w - rw <= slack and d - rd <= slack:
			tight.append(facing)
	return tight


## The id _choose takes, or "".
static func _best(rect: Rect2, want: Dictionary, ctx: Dictionary) -> String:
	var book: Dictionary = ctx["book"]
	var pool: Dictionary = book["pool"]
	var pl: Dictionary = ctx["pl"]
	var counts: Dictionary = ctx["count"]
	var best: Array[String] = []
	var best_uses := 1 << 30
	var ids: Array = pool.keys()
	ids.sort()
	for id: Variant in ids:
		var row: Dictionary = pool[id]
		if str(row["district"]) != want["district"] or str(row["role"]) != want["role"]:
			continue
		if not row.has("w") or _facings(row, rect, want).is_empty():
			continue
		if (
			want.get("big", false)
			and mini(Num.i(row["w"]), Num.i(row["d"])) < Num.i(pl["big_side"])
		):
			continue
		if not _height_ok(Num.i(row["h"]), want, pl):
			continue
		if _crowded(str(id), rect.get_center(), ctx):
			continue
		var uses := Num.i(counts.get(id, 0))
		if uses < best_uses:
			best_uses = uses
			best.clear()
		if uses == best_uses:
			best.append(str(id))
	return "" if best.is_empty() else best[Num.i(want["pick"]) % best.size()]


static func _count(id: String, at: Vector2, ctx: Dictionary) -> void:
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
		if spot.distance_to(at) < reuse:
			return true
	return false


## A model suits want.h floors within height_fit of them (a share, never under height_fit_min
## floors); a block model (hero or big filler) may stand up to hero_rise times taller than the
## block's tallest lot.
static func _height_ok(h: int, want: Dictionary, pl: Dictionary) -> bool:
	var lot_h := Num.i(want["h"])
	if want.has("big"):
		return h <= maxf(lot_h * Num.f(pl["hero_rise"]), Num.f(pl["height_fit_min"]) + lot_h)
	var slack := maxf(Num.f(pl["height_fit_min"]), lot_h * Num.f(pl["height_fit"]))
	return absf(h - lot_h) <= slack
