extends RefCounted
## ROADS audit (D-265): every rule of tools/audit/road_graph_audit.gd (stubs, arms, close
## junctions, zero or overlapping pieces, one connected network, junction angles, block shapes)
## and tools/audit/road_ground_audit.gd (no road over open water off a bridge, a kerbed pavement
## on every road edge) over one stage's street plan at one map seed. The seed goes into the
## city config (city.map_seed) even though the game plays one plan per stage today (D-261).

const Graph := preload("res://tools/audit/road_graph_audit.gd")
const Ground := preload("res://tools/audit/road_ground_audit.gd")
const SHIPPED_SEED := 7301  # city.map_seed in data/tuning.json, the plan the game plays today
const SEED_SALT := "city_audit_map"


## `count` map seeds: the shipped one first, then seeded draws (the same list every run).
static func seeds(count: int) -> Array[int]:
	var out: Array[int] = [SHIPPED_SEED]
	var k := 1
	while out.size() < count:
		var s := Seeds.make(SEED_SALT, k).randi_range(1, 99999)
		if not s in out:
			out.append(s)
		k += 1
	return out


## The stage's city config with this map seed (the tuning's own otherwise).
static func city(base: Dictionary, tier: int, map_seed: int) -> Dictionary:
	var tuning: Dictionary = base.duplicate(true)
	tuning["city"]["map_seed"] = map_seed
	return CityGrowth.tuning_for(tuning, tier)["city"]


## {plan, violations, metrics} for one stage's plan under config `cfg`.
static func run(cfg: Dictionary) -> Dictionary:
	var plan := CityGen.map(cfg)
	var found := Graph.audit(plan, cfg)
	var violations: Array[Dictionary] = found["violations"]
	violations.append_array(Ground.audit(plan, cfg))
	return {"plan": plan, "violations": violations, "metrics": found["metrics"]}


## Violations counted by rule ("close!": close junctions whose boxes overlap).
static func by_rule(violations: Array) -> Dictionary:
	var out := {}
	for v: Dictionary in violations:
		var rule := str(v["rule"])
		if rule == "close" and str(v["note"]).contains("overlap"):
			rule = "close!"  # junction boxes overlap: worse than a short block
		out[rule] = Num.i(out.get(rule, 0)) + 1
	return out
