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
