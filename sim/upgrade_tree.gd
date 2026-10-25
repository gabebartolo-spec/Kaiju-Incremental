class_name UpgradeTree
extends RefCounted
## The upgrade tree: definitions (data/upgrades.json), the levels bought, and the stats they
## produce on top of a species. Pure: no nodes, no files. A definition with a "species" key
## belongs to that species' own branch and is left out of every other species' tree.

var defs: Dictionary = {}
var order: Array[String] = []
var levels: Dictionary = {}
var _tiers: Dictionary = {}
## Every price x this (data/species.json cost_mult of the kaiju's species, D-167 pacing bar); 1 for "".
var cost_mult := 1.0

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
	if species_id != "":
		cost_mult = Num.f(Content.species_def(species_id).get("cost_mult", 1.0))
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
	return roundi(Num.f(costs[next]) * cost_mult)


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
func apply(base: Dictionary, species_id: String = "") -> Dictionary:
	var out: Dictionary = base.duplicate()
	for id: String in order:
		var owned := level(id)
		if owned == 0:
			continue
		var def: Dictionary = defs[id]
		var effects := effects_for(def, species_id)
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


## Stats for a run: the shared base, the species' own values over it, then upgrades.
## "growth" = every level owned (body scale); "stage_growth" = levels owned on the current
## tier's nodes (the army's in-stage escalation, CityGrowth.for_stats).
static func run_stats(base: Dictionary, species: Dictionary, tree: UpgradeTree) -> Dictionary:
	var stats: Dictionary = base.duplicate()
	var own: Dictionary = species.get("stats", {})
	for stat: String in own:
		stats[stat] = Num.f(own[stat])
	var out := tree.apply(stats, str(species.get("id", "")))
	out["growth"] = float(tree.levels_owned())
	out["stage_growth"] = float(tree.levels_owned_at_tier(Num.i(out.get("size", 1))))
	return out


## An upgrade's effects for a species: its "species_effects" entry when it has one (Claws rakes
## for the reptilian and stomps harder for the others, D-095), else its "effects".
static func effects_for(def: Dictionary, species_id: String) -> Dictionary:
	var own: Dictionary = def.get("species_effects", {})
	var effects: Dictionary = own.get(species_id, def.get("effects", {}))
	return effects


## An upgrade's description for a species: its "species_desc" entry when it has one, else "desc".
static func desc_for(def: Dictionary, species_id: String) -> String:
	var own: Dictionary = def.get("species_desc", {})
	return str(own.get(species_id, def.get("desc", "")))
