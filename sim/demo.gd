class_name Demo
extends RefCounted
## The demo slice (D-050, D-145). data/tuning.json "demo" limits play to its species. Buying the
## final upgrade (every node of the tree owned) shows the thanks screen (rampage totals, a feedback
## link) and unlocks Endless mode (Endless, D-156); normal mode stays replayable. With
## "enabled": false (or no section) the full game plays. Pure: reads Content.


static func enabled() -> bool:
	return _cfg().get("enabled", false) == true


## True when `species_id` is playable (every species is, with the demo off).
static func allows(species_id: String) -> bool:
	if not enabled():
		return true
	var allowed: Array = _cfg().get("species", [])
	return allowed.has(species_id)


## True when a build can continue `save`: its species is playable, and a save that began in a demo
## never continues in the full game (D-145: demo saves do not carry over).
static func continues(save: Dictionary) -> bool:
	if save.is_empty() or not allows(str(save.get("species", ""))):
		return false
	return enabled() or save.get("demo", false) != true


## The species a new game offers, in data order.
static func species() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for def: Dictionary in Content.species():
		if allows(str(def["id"])):
			out.append(def)
	return out


## True when `tree` owns every node (the final upgrade is bought): the demo's end, read from data.
static func complete(tree: UpgradeTree) -> bool:
	return enabled() and tree.levels_owned() >= tree.levels_total()


## `totals` plus one rampage's `result` (RampageSim.result() with the view's people counts).
static func add(totals: Dictionary, result: Dictionary) -> Dictionary:
	var out := totals.duplicate()
	var military := 0
	for key: String in _cfg()["military_keys"]:
		military += Num.i(result.get(key, 0))
	var adds := {
		"biomass": Num.i(result.get("rubble", 0)),
		"buildings": Num.i(result.get("buildings", 0)),
		"eaten": Num.i(result.get("civilians", 0)),
		"fled": Num.i(result.get("fled", 0)),
		"military": military,
		"seconds": Num.i(floor(Num.f(result.get("seconds", 0.0)))),
	}
	for key: String in adds:
		out[key] = Num.i(out.get(key, 0)) + Num.i(adds[key])
	return out


## The thanks screen's rows, label then text, in order (what the screen draws).
static func rows(totals: Dictionary) -> Array[PackedStringArray]:
	var secs := Num.i(totals.get("seconds", 0))
	var out: Array[PackedStringArray] = []
	out.append(PackedStringArray(["Buildings destroyed", str(Num.i(totals.get("buildings", 0)))]))
	out.append(PackedStringArray(["People eaten", str(Num.i(totals.get("eaten", 0)))]))
	out.append(PackedStringArray(["People fled", str(Num.i(totals.get("fled", 0)))]))
	out.append(PackedStringArray(["Military destroyed", str(Num.i(totals.get("military", 0)))]))
	out.append(PackedStringArray(["Time played", "%d:%02d" % [secs / 60, secs % 60]]))
	out.append(PackedStringArray(["Biomass earned", str(Num.i(totals.get("biomass", 0)))]))
	return out


## Where "Leave feedback" goes (D-148): one data string.
static func feedback_url() -> String:
	return str(_cfg()["feedback_url"])


static func _cfg() -> Dictionary:
	return Content.section("demo")
