class_name UpgradeTree
extends RefCounted
## The upgrade tree: definitions (data/upgrades.json), the levels bought, and the stats they
## produce on top of a species. Pure: no nodes, no files. A definition with a "species" key
## belongs to that species' own branch and is left out of every other species' tree.
## Rings (tuning "tree", ROADMAP E): a species listed there grows its tree outward in rings, each
## node a kind (stat, verb, stage); only the open rings can be bought, the next one shows as
## shapes, the rest stay hidden (R 1.4, R 16.3). A species not listed keeps the whole tree open.
## Conquest bonuses (D-421, plan row F4) ride the same path: the picks a save holds scale the
## stats after the upgrades, so combat reads them as it reads any upgrade.

## How much of a node the tree screen may show (R 16.3).
enum Reveal { HIDDEN, SHAPE, FULL }

var defs: Dictionary = {}
var order: Array[String] = []
var levels: Dictionary = {}
## Every price x this (data/species.json cost_mult of the kaiju's species, D-167 pacing bar);
## 1 for "".
var cost_mult := 1.0
## The species' rings from the centre out (tuning "tree" "species"): each {"stage", "target"}.
## Empty: no rings, every node open.
var rings: Array = []
## The conquest bonus ids picked (the save's "bonuses" values, Content.bonus).
var bonuses: Array[String] = []
var _tiers: Dictionary = {}

## species_id "" keeps every branch (data checks); a game passes its kaiju's species, and its
## save's "bonuses" (continent id -> bonus id picked) as picked.


func _init(
	definitions: Array[Dictionary],
	saved_levels: Dictionary = {},
	species_id: String = "",
	picked: Dictionary = {}
) -> void:
	for continent: String in picked:
		bonuses.append(str(picked[continent]))
	for def: Dictionary in definitions:
		var owner := str(def.get("species", ""))
		if species_id != "" and owner != "" and owner != species_id:
			continue
		var id: String = def["id"]
		defs[id] = def
		order.append(id)
	if species_id != "":
		cost_mult = Num.f(Content.species_def(species_id).get("cost_mult", 1.0))
		var ringed: Dictionary = Content.section("tree").get("species", {})
		var own: Dictionary = ringed.get(species_id, {})
		rings = own.get("rings", [])
	# Old saves keep every level they bought: ids never change and levels are only clamped
	# to today's max (a save owning a node in a ring not yet open still owns it).
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


## Every prerequisite owned at level 1 or more, in an open ring.
func is_unlocked(id: String) -> bool:
	if not ring_open(ring(id)):
		return false
	var def: Dictionary = defs[id]
	var requires: Array = def.get("requires", [])
	for req: String in requires:
		if level(req) < 1:
			return false
	return true


## The node's ring, 1 at the centre (1 when the species has no rings).
func ring(id: String) -> int:
	var def: Dictionary = defs[id]
	return Num.i(def.get("ring", 1))


## "stat", "verb" or "stage"; a node without a kind is a stage if it grows the kaiju, else a stat.
func kind(id: String) -> String:
	var def: Dictionary = defs[id]
	if def.has("kind"):
		return str(def["kind"])
	var effects: Dictionary = def.get("effects", {})
	return "stage" if effects.has("size") else "stat"


## The growth stage the kaiju has reached: 1 plus the evolutions owned.
func stage() -> int:
	var out := 1
	for id: String in order:
		if kind(id) == "stage":
			out += level(id)
	return out


## A ring can be bought from once the kaiju has reached its stage and owns a node of the ring
## before it (ring 1 always). Every ring is open when the species has no rings.
func ring_open(r: int) -> bool:
	if rings.is_empty() or r <= 1:
		return true
	if r > rings.size():
		return false
	var ring_def: Dictionary = rings[r - 1]
	if stage() < Num.i(ring_def["stage"]):
		return false
	for id: String in order:
		if ring(id) == r - 1 and level(id) > 0:
			return true
	return false


## What the tree screen shows of a node: in full when its ring is open or it is owned; as a
## shape in the next ring out, and an evolution always (the landmark ahead); else nothing.
func reveal(id: String) -> Reveal:
	var r := ring(id)
	if level(id) > 0 or ring_open(r):
		return Reveal.FULL
	if kind(id) == "stage" or ring_open(r - 1):
		return Reveal.SHAPE
	return Reveal.HIDDEN


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


## Base stats with every bought level's effects added, then each picked bonus's scale: a stat
## grows by the fractions on it, summed (two +10% picks are +20%, not +21%).
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
	var fractions: Dictionary = {}
	for id: String in bonuses:
		var pick := Content.bonus(id)
		var scale: Dictionary = pick.get("scale", {})
		for stat: String in scale:
			fractions[stat] = Num.f(fractions.get(stat, 0.0)) + Num.f(scale[stat])
	for stat: String in fractions:
		out[stat] = Num.f(out.get(stat, 0.0)) * (1.0 + Num.f(fractions[stat]))
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
