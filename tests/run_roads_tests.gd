extends "res://tests/lib/runner.gd"
## Roads suite (director 2026-10-26: "we need a system to ensure that roads are intersecting with
## other roads and pavements in a natural, realistic way"; "I also saw some weird spots where two
## roads met, like a seam between them rather than a seamless join"). Over every road the stage
## draws as the real city (CityBand) at each city stage (young, Behemoth, Colossus) in 20 cities
## (city.map_seed), one test function per rule, each check naming every violation's kind and
## world coordinates (x, z in metres): tests/lib/road_net.gd (R1-R3 on the road graph) and
## tests/lib/road_edges.gd (R3-R6 along every road edge and centre line, read off the ground as
## CityGround draws it, tests/lib/road_ground.gd).
##   R1 every road end meets a road, a junction, a bridge deck or the plan's edge
##   R2 a bridge deck lands on a road of its width and axis at both ends (#12)
##   R3 clean T or X junctions with matching widths, no jagged step in the asphalt edge
##   R4 a kerbed pavement lines both sides of every road (bridges and quays excepted)
##   R5 lane paint stops at junction edges; zebras only at the central junction (D-054)
##   R6 two road pieces that meet make one surface (no height step); its look across a seam is
##      measured at the game camera by tools/capture/capture_road_seams.gd
##   R7 every road wide enough for two lanes has its centre line and a stop line at each junction
##   R8 the beachfront's roads carry their lines too (director 2026-10-31: the beach road and the
##      side streets had none): the beach road's centre line along its whole curve, each side
##      street's dashes and a stop line at both ends
## Seeded by design: the street plan is fixed by city.map_seed; the 20 seeds are listed here.
##   godot --headless --path . --script tests/run_roads_tests.gd

const RoadGround := preload("res://tests/lib/road_ground.gd")
const Net := preload("res://tests/lib/road_net.gd")
const Edges := preload("res://tests/lib/road_edges.gd")
const STAGES: Array[int] = [1, 2, 3]
## 20 cities: the three the city suite pins, then 17 more.
const SEEDS: Array[int] = [
	7301,
	1234,
	98765,
	11,
	42,
	77,
	123,
	256,
	404,
	512,
	777,
	1001,
	2024,
	3141,
	4242,
	5150,
	6502,
	8086,
	9999,
	31337
]
## The bridge into a park the director saw was at x=-3 (stage 1, seed 7301); since the road
## geometry fix (D-265) moved the street lines, the fixture plants it at the deck nearest x=0.
const PARK_DECK_X := 0.0
const SHOWN := 4  # violations quoted in a failure message (the count is always given)

var _cities: Array[Dictionary] = []  # {tier, seed, ground, paint}


func suite_name() -> String:
	return "Roads"


func run_checks() -> void:
	_build()
	await _t("_check_r1_road_ends")
	await _t("_check_r2_bridges_land_on_roads")
	await _t("_check_r2_names_a_bridge_into_a_park")
	await _t("_check_r3_clean_junctions")
	await _t("_check_r4_kerbed_pavement")
	await _t("_check_r5_paint_stops_at_junctions")
	await _t("_check_r6_one_surface")
	await _t("_check_r7_road_paint_everywhere")
	await _t("_check_r8_beachfront_paint")


func _build() -> void:
	for tier: int in STAGES:
		for map_seed: int in SEEDS:
			var cfg := _cfg(tier, map_seed)
			var drawn := CityGround.new(cfg)
			drawn._markings()
			var paint: Array[Transform3D] = drawn._paint.duplicate()
			var city := {"tier": tier, "seed": map_seed, "paint": paint}
			city["ground"] = RoadGround.new(drawn.plan, cfg)
			_cities.append(city)
			drawn.free()


## The city config of a stage (1-3) and map seed.
static func _cfg(tier: int, map_seed: int) -> Dictionary:
	var base: Dictionary = Content.tuning().duplicate(true)
	var city: Dictionary = base["city"]
	city["map_seed"] = map_seed
	return CityGrowth.tuning_for(base, tier)["city"]


## One check per stage and city: `found` takes its ground and paint and returns its violations.
func _each(rule: String, found: Callable) -> void:
	for city: Dictionary in _cities:
		var ground: RoadGround = city["ground"]
		var paint: Array[Transform3D] = city["paint"]
		var bad: Array[String] = found.call(ground, paint)
		check(
			bad.is_empty(),
			(
				"stage %d, map_seed %d: %s (%d violations: %s)"
				% [city["tier"], city["seed"], rule, bad.size(), "; ".join(bad.slice(0, SHOWN))]
			)
		)


func _check_r1_road_ends() -> void:
	_each(
		"R1 every road end meets a road, a junction, a deck or the edge",
		func(g: RoadGround, _paint: Array[Transform3D]) -> Array[String]: return Net.r1_dead_ends(g)
	)


func _check_r2_bridges_land_on_roads() -> void:
	_each(
		"R2 every deck lands on a road of its width and axis; no road crosses water off a deck",
		func(g: RoadGround, _paint: Array[Transform3D]) -> Array[String]: return Net.r2_bridges(g)
	)


## Known-bad fixture: the spot the director saw (stage 1, seed 7301, the deck nearest the middle)
## with a park laid over the landing at its low-z end; R2 must name it a bridge into a park.
func _check_r2_names_a_bridge_into_a_park() -> void:
	var cfg := _cfg(1, 7301)
	var plan := CityGen.map(cfg)
	var deck := Rect2()
	for d: Rect2 in CityRiver.bridges(plan, cfg):
		var off := absf(d.get_center().x - PARK_DECK_X)
		if not deck.has_area() or off < absf(deck.get_center().x - PARK_DECK_X):
			deck = d
	check(deck.has_area(), "stage 1, seed 7301 has a bridge deck (nearest x=%.0f)" % PARK_DECK_X)
	var park := Rect2(deck.position.x - 4.0, deck.position.y - 10.0, deck.size.x + 8.0, 10.0)
	var blocks: Array = plan["blocks"]
	blocks.append({"rect": park, "use": "park"})
	var bad := Net.r2_bridges(RoadGround.new(plan, cfg))
	var named := bad.filter(func(m: String) -> bool: return m.begins_with("R2 bridge into a park"))
	check(
		not named.is_empty(), "R2 names the planted bridge into a park (got: %s)" % "; ".join(bad)
	)


func _check_r3_clean_junctions() -> void:
	_each(
		"R3 clean T or X junctions, matching widths, no jagged asphalt edge",
		func(g: RoadGround, _paint: Array[Transform3D]) -> Array[String]:
			var out := Net.r3_junctions(g)
			out.append_array(Edges.r3_edges(g))
			return out
	)


func _check_r4_kerbed_pavement() -> void:
	_each(
		"R4 a kerbed pavement lines both sides of every road",
		func(g: RoadGround, _paint: Array[Transform3D]) -> Array[String]: return Edges.r4_kerbs(g)
	)


func _check_r5_paint_stops_at_junctions() -> void:
	_each(
		"R5 lane paint stops at junction edges, zebras only at the central junction",
		func(g: RoadGround, paint: Array[Transform3D]) -> Array[String]:
			return Edges.r5_paint(g, paint)
	)


func _check_r6_one_surface() -> void:
	_each(
		"R6 road pieces that meet make one surface",
		func(g: RoadGround, _paint: Array[Transform3D]) -> Array[String]: return Edges.r6_seams(g)
	)


func _check_r7_road_paint_everywhere() -> void:
	_each(
		"R7 every two-lane road has its centre line and a stop line at each junction",
		func(g: RoadGround, paint: Array[Transform3D]) -> Array[String]:
			return Edges.r7_markings(g, paint)
	)


func _check_r8_beachfront_paint() -> void:
	_each(
		"R8 the beach road and every side street carry their lines",
		func(g: RoadGround, paint: Array[Transform3D]) -> Array[String]:
			return _beachfront(g.plan, paint)
	)


## R8: every metre of the beach road has its centre line over it (a stripe within half the double
## gap plus a line of the road's centre); every side street has dashes down its middle and a
## stripe square across it near each end (its stop lines).
static func _beachfront(plan: Dictionary, paint: Array[Transform3D]) -> Array[String]:
	var out: Array[String] = []
	if not plan.has("harbour"):
		return out
	var b: Dictionary = plan["harbour"]
	var h: Dictionary = b["h"]
	var rect: Rect2 = b["rect"]
	var bare := 0
	var x := rect.position.x + 0.5
	while x < rect.end.x:
		var at := CityHarbour.bands(h, x)
		var mid := (at[2] + at[3]) * 0.5
		var hit := paint.any(
			func(t: Transform3D) -> bool:
				return absf(t.origin.x - x) <= 0.6 and absf(t.origin.z - mid) <= 0.3
		)
		if not hit:
			bare += 1
			if bare <= SHOWN:
				out.append("beach road bare at (%.0f, %.0f)" % [x, mid])
		x += 1.0
	var sides: Array[float] = b["sides"]
	for sx: float in sides:
		var kerb := CityHarbour.bands(h, sx)[3]
		var dashes := paint.filter(
			func(t: Transform3D) -> bool:
				return (
					absf(t.origin.x - sx) < 0.01
					and t.origin.z > kerb
					and t.origin.z < rect.end.y
				)
		)
		var stops := paint.filter(
			func(t: Transform3D) -> bool:
				return (
					absf(t.origin.x - sx) < 3.0
					and t.origin.z > kerb - 0.1
					and absf(t.basis.z.normalized().z) < 0.01
				)
		)
		if dashes.is_empty():
			out.append("side street at x %.0f has no centre line" % sx)
		if stops.size() < 2:
			out.append("side street at x %.0f has %d stop lines, not 2" % [sx, stops.size()])
	return out
