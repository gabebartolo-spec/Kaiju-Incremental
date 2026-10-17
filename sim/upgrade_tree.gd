class_name UpgradeTree
extends RefCounted
## The upgrade tree: definitions (data/upgrades.json), the levels bought, and the stats they
## produce on top of a species. Pure: no nodes, no files. A definition with a "species" key
## belongs to that species' own branch and is left out of every other species' tree.

var defs: Dictionary = {}
var order: Array[String] = []
var levels: Dictionary = {}


## species_id "" keeps every branch (data checks); a game passes its kaiju's species.
func _init(
	definitions: Array[Dictionary], saved_levels: Dictionary = {}, species_id: String = ""
) -> void:
	for def: Dictionary in definitions:
		var owner := str(def.get("species", ""))
		if species_id != "" and owner != "" and owner != species_id:
			continue
		var id: String = def["id"]
		defs[id] = def
		order.append(id)
	for id: String in saved_levels:
		if defs.has(id):
			levels[id] = clampi(Num.i(saved_levels[id]), 0, max_level(id))


func level(id: String) -> int:
	return Num.i(levels.get(id, 0))


func max_level(id: String) -> int:
	var def: Dictionary = defs[id]
	return Num.i(def.get("max_level", 1))


func is_maxed(id: String) -> bool:
	return level(id) >= max_level(id)


## Rubble for the next level, or -1 when maxed.
func cost(id: String) -> int:
	var def: Dictionary = defs[id]
	var costs: Array = def["cost"]
	var next := level(id)
	if next >= costs.size() or is_maxed(id):
		return -1
	return Num.i(costs[next])


## Every prerequisite owned at level 1 or more.
func is_unlocked(id: String) -> bool:
	var def: Dictionary = defs[id]
	var requires: Array = def.get("requires", [])
	for req: String in requires:
		if level(req) < 1:
			return false
	return true


func can_buy(id: String, rubble: int) -> bool:
	return is_unlocked(id) and not is_maxed(id) and cost(id) <= rubble


## Buys one level and returns what it cost (0 if it could not be bought).
func buy(id: String, rubble: int) -> int:
	if not can_buy(id, rubble):
		return 0
	var price := cost(id)
	levels[id] = level(id) + 1
	return price


func levels_owned() -> int:
	var total := 0
	for id: String in order:
		total += level(id)
	return total


func levels_total() -> int:
	var total := 0
	for id: String in order:
		total += max_level(id)
	return total


## Base stats with every bought level's effects added.
func apply(base: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate()
	for id: String in order:
		var owned := level(id)
		if owned == 0:
			continue
		var def: Dictionary = defs[id]
		var effects: Dictionary = def.get("effects", {})
		for stat: String in effects:
			out[stat] = Num.f(out.get(stat, 0.0)) + Num.f(effects[stat]) * owned
	return out


## The size tier a node belongs to: 1 plus the evolutions (nodes with a "size" effect) in its
## prerequisite chain. The evolution node itself belongs to the tier it is bought in.
func tier_of(id: String) -> int:
	if _tiers.has(id):
		return Num.i(_tiers[id])
	var def: Dictionary = defs[id]
	var tier := 1
	var requires: Array = def.get("requires", [])
	for req: String in requires:
		if not defs.has(req):
			continue
		var req_def: Dictionary = defs[req]
		var effects: Dictionary = req_def.get("effects", {})
		tier = maxi(tier, tier_of(req) + (1 if effects.has("size") else 0))
	_tiers[id] = tier
	return tier


## Levels bought on this tier's own nodes: the growth the army has seen since the last
## evolution. Resets to 0 the moment the kaiju evolves.
func levels_owned_at_tier(tier: int) -> int:
	var total := 0
	for id: String in order:
		if tier_of(id) == tier:
			total += level(id)
	return total


var _tiers: Dictionary = {}


## Stats for a run: the shared base, the species' own values over it, then upgrades.
## "growth" = every level owned (body scale); "stage_growth" = levels owned on the current
## tier's nodes (the army's in-stage escalation, CityGrowth.for_stats).
static func run_stats(base: Dictionary, species: Dictionary, tree: UpgradeTree) -> Dictionary:
	var stats: Dictionary = base.duplicate()
	var own: Dictionary = species.get("stats", {})
	for stat: String in own:
		stats[stat] = Num.f(own[stat])
	var out := tree.apply(stats)
	out["growth"] = float(tree.levels_owned())
	out["stage_growth"] = float(tree.levels_owned_at_tier(Num.i(out.get("size", 1))))
	return out
