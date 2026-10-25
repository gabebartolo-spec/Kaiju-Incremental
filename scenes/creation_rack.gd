class_name CreationRack
extends RefCounted
## The genome rack of Kaiju Creation (D-207): every titan in data/tuning.json "creation" "titans",
## in order. A titan is unlocked if data starts a new player with it or the save's titans_unlocked
## list holds it (so the scene can replay for each new titan; the unlock rules are not decided).
## It can be picked only when unlocked, with a species to play that this build allows (the demo).
## Pure: reads Content and the save it is given, writes nothing.


## Each titan: {id, name, species, genome (Color), locked, selectable}.
static func titans(save: Dictionary) -> Array[Dictionary]:
	var cfg := Content.section("creation")
	var opened: Array = save.get(str(cfg["save_key"]), [])
	var out: Array[Dictionary] = []
	for row: Dictionary in cfg["titans"]:
		var id := str(row["id"])
		var species := str(row["species"])
		var unlocked: bool = row["unlocked"] == true or opened.has(id)
		var playable := species != "" and Demo.allows(species) and _exists(species)
		var titan := {
			"id": id,
			"name": str(row["name"]),
			"species": species,
			"genome": Color(str(row["genome"])),
			"locked": not unlocked,
			"selectable": unlocked and playable,
		}
		out.append(titan)
	return out


static func _exists(species: String) -> bool:
	for def: Dictionary in Content.species():
		if str(def["id"]) == species:
			return true
	return false
