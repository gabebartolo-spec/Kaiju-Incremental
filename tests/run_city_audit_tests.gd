extends "res://tests/lib/runner.gd"
## City audits suite (D-265, director 2026-10-26: "audit that the road layouts are natural and
## realistic in all seeds"; "audit that seeds are actually meaningfully different from one
## another"; "audit that all assets appear often, none never appearing"). Runs the tools in
## tools/audit/ on a few seeds per stage; tools/audit/run_city_audit.gd runs them at full size
## (50 road seeds, 20 run indices, 20 asset seeds) and writes the report tables.
## Each tool is shown catching a planted defect (a dangling road stub, two identical cities, an
## asset that can never be placed). Only bars that hold on main are asserted here; a bar main
## fails today is reported by the full run and joins this suite with the PR that meets it
## (the >= 50% lots-differ bar comes with the city blocks, D-261).
## Seeded by design: map seeds from tools/audit/road_audit.gd seeds(), run indices 0..N-1.
##   godot --headless --path . --script tests/run_city_audit_tests.gd

const Roads := preload("res://tools/audit/road_audit.gd")
const Graph := preload("res://tools/audit/road_graph_audit.gd")
const Ground := preload("res://tools/audit/road_ground_audit.gd")
const SeedAudit := preload("res://tools/audit/seed_audit.gd")
const AssetAudit := preload("res://tools/audit/asset_audit.gd")
const STAGES: Array[int] = [1, 2, 3]
const ROAD_SEEDS := 6
const ASSET_SEEDS := 8
## Road rules that hold at every stage and seed of the full run (2026-10-26; road geometry
## brought arms, water, thin blocks and overlapping junction boxes, "close!", to zero; short
## blocks, "close", and aspect still fail there; tools/audit/run_city_audit.gd reports them).
const ROAD_RULES_HELD: Array[String] = [
	"stub", "zero", "split", "angle", "kerb", "arms", "water", "thin", "close!"
]
const STUB_M := 4.0  # the planted dead end: shorter than any block


func suite_name() -> String:
	return "City audit"


func run_checks() -> void:
	await _t("_check_planted_stub")
	await _t("_check_planted_bare_kerb")
	await _t("_check_planted_twin_cities")
	await _t("_check_planted_zero_weight_asset")
	await _t("_check_same_index_same_city")
	await _t("_check_road_rules_held")
	await _t("_check_diagonal_fits")
	await _t("_check_layout_assets_held")


## A street stub hung off a crossing of the shipped plan is caught as a "stub" right there.
func _check_planted_stub() -> void:
	var cfg := Roads.city(Content.tuning(), 1, Roads.SHIPPED_SEED)
	var plan := CityGen.map(cfg)
	var nodes: Array[Vector2] = plan["nodes"]
	var from := _central_node(plan)
	var tip := nodes[from] + Vector2(STUB_M * 0.6, STUB_M * 0.8)
	nodes.append(tip)
	var streets: Array[Dictionary] = plan["streets"]
	streets.append({"from": from, "to": nodes.size() - 1, "width": 4.0, "kind": CityGen.STREET})
	var found := false
	for v: Dictionary in Graph.audit(plan, cfg)["violations"]:
		var at: Vector2 = v["at"]
		found = found or (v["rule"] == "stub" and at.distance_to(tip) < 0.01)
	check(found, "a %.0f m dead end planted at %s is reported as a stub" % [STUB_M, tip])


## A built block taken out of the shipped plan leaves the streets round it with no pavement: the
## kerb rule names a spot beside it (and none there with the block in).
func _check_planted_bare_kerb() -> void:
	var cfg := Roads.city(Content.tuning(), 1, Roads.SHIPPED_SEED)
	var plan := CityGen.map(cfg)
	var blocks: Array[Dictionary] = plan["blocks"]
	var pick := -1
	for n: int in blocks.size():
		var rect: Rect2 = blocks[n]["rect"]
		if str(blocks[n]["use"]) == "built" and rect.get_center().length() < 30.0:
			pick = n
			break
	var around := CityGen.pavement(blocks[pick], cfg).grow(Num.f(cfg["avenue_width"]))
	var before := _kerbs_in(Ground.audit(plan, cfg), around)
	blocks.remove_at(pick)
	var after := _kerbs_in(Ground.audit(plan, cfg), around)
	check(
		before == 0 and after > 0,
		"a block taken out leaves bare kerbs beside it (%d before, %d after)" % [before, after]
	)


func _kerbs_in(violations: Array[Dictionary], area: Rect2) -> int:
	var n := 0
	for v: Dictionary in violations:
		var at: Vector2 = v["at"]
		if v["rule"] == "kerb" and area.has_point(at):
			n += 1
	return n


func _central_node(plan: Dictionary) -> int:
	var nodes: Array[Vector2] = plan["nodes"]
	var best := 0
	for n: int in nodes.size():
		if nodes[n].length() < nodes[best].length():
			best = n
	return best


## Two runs that build the same city differ on 0% of lots (the tool sees no difference, so the
## >= 50% bar would fail them); two seeded cities differ.
func _check_planted_twin_cities() -> void:
	var base := Content.tuning()
	var a := SeedAudit.city(base, 1, 0, "seeded")
	var twin := SeedAudit.city(base, 1, 0, "seeded")
	var other := SeedAudit.city(base, 1, 1, "seeded")
	var same := SeedAudit.compare(a, twin)
	var apart := SeedAudit.compare(a, other)
	check(
		Num.f(same["lots"]) == 0.0 and Num.f(same["roads"]) == 0.0,
		"twin cities differ on 0%% of lots and roads (got %s)" % same
	)
	check(
		Num.f(apart["lots"]) > 0.0 and Num.f(apart["roads"]) > 0.0,
		"two seeded cities differ on some lots and roads (got %s)" % apart
	)


## A pool model too big for any lot is in the inventory, never placed, and named short of the
## bar with its reason.
func _check_planted_zero_weight_asset() -> void:
	var base: Dictionary = Content.tuning().duplicate(true)
	var city: Dictionary = base["city"]
	var book: Dictionary = city.get("building_pool", {})
	var pool: Dictionary = book.get("pool", {})
	pool["planted_giant"] = {"role": "filler", "w": 999, "d": 999}
	book["pool"] = pool
	city["building_pool"] = book
	var result: Dictionary = await AssetAudit.stage(root, base, 1, {"count": 2})
	var short := AssetAudit.short_of_bar(result, 2, false)
	var named := ""
	for s: Dictionary in short:
		if s["id"] == "pool:planted_giant":
			named = str(s["why"])
	check(
		named.contains("never fits"), "the planted 999x999 model is short, never fits: %s" % named
	)


## The same run index twice builds a byte-identical city (layout and street plan), both through
## the game's own seeding (CitySeed) and with every stream seeded.
func _check_same_index_same_city() -> void:
	var base := Content.tuning()
	for tier: int in STAGES:
		for mode: String in ["game", "seeded"]:
			var one := SeedAudit.layout_hash(SeedAudit.city(base, tier, 3, mode))
			var two := SeedAudit.layout_hash(SeedAudit.city(base, tier, 3, mode))
			check(one == two, "stage %d, %s run 3 twice: the same layout hash" % [tier, mode])


## The road rules main meets in every city of the full run still hold on a few seeds per stage.
func _check_road_rules_held() -> void:
	var base := Content.tuning()
	for tier: int in STAGES:
		for map_seed: int in Roads.seeds(ROAD_SEEDS):
			var got := Roads.run(Roads.city(base, tier, map_seed))
			var bad: Array[Dictionary] = []
			for v: Dictionary in got["violations"]:
				var rule := str(v["rule"])
				if rule == "close" and str(v["note"]).contains("overlap"):
					rule = "close!"  # junction boxes overlap (Roads.by_rule)
				if rule in ROAD_RULES_HELD:
					bad.append(v)
			check(
				bad.is_empty(),
				(
					"stage %d, map seed %d: no %s (%s)"
					% [tier, map_seed, "/".join(ROAD_RULES_HELD), bad.slice(0, 4)]
				)
			)


## The shipped diagonal fits its rings (CityLineFit.x_runs_fit; tools/audit/diagonal_fit.gd
## re-picks it when they change), and the pre-fix one (through (-6, 4) at 27 deg, which crossed
## the grid 2.2 m from the ring corner (80, 50)) is caught as not fitting.
func _check_diagonal_fits() -> void:
	var cfg := Roads.city(Content.tuning(), 1, Roads.SHIPPED_SEED)
	check(
		CityLineFit.x_runs_fit(cfg, CityGen.diagonal_of(cfg)),
		(
			"the shipped diagonal %s at %s deg fits the rings %s (else run tools/audit/diagonal_fit.gd)"
			% [cfg["diagonal_through"], cfg["diagonal_deg"], cfg["districts"]]
		)
	)
	var old := cfg.duplicate()
	old["diagonal_through"] = [-6, 4]
	old["diagonal_deg"] = 27
	check(
		not CityLineFit.x_runs_fit(old, CityGen.diagonal_of(old)),
		"the pre-fix diagonal (-6, 4) at 27 deg is caught as not fitting"
	)


## Every layout asset (archetypes, facades, landmarks, signs) meets the bar on a few seeds.
func _check_layout_assets_held() -> void:
	for tier: int in STAGES:
		var opts := {"count": ASSET_SEEDS}
		var result: Dictionary = await AssetAudit.stage(root, Content.tuning(), tier, opts)
		var short := AssetAudit.short_of_bar(result, ASSET_SEEDS, false)
		check(short.is_empty(), "stage %d: every layout asset meets its bar (%s)" % [tier, short])


## Every landmark's plaza stays clear of every street (tools/audit/landmark_clear_audit.gd; on
## main before the road geometry fix 7 of 20 stage-1 cities had a plaza over an avenue's stub
## end), 20 map seeds x 3 stages; and a plaza planted across the middle avenue is caught.
func _check_landmarks_clear() -> void:
	var base := Content.tuning()
	for tier: int in STAGES:
		var bad: Array[String] = []
		for map_seed: int in Roads.seeds(LANDMARK_SEEDS):
			for v: String in LandmarkClear.violations(Roads.city(base, tier, map_seed)):
				bad.append("seed %d: %s" % [map_seed, v])
		check(
			bad.is_empty(),
			(
				"stage %d: every landmark plaza clear of the streets (%d: %s)"
				% [tier, bad.size(), bad.slice(0, 3)]
			)
		)
	var city := Roads.city(base, 3, Roads.SHIPPED_SEED)
	var plan := CityGen.map(city)
	var x := Rail.avenue_x(city)  # the north-south avenue nearest the middle
	plan["sites"] = [{"id": "planted", "rect": Rect2(x - 6.0, -20.0, 12.0, 8.0)}]
	var got := LandmarkClear.of_plan(plan)
	check(
		got.any(func(v: String) -> bool: return v.contains("on the avenue")),
		"a plaza planted across the middle avenue is caught (%s)" % [got.slice(0, 2)]
	)
