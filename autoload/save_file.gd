class_name SaveFile
extends RefCounted
## Versioned save. One file: species, rubble bank, upgrade levels, run history and the best
## rampage so far (what the results screen compares against).
## A save from a newer version is refused, never half-loaded; an older one is migrated.
## Static so screens and tests can use it without the SaveSystem autoload (which forwards here).

const PATH := "user://save.json"
const VERSION := 2
## The results screen's records: each is the best single rampage, per stat.
const BEST_KEYS: Array[String] = [
	"rubble", "destruction", "toppled", "tallest_topple", "civilians", "tanks", "helis"
]


static func has_save() -> bool:
	return FileAccess.file_exists(PATH)


static func save_game(data: Dictionary) -> void:
	var payload: Dictionary = data.duplicate(true)
	payload["version"] = VERSION
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: cannot write %s" % PATH)
		return
	file.store_string(JSON.stringify(payload, "\t"))


static func load_game() -> Dictionary:
	if not has_save():
		return {}
	return migrate(Content.load_json(PATH))


static func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


## A fresh save for a new kaiju of `species_id`.
static func new_save(species_id: String) -> Dictionary:
	return {
		"version": VERSION, "species": species_id, "rubble": 0, "levels": {}, "runs": 0, "best": {}
	}


## Brings an older save up to VERSION. v1 kept only "best_destruction"; v2 keeps a "best"
## record per stat. Unknown or newer versions are refused (empty), never guessed at.
static func migrate(data: Dictionary) -> Dictionary:
	var version: int = Num.i(data.get("version", 0))
	if version > VERSION or version < 1:
		push_warning("SaveSystem: save version %d not supported" % version)
		return {}
	var out: Dictionary = data.duplicate(true)
	if version == 1:
		out["best"] = {"destruction": Num.f(out.get("best_destruction", 0.0))}
		out.erase("best_destruction")
	out["version"] = VERSION
	return out


## The best record after a rampage `result`, keeping the higher of each stat.
static func merge_best(best: Dictionary, result: Dictionary) -> Dictionary:
	var out: Dictionary = best.duplicate()
	for key: String in BEST_KEYS:
		if result.has(key):
			out[key] = maxf(Num.f(out.get(key, 0.0)), Num.f(result[key]))
	return out
