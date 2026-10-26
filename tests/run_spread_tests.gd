extends "res://tests/lib/runner.gd"
## Play area and spread suite (D-254, director 2026-10-26: "1.5x wider", "space out our
## landmarks ... across the new expanded area"; spacing among the sites a stage newly opens,
## pairs with an inner district's site at the inner stage's share: lead call 2026-10-26). Over
## SEEDS street plans (city.map_seed) and every growth stage: the play-area half-widths, landmark
## spacing and rise clearance, the red barrels (CityHazards, as tuned) all in play and none at
## the rise, the stadium as far from the rise as before (b2-21), the bridge's
## inlet (at least 3x the river's width, joined to the river, the bridge on land at both ends,
## #12), no skyline core over a play area, and the same plan from the same seed.
## Seeded by design: city.map_seed per plan, the shipped tuning.
##   godot --headless --path . --script tests/run_spread_tests.gd

const Play := preload("res://tests/lib/spread_play.gd")

## The plans checked: the shipped one first, then 19 more.
const SEEDS := 20
const SHIPPED := 7301
const SEED_STEP := 977
## The play area's half-widths per stage (D-254).
const HALVES: Array[float] = [75.0, 120.0, 225.0]
## The stadium's distance from the rise before D-254 (125 m: 2.50 / 1.56 / 0.83 x the old
## half-widths); it must stay at least this share of each stage's half-width (b2-21).
const STADIUM_SHARE: Array[float] = [2.5, 1.5625, 0.8333]
## How much wider than the river's channel a bridge's water must be (D-254: "at least 3x").
const BRIDGE_WATER := 3.0


func suite_name() -> String:
	return "Spread"


func run_checks() -> void:
	await _t("_check_halves")
	await _t("_check_landmarks")
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
		var rise: Vector2 = plan["river_spawn"]
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
			if str(site["id"]) == "stadium":
				for s: int in rings.size():
					if at.distance_to(rise) < STADIUM_SHARE[s] * rings[s] - 0.5:
						bad.append(
							"%d stadium %.0f m from the rise" % [map_seed, at.distance_to(rise)]
						)
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
			var rise: Vector2 = CityGen.map(cfg)["river_spawn"]
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


## A landmark site's centre (its plaza's; CitySpread spaces sites by it).
func _at(site: Dictionary) -> Vector2:
	var rect: Rect2 = site["rect"]
	return rect.get_center()
