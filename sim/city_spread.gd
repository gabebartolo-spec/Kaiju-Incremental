class_name CitySpread
extends RefCounted
## Where a city's landmarks and explosive sites stand (D-254: "space out our landmarks ... and
## explosive sites across the new expanded area"), seeded by the city's map_seed alone, so the
## same seed always gives the same city and every stage shows the sites of the districts it has
## opened (D-039: sites never move between stages). Part of CityGen.map; pure.
##
## The public interface other systems read (districts, city blocks, the explosives):
##   plan["sites"]            landmark sites (CitySites.find's dictionaries), "district" = ring
##   plan["explosive_sites"]  explosive_sites(): {"at": Vector2, "district": int, "rect": Rect2}
##   opens_at(district)       the growth stage (1-based) a district first comes into play
##   width(rings, district)   that stage's play-area width
##
## Spacing (city "spread", lead call 2026-10-26): sites a stage newly opens keep apart by a share
## of that stage's width; a pair with a site of an inner district keeps the share of the INNER
## stage's width. Landmarks also keep spawn_clear x width (or their own "rise_clear" m, the
## stadium: b2-21) from the kaiju's rise, plus rise_slack for the rise's exact spot, which the
## river fixes only once the blocks are laid. Explosive sites cover all four quadrants of each
## district and stand explosive_landmark_clear m off every landmark's plaza.

const LANDMARK_STREAM := "city_spread"
const EXPLOSIVE_STREAM := "explosive_sites"
const QUADRANTS: Array[Vector2] = [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]


## The growth stage (1 = the young city) in which district `ring` first lies in the play area.
static func opens_at(ring: int) -> int:
	return ring + 1


## The play-area width (both sides) of the stage that opens district `ring`.
static func width(rings: Array[float], ring: int) -> float:
	return 2.0 * rings[clampi(ring, 0, rings.size() - 1)]


## The landmark sites: the pool (city "landmarks") in seeded order, each into a seeded district
## from its "min_ring" on with room left (spread "landmarks_per_ring"), at the first seeded cell
## of that district where it fits and keeps its distances. A landmark no district can take is
## left out.
static func landmarks(
	plan: Dictionary, rings: Array[float], avenues: Array, cfg: Dictionary
) -> Array[Dictionary]:
	var spread: Dictionary = cfg.get("spread", {})
	var shapes: Dictionary = cfg.get("landmark_shapes", {})
	var rng := Seeds.make(LANDMARK_STREAM, Num.i(cfg["map_seed"]))
	var axes := [
		{"lines": plan["xs"], "rings": rings, "avenues": avenues[0], "cfg": cfg},
		{"lines": plan["zs"], "rings": rings, "avenues": avenues[1], "cfg": cfg},
	]
	var pool: Array = []
	for spec: Dictionary in cfg.get("landmarks", []):
		if shapes.has(str(spec["id"])):
			pool.append(spec)
	_shuffle(pool, rng)
	var per_ring := Num.i(spread.get("landmarks_per_ring", 0))
	var taken: Array[int] = []
	for k: int in rings.size():
		taken.append(0)
	var zs: Array[float] = plan["zs"]
	var rise := rise_estimate(zs, cfg)
	var out: Array[Dictionary] = []
	for spec: Dictionary in pool:
		var shape: Dictionary = shapes[str(spec["id"])]
		var choices: Array = []
		for k: int in range(Num.i(spec.get("min_ring", 0)), rings.size()):
			if taken[k] < per_ring:
				choices.append(k)
		_shuffle(choices, rng)
		for k: int in choices:
			var site := _place(plan, spec, shape, k, axes, out, rise, rng)
			if not site.is_empty():
				out.append(site)
				taken[k] += 1
				break
	return out


## Roughly where the kaiju rises (CityRiver.mark fixes it once the blocks are laid): the middle
## of the river's row on the city's axis. INF without a river.
static func rise_estimate(zs: Array[float], cfg: Dictionary) -> Vector2:
	var row := CityRiver.river_row(zs, cfg)
	if row < 0:
		return Vector2(INF, INF)
	return Vector2(0.0, (zs[row] + zs[row + 1]) * 0.5)


## The explosive sites (after the blocks are laid): per district, spread "explosives_per_ring"
## built blocks big enough for a lot, one in each quadrant first, then anywhere, keeping the
## spacing, off the landmarks and the rise. Each is its block's centre: {"at", "district",
## "rect"} (the block, so a reader can pick the building that stands there).
static func explosive_sites(plan: Dictionary, cfg: Dictionary) -> Array[Dictionary]:
	var spread: Dictionary = cfg.get("spread", {})
	var counts: Array = spread.get("explosives_per_ring", [])
	var rings := CityGen.districts(cfg)
	var rng := Seeds.make(EXPLOSIVE_STREAM, Num.i(cfg["map_seed"]))
	var rise: Vector2 = plan.get("river_spawn", Vector2(INF, INF))
	var landmark_rects: Array[Rect2] = []
	for site: Dictionary in plan.get("sites", []):
		landmark_rects.append(site["rect"])
	var out: Array[Dictionary] = []
	for k: int in mini(rings.size(), counts.size()):
		var pool: Array = []
		for block: Dictionary in plan["blocks"]:
			if _explosive_ok(block, k, rise, rings, landmark_rects, spread):
				pool.append(block["rect"])
		_shuffle(pool, rng)
		var want := Num.i(counts[k])
		var mine: Array[Dictionary] = []
		for q: Vector2 in QUADRANTS:  # one in every quadrant first
			for rect: Rect2 in pool:
				if mine.size() < want and _quadrant(rect.get_center()) == q:
					if _spaced(rect.get_center(), k, mine, out, rings, spread):
						mine.append({"at": rect.get_center(), "district": k, "rect": rect})
						break
		for rect: Rect2 in pool:
			if mine.size() >= want:
				break
			if _spaced(rect.get_center(), k, mine, out, rings, spread):
				mine.append({"at": rect.get_center(), "district": k, "rect": rect})
		out.append_array(mine)
	return out


## Distance from point p to rect (0 inside it).
static func to_rect(p: Vector2, rect: Rect2) -> float:
	var dx := maxf(maxf(rect.position.x - p.x, p.x - rect.end.x), 0.0)
	var dz := maxf(maxf(rect.position.y - p.y, p.y - rect.end.y), 0.0)
	return Vector2(dx, dz).length()


## Gap between two rects (0 when they touch or overlap).
static func rect_gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(maxf(a.position.x - b.end.x, b.position.x - a.end.x), 0.0)
	var dz := maxf(maxf(a.position.y - b.end.y, b.position.y - a.end.y), 0.0)
	return Vector2(dx, dz).length()


## The quadrant of the play area holding p (signs of x and z, 0 counted positive).
static func _quadrant(p: Vector2) -> Vector2:
	return Vector2(-1.0 if p.x < 0.0 else 1.0, -1.0 if p.y < 0.0 else 1.0)


static func _place(
	plan: Dictionary,
	spec: Dictionary,
	shape: Dictionary,
	k: int,
	axes: Array,
	placed: Array[Dictionary],
	rise: Vector2,
	rng: RandomNumberGenerator
) -> Dictionary:
	var along_x: Dictionary = axes[0]
	var cfg: Dictionary = along_x["cfg"]
	var spread: Dictionary = cfg.get("spread", {})
	var rings: Array[float] = along_x["rings"]
	var xs: Array[float] = plan["xs"]
	var zs: Array[float] = plan["zs"]
	var inner := rings[k - 1] if k > 0 else 0.0
	var anchors: Array = []
	for i: int in xs.size() - 1:
		for j: int in zs.size() - 1:
			var at := Vector2((xs[i] + xs[i + 1]) * 0.5, (zs[j] + zs[j + 1]) * 0.5)
			var reach := maxf(absf(at.x), absf(at.y))
			if reach > inner and reach < rings[k]:
				anchors.append(at)
	_shuffle(anchors, rng)
	var bridge := str(spec.get("kind", "")) == "bridge"
	var rows := Num.i(spread.get("bridge_rows", 1))
	for at: Vector2 in anchors:
		var site := (
			CitySites.bridge_at(plan, spec, shape, at.x, axes, rows)
			if bridge
			else CitySites.site_at(plan, spec, shape, at, axes)
		)
		if site.is_empty() or Num.i(site["district"]) != k:
			continue
		if _landmark_ok(site, k, placed, rise, rings, spread):
			return site
	return {}


static func _landmark_ok(
	site: Dictionary,
	k: int,
	placed: Array[Dictionary],
	rise: Vector2,
	rings: Array[float],
	spread: Dictionary
) -> bool:
	var spec: Dictionary = site["spec"]
	var outer: Rect2 = site["outer"]
	var rect: Rect2 = site["rect"]
	var at := rect.get_center()
	var clear := maxf(
		Num.f(spread["spawn_clear"]) * width(rings, k), Num.f(spec.get("rise_clear", 0.0))
	)
	if rise.x != INF and at.distance_to(rise) < clear + Num.f(spread["rise_slack"]):
		return false
	for other: Dictionary in placed:
		var other_outer: Rect2 = other["outer"]
		if outer.grow(-0.01).intersects(other_outer.grow(-0.01)):
			return false
		var ring := mini(k, Num.i(other["district"]))
		var gap := Num.f(spread["landmark_gap"]) * width(rings, ring)
		var other_rect: Rect2 = other["rect"]
		if at.distance_to(other_rect.get_center()) < gap:
			return false
	return true


static func _explosive_ok(
	block: Dictionary,
	k: int,
	rise: Vector2,
	rings: Array[float],
	landmarks: Array[Rect2],
	spread: Dictionary
) -> bool:
	if not str(block["use"]) in ["built", "outer"] or Num.i(block["district"]) != k:
		return false  # the river, its far bank, parks, plazas and landmarks are no lots
	if str(block.get("was", block["use"])) != "built":
		return false
	var rect: Rect2 = block["rect"]
	if minf(rect.size.x, rect.size.y) < Num.f(spread["explosive_min_block"]):
		return false
	var at := rect.get_center()
	if rise.x != INF and at.distance_to(rise) < Num.f(spread["spawn_clear"]) * width(rings, k):
		return false
	for lm: Rect2 in landmarks:
		if rect_gap(rect, lm) < Num.f(spread["explosive_landmark_clear"]):
			return false
	return true


static func _spaced(
	at: Vector2,
	k: int,
	mine: Array[Dictionary],
	inner: Array[Dictionary],
	rings: Array[float],
	spread: Dictionary
) -> bool:
	var share := Num.f(spread["explosive_gap"])
	for s: Dictionary in mine:
		var there: Vector2 = s["at"]
		if at.distance_to(there) < share * width(rings, k):
			return false
	for s: Dictionary in inner:
		var there: Vector2 = s["at"]
		if at.distance_to(there) < share * width(rings, Num.i(s["district"])):
			return false
	return true


## Fisher-Yates from `rng`, so the order is the seed's alone.
static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for n: int in range(items.size() - 1, 0, -1):
		var m := rng.randi_range(0, n)
		var keep: Variant = items[n]
		items[n] = items[m]
		items[m] = keep
