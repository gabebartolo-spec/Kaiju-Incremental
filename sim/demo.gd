class_name Demo
extends RefCounted
## The demo slice (D-050). data/tuning.json "demo" limits play to its species and ends the game on
## its end node (an evolution): after that node's reveal, and on every Continue after it, the demo
## end card shows. With "enabled": false (or no section) the full game plays. Pure: reads Content.


static func enabled() -> bool:
	return _cfg().get("enabled", false) == true


## True when `species_id` is playable (every species is, with the demo off).
static func allows(species_id: String) -> bool:
	if not enabled():
		return true
	var allowed: Array = _cfg().get("species", [])
	return allowed.has(species_id)


## The species a new game offers, in data order.
static func species() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for def: Dictionary in Content.species():
		if allows(str(def["id"])):
			out.append(def)
	return out


## True when buying `upgrade_id` ends the demo.
static func is_end(upgrade_id: String) -> bool:
	return enabled() and str(_cfg().get("end_node", "")) == upgrade_id


## True when a save with these upgrade levels has played the demo to its end.
static func complete(levels: Dictionary) -> bool:
	return enabled() and Num.i(levels.get(str(_cfg().get("end_node", "")), 0)) >= 1


static func _cfg() -> Dictionary:
	return Content.section("demo")
