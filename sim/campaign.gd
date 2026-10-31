class_name Campaign
extends RefCounted
## The campaign's state on the globe (Overworld plan row G3; the rest of plan row T1, Threat and
## noise, lands here later). Pure: reads the continent rows (Content.continents()) and a save's
## conquered list, no Node.
##   - conquered: in the save's conquered list;
##   - available: Ostia Minor alone until it falls; then the two lowest unconquered continents in
##     the fixed sequence (D-420); the capital once every other continent has fallen (D-422);
##   - locked: everything else.

enum State { LOCKED, AVAILABLE, CONQUERED }

## Continents the globe offers at once after the first (D-420).
const OFFERED := 2
## D-422: Threat stays at or under THREAT_CAP until the last conquest before the capital sets it
## to THREAT_FULL and opens Aurelia.
const THREAT_CAP := 99.0
const THREAT_FULL := 100.0


## The save after a won mission (plan row G5): the continent joins conquered, the one bonus the
## player kept of its three is stored under its id (D-421), and Threat rises by its share, capped
## at THREAT_CAP, until the last conquest before the capital sets THREAT_FULL (D-422). The input
## is left as it was; a continent already conquered changes nothing.
static func conquer(save: Dictionary, def: Dictionary, bonus_id: String) -> Dictionary:
	var out := save.duplicate(true)
	var conquered: Array = out.get("conquered", [])
	var id: String = def["id"]
	if conquered.has(id):
		return out
	conquered.append(id)
	out["conquered"] = conquered
	var bonuses: Dictionary = out.get("bonuses", {})
	bonuses[id] = bonus_id
	out["bonuses"] = bonuses
	var threat: float = out.get("threat", 0.0)
	var share: float = def["threat"]
	threat = minf(threat + share, THREAT_CAP)
	out["threat"] = THREAT_FULL if _capital_opens(conquered) else threat
	return out


## True once every continent but the capital has fallen (D-422).
static func _capital_opens(conquered: Array) -> bool:
	for def: Dictionary in Content.continents():
		if not def.get("capital", false) and not conquered.has(def["id"]):
			return false
	return true


## Each continent's State by id, from the rows in sequence order and the conquered ids.
static func states(continents: Array[Dictionary], conquered: Array) -> Dictionary:
	var out := {}
	var open := 1  # Ostia Minor, the first row, stands alone until it is conquered
	if not continents.is_empty() and conquered.has(continents[0]["id"]):
		open = OFFERED
	var left := 0  # unconquered continents that are not the capital
	for def: Dictionary in continents:
		var id: String = def["id"]
		if conquered.has(id):
			out[id] = State.CONQUERED
		elif def.get("capital", false):
			out[id] = State.LOCKED
		else:
			out[id] = State.AVAILABLE if left < open else State.LOCKED
			left += 1
	for def: Dictionary in continents:
		if def.get("capital", false) and out[def["id"]] == State.LOCKED and left == 0:
			out[def["id"]] = State.AVAILABLE
	return out
