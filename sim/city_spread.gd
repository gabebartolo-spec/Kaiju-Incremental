class_name CitySpread
extends RefCounted
## Where a city's landmarks stand (D-254: "space out our landmarks ... across the new expanded
## area"; the explosive sites are CityHazards'), seeded by the city's map_seed alone, so the
## same seed always gives the same city and every stage shows the sites of the districts it has
## opened (D-039: sites never move between stages). Part of CityGen.map; pure.
##
## The public interface other systems read (districts, city blocks):
##   plan["sites"]            landmark sites (CitySites.find's dictionaries), "district" = ring
##   opens_at(district)       the growth stage (1-based) a district first comes into play
##   width(rings, district)   that stage's play-area width
##
## Spacing (city "spread", lead call 2026-10-26): sites a stage newly opens keep apart by a share
## of that stage's width; a pair with a site of an inner district keeps the share of the INNER
## stage's width. Landmarks also keep spawn_clear x width (or their own "rise_clear" m, the
## stadium: b2-21) from the kaiju's rise, plus rise_slack for the rise's exact spot, which the
## river fixes only once the blocks are laid. A landmark with "far_from_rise" (the stadium: "as
## far away from our spawn spot as possible", b2-21) takes the fitting cell of its district
## farthest from the rise (seeded order breaks a tie); "max_ring" caps its districts (the stadium
## stays reachable from stage 2: D-271); "place_order" places the most constrained first (the
## stadium, then the bridge, which only the river's far bank takes), the rest after them.

const LANDMARK_STREAM := "city_spread"


## The growth stage (1 = the young city) in which district `ring` first lies in the play area.
static func opens_at(ring: int) -> int:
	return ring + 1


## The play-area width (both sides) of the stage that opens district `ring`.
static func width(rings: Array[float], ring: int) -> float:
	return 2.0 * rings[clampi(ring, 0, rings.size() - 1)]


## The landmark sites: the pool (city "landmarks") in seeded order, each into a seeded district
## from its "min_ring" on with room left (spread "landmarks_per_ring"), at the first seeded cell
## of that district where it fits and keeps its distances. A landmark no district can take is
## left out. A spec with an "anchor" [x, z] stands there instead (no spread). Specs place in
## "place_order" (lowest first; none = after every ordered one), seeded order among equals.
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
	pool = _in_place_order(pool)
	var per_ring := Num.i(spread.get("landmarks_per_ring", 0))
	var taken: Array[int] = []
	for k: int in rings.size():
		taken.append(0)
	var zs: Array[float] = plan["zs"]
	var rise := rise_estimate(zs, cfg)
	var out: Array[Dictionary] = []
	for spec: Dictionary in pool:
		var shape: Dictionary = shapes[str(spec["id"])]
		if spec.has("anchor"):  # pinned where the spec says (a test fixture's own plan)
			var at: Array = spec["anchor"]
			var pinned := CitySites.site_at(
				plan, spec, shape, Vector2(Num.f(at[0]), Num.f(at[1])), axes
			)
			if not pinned.is_empty():
				out.append(pinned)
			continue
		var choices: Array = []
		var last := mini(Num.i(spec.get("max_ring", rings.size() - 1)), rings.size() - 1)
		for k: int in range(Num.i(spec.get("min_ring", 0)), last + 1):
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
	if spec.get("far_from_rise", false) and rise.x != INF:
		anchors = _farthest_first(anchors, rise)
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


## The pool sorted by "place_order" (none = last); equal orders keep their (seeded) order.
static func _in_place_order(pool: Array) -> Array:
	var keyed: Array = []
	for n: int in pool.size():
		var spec: Dictionary = pool[n]
		keyed.append([-Num.f(spec.get("place_order", INF)), n, spec])
	keyed.sort_custom(_farther)
	var out: Array = []
	for row: Array in keyed:
		out.append(row[2])
	return out


## The anchors sorted farthest from the rise first; equal distances keep their (seeded) order.
static func _farthest_first(anchors: Array, rise: Vector2) -> Array:
	var keyed: Array = []
	for n: int in anchors.size():
		var at: Vector2 = anchors[n]
		keyed.append([at.distance_to(rise), n, at])
	keyed.sort_custom(_farther)
	var out: Array = []
	for row: Array in keyed:
		out.append(row[2])
	return out


## Sort order for [key, seeded index, item] rows: the larger key first, then the lower index.
static func _farther(a: Array, b: Array) -> bool:
	var da: float = a[0]
	var db: float = b[0]
	if da != db:
		return da > db
	var ia: int = a[1]
	var ib: int = b[1]
	return ia < ib


static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for n: int in range(items.size() - 1, 0, -1):
		var m := rng.randi_range(0, n)
		var keep: Variant = items[n]
		items[n] = items[m]
		items[m] = keep
