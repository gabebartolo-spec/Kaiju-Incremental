extends "res://tests/lib/runner.gd"
## Play area and spread suite (D-254, director 2026-10-26: "1.5x wider", "space out our
## landmarks ... across the new expanded area"; spacing among the sites a stage newly opens,
## pairs with an inner district's site at the inner stage's share: lead call 2026-10-26). Over
## SEEDS street plans (city.map_seed) and every growth stage: the play-area half-widths, landmark
## spacing and rise clearance, the red barrels (CityHazards, as tuned) all in play and none at
## the rise, the stadium far from the rise (b2-21, D-271) at the farthest site, the bridge's
## inlet (at least 3x the river's width, joined to the river, the bridge on land at both ends,
## #12), no skyline core over a play area, and the same plan from the same seed.
## Seeded by design: city.map_seed per plan, the shipped tuning.
##   godot --headless --path . --script tests/run_spread_tests.gd

## The plans checked: the shipped one first, then 19 more.
const SEEDS := 20
const SHIPPED := 7301
const SEED_STEP := 977
## The play area's half-widths per stage (D-254).
const HALVES: Array[float] = [75.0, 120.0, 225.0]
## The least the stadium stands from the stage-1 rise, in metres (lead call 2026-10-27, D-271
## "the stage-2 stadium bar stands"). The sea bay (D-270) puts the rise on the north edge, so
## district 1 offers 155-169 m on the probe seeds; the stadium takes the farthest site
## ("farthest", b2-21: "placed as far away from our spawn spot as possible"). D-254's own
## scaling of the old 125 m (x1.5 = 187.5 m) was ours, not the director's.
const STADIUM_FLOOR := 150.0
## The plans _check_stadium_farthest brute-forces (about a minute each).
const FARTHEST_SEEDS: Array[int] = [7301, 98765]
## How much wider than the river's channel a bridge's water must be (D-254: "at least 3x").
const BRIDGE_WATER := 3.0


func suite_name() -> String:
	return "Spread"


func run_checks() -> void:
	await _t("_check_halves")
	await _t("_check_landmarks")
	await _t("_check_stadium_farthest")
	await _t("_check_hazards")
	await _t("_check_bridge")
	await _t("_check_outer_cores")
	await _t("_check_seeded")
	await _t("_check_effect")


func _seeds() -> Array[int]:
	var out: Array[int] = []
	for n: int in SEEDS:
		out.append(SHIPPED + n * SEED_STEP)
	return out


func _cfg(map_seed: int, tier: int) -> Dictionary:
	var base: Dictionary = Content.tuning().duplicate(true)
	base["city"]["map_seed"] = map_seed
	return CityGrowth.tuning_for(base, tier)["city"]


func _rings() -> Array[float]:
	return CityGen.districts(Content.section("city"))


## Each stage's play area is 1.5x the old one: 75 / 120 / 225 m half-widths.
func _check_halves() -> void:
	var got: Array[float] = []
	for tier: int in [1, 2, 3]:
		got.append(CityGen.half_extent(_cfg(SHIPPED, tier)))
	check(got == HALVES, "the play area's half-widths are %s (got %s)" % [HALVES, got])
	check(_rings() == HALVES, "the districts are the stages' play areas (%s)" % [_rings()])


## Landmarks a stage newly opens keep 0.4 x its width apart; a pair with an inner district's
## landmark keeps 0.4 x the inner stage's width; each keeps 0.2 x its stage's width off the rise,
## and the stadium at least its old distance.
func _check_landmarks() -> void:
	var spread: Dictionary = Content.section("city")["spread"]
	var rings := _rings()
	var bad: Array[String] = []
	var placed := 0
	for map_seed: int in _seeds():
		var plan := CityGen.map(_cfg(map_seed, 1))
		var rise: Vector2 = plan["rise_spawn"]
		var sites: Array = plan["sites"]
		placed += sites.size()
		for a: int in sites.size():
			var site: Dictionary = sites[a]
			var k := Num.i(site["district"])
			var at := _at(site)
			var clear := Num.f(spread["spawn_clear"]) * CitySpread.width(rings, k)
			if at.distance_to(rise) < clear:
				bad.append(
					"%d %s %.0f m from the rise" % [map_seed, site["id"], at.distance_to(rise)]
				)
			if str(site["id"]) == "stadium" and at.distance_to(rise) < STADIUM_FLOOR:
				bad.append("%d stadium %.0f m from the rise" % [map_seed, at.distance_to(rise)])
			for b: int in range(a + 1, sites.size()):
				var other: Dictionary = sites[b]
				var inner := mini(k, Num.i(other["district"]))
				var gap := Num.f(spread["landmark_gap"]) * CitySpread.width(rings, inner)
				if at.distance_to(_at(other)) < gap:
					bad.append(
						(
							"%d %s-%s %.0f m < %.0f"
							% [map_seed, site["id"], other["id"], at.distance_to(_at(other)), gap]
						)
					)
	check(placed >= SEEDS * 2, "most landmarks find a site (%d over %d plans)" % [placed, SEEDS])
	check(bad.is_empty(), "landmarks spread and clear of the rise in every plan: %s" % [bad])


## The red barrels (CityHazards, landed as tuned: "Land it", 2026-10-26) at 1.5x: each stage
## tags its count, every one stands inside the stage's play area and spawn_clear m or more off
## the kaiju's rise. Prints the counts per stage over the plans (for the PR).
func _check_hazards() -> void:
	var h: Dictionary = Content.section("city")["hazards"]
	var bad: Array[String] = []
	for tier: int in [1, 2, 3]:
		var counts: Array[int] = []
		for map_seed: int in _seeds():
			var base: Dictionary = Content.tuning().duplicate(true)
			base["city"]["map_seed"] = map_seed
			var cfg := _cfg(map_seed, tier)
			var half := CityGen.half_extent(cfg)
			var rise: Vector2 = CityGen.map(cfg)["rise_spawn"]
			var n := 0
			for e: Dictionary in CityGrowth.layout(base, tier, Seeds.make("city", 0)):
				if not e.has("hazard"):
					continue
				n += 1
				var at := Vector2(Num.f(e["x"]), Num.f(e["z"]))
				var which := "%d stage %d %s" % [map_seed, tier, e["hazard"]]
				if maxf(absf(at.x), absf(at.y)) > half:
					bad.append("%s at %s outside %.0f" % [which, at, half])
				if at.distance_to(rise) < Num.f(h["spawn_clear"]):
					bad.append("%s %.0f m from the rise" % [which, at.distance_to(rise)])
			counts.append(n)
		var tuned: Array = h["count"]
		var want := Num.i(tuned[mini(tier - 1, tuned.size() - 1)])
		print("  hazards stage %d over %d plans: %s (tuned %d)" % [tier, SEEDS, counts, want])
		if counts.min() < want:
			bad.append("stage %d: as few as %d of %d" % [tier, counts.min(), want])
	check(bad.is_empty(), "every red barrel in play and clear of the rise, full count: %s" % [bad])


## Where a bridge is placed: its water is at least 3x the river's channel wide, starts where the
## river's water ends (joined), lies inside the play area of the stage that opens it, and the
## bridge stands on land past both ends of it.
func _check_bridge() -> void:
	var rings := _rings()
	var bad: Array[String] = []
	var bridges := 0
	for map_seed: int in _seeds():
		var cfg := _cfg(map_seed, 1)
		var plan := CityGen.map(cfg)
		var river: Rect2 = CityRiver.channels(plan, cfg)[0]
		for site: Dictionary in plan["sites"]:
			if not site.has("water"):
				continue
			bridges += 1
			var water: Rect2 = site["water"]
			var k := Num.i(site["district"])
			var shape: Dictionary = site["shape"]
			var at: Vector2 = site["at"]
			var span := Num.f(shape["w"])
			if water.size.x < BRIDGE_WATER * river.size.y:
				bad.append("%d water %.0f m < 3 x %.0f" % [map_seed, water.size.x, river.size.y])
			if absf(water.position.y - river.end.y) > 0.01:
				bad.append("%d inlet not joined to the river" % map_seed)
			if maxf(absf(water.end.y), maxf(absf(water.position.x), absf(water.end.x))) > rings[k]:
				bad.append("%d inlet past stage %d's edge" % [map_seed, k + 1])
			var ends := Vector2(at.x - span * 0.5, at.x + span * 0.5)
			var plaza: Rect2 = site["rect"]
			if ends.x >= water.position.x or ends.y <= water.end.x:
				bad.append("%d bridge does not reach both banks" % map_seed)
			if ends.x < plaza.position.x or ends.y > plaza.end.x:
				bad.append("%d bridge ends off its landings" % map_seed)
	check(
		bridges >= SEEDS / 2,
		"the bridge finds its water in most plans (%d of %d)" % [bridges, SEEDS]
	)
	check(
		bad.is_empty(),
		"every bridge spans a wide inlet off the river, land at both ends: %s" % [bad]
	)


## No skyline stand-in core (city.outer_cores) reaches into any stage's play area.
func _check_outer_cores() -> void:
	var bad: Array[String] = []
	for tier: int in [1, 2, 3]:
		var cfg := _cfg(SHIPPED, tier)
		var half := CityGen.half_extent(cfg)
		for at: Array in cfg["outer_cores"]:
			var c := Vector2(Num.f(at[0]), Num.f(at[1]))
			var gap := Vector2(maxf(absf(c.x) - half, 0.0), maxf(absf(c.y) - half, 0.0)).length()
			if gap < Num.f(at[2]):
				bad.append("stage %d core %s" % [tier, at])
	check(bad.is_empty(), "no skyline core overlaps a play area: %s" % [bad])


## The same seed gives the same sites, and every stage the same ones (D-039: sites never move).
func _check_seeded() -> void:
	var same := true
	for map_seed: int in [SHIPPED, SHIPPED + SEED_STEP]:
		var first := CityGen.map(_cfg(map_seed, 1))
		for tier: int in [1, 2, 3]:
			var again := CityGen.map(_cfg(map_seed, tier))
			same = same and _digest(first) == _digest(again)
	check(same, "a seed's landmark sites are the same every time and every stage")


## Player-effect fixture (CitySpread): the seed moves what the player meets. Across the plans,
## the landmarks stand in more than one district each and their sites differ, so a city
## seed (per save, with the city blocks: D-263) changes where the big targets are.
func _check_effect() -> void:
	var districts := {}
	var layouts := {}
	for map_seed: int in _seeds():
		var plan := CityGen.map(_cfg(map_seed, 3))
		layouts[_digest(plan)] = true
		for site: Dictionary in plan["sites"]:
			districts["%s %d" % [site["id"], site["district"]]] = true
	check(
		layouts.size() == SEEDS and districts.size() > 3,
		(
			(
				"each seed lays its own landmarks (%d layouts of %d), landmarks"
				+ " across districts: %s"
			)
			% [layouts.size(), SEEDS, districts.keys()]
		)
	)


func _digest(plan: Dictionary) -> String:
	var parts: Array[String] = []
	for site: Dictionary in plan["sites"]:
		parts.append("%s%s" % [site["id"], site["rect"]])
	return ",".join(parts)


## b2-21 "placed as far away from our spawn spot as possible" (D-271): of the sites district 1
## offers the stadium, the shipped plan takes the farthest from the rise. Brute force: pin the
## stadium at every district-1 cell (spec "anchor") and rank the sites that keep off the bay,
## the rise floor and the plan's other landmarks.
func _check_stadium_farthest() -> void:
	var spread: Dictionary = Content.section("city")["spread"]
	var rings := _rings()
	for map_seed: int in FARTHEST_SEEDS:
		var cfg := _cfg(map_seed, 1)
		var plan := CityGen.map(cfg)
		var rises := CitySpread.rise_estimates(plan, cfg)
		var xs: Array[float] = plan["xs"]
		var zs: Array[float] = plan["zs"]
		var bay := CityHarbour.reaches(xs, Num.f(plan.get("rail_x", 0.0)), cfg)
		var spec := {}
		for s: Dictionary in cfg["landmarks"]:
			if str(s["id"]) == "stadium":
				spec = s
		var picked := {}
		var others: Array[Dictionary] = []
		for site: Dictionary in plan["sites"]:
			if str(site["id"]) == "stadium":
				picked = site
			else:
				others.append(site)
		var floor_m := (
			maxf(
				Num.f(spread["spawn_clear"]) * CitySpread.width(rings, 1), Num.f(spec["rise_clear"])
			)
			+ Num.f(spread["rise_slack"])
		)
		var best := 0.0
		var tried := 0
		for i: int in xs.size() - 1:
			for j: int in zs.size() - 1:
				var cell := Vector2((xs[i] + xs[i + 1]) * 0.5, (zs[j] + zs[j + 1]) * 0.5)
				var reach := maxf(absf(cell.x), absf(cell.y))
				if reach <= rings[0] or reach >= rings[1]:
					continue
				var pinned_spec: Dictionary = spec.duplicate(true)
				pinned_spec["anchor"] = [cell.x, cell.y]
				var pinned: Dictionary = cfg.duplicate(true)
				pinned["landmarks"] = [pinned_spec]
				var sites: Array = CityGen.map(pinned)["sites"]
				if sites.size() != 1 or Num.i(sites[0]["district"]) != 1:
					continue
				var site: Dictionary = sites[0]
				var far := CitySpread.rise_far(site, rises)
				if far >= floor_m and _keeps_off(site, bay, others):
					tried += 1
					best = maxf(best, far)
		var got := CitySpread.rise_far(picked, rises) if not picked.is_empty() else 0.0
		check(
			tried > 0 and got >= best - 0.01,
			(
				(
					"%d: the stadium stands %.1f m from the nearest rise, the farthest of %d district-1"
					+ " sites (best %.1f)"
				)
				% [map_seed, got, tried, best]
			)
		)


## Whether a candidate stadium site keeps off the bay and clear of the plan's other landmarks.
func _keeps_off(site: Dictionary, bay: Array[Rect2], others: Array[Dictionary]) -> bool:
	var spread: Dictionary = Content.section("city")["spread"]
	var rings := _rings()
	var outer: Rect2 = site["outer"]
	if bay.any(func(b: Rect2) -> bool: return b.intersects(outer)):
		return false
	for other: Dictionary in others:
		var other_outer: Rect2 = other["outer"]
		if outer.grow(-0.01).intersects(other_outer.grow(-0.01)):
			return false
		var ring := mini(Num.i(site["district"]), Num.i(other["district"]))
		var gap := Num.f(spread["landmark_gap"]) * CitySpread.width(rings, ring)
		if _at(site).distance_to(_at(other)) < gap:
			return false
	return true


## A landmark site's centre (its plaza's; CitySpread spaces sites by it).
func _at(site: Dictionary) -> Vector2:
	var rect: Rect2 = site["rect"]
	return rect.get_center()
