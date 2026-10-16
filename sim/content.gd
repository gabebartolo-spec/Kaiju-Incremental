class_name Content
extends RefCounted
## Content and balance from data/*.json, loaded once and cached. Static so test runners and
## sim code can read it without the GameData autoload; GameData only forwards here.

static var _tuning: Dictionary = {}
static var _upgrades: Array[Dictionary] = []
static var _species: Array[Dictionary] = []
static var _looks: Array[Dictionary] = []
static var _look_id := ""


static func tuning() -> Dictionary:
	_load()
	return _tuning


static func section(key: String) -> Dictionary:
	_load()
	var out: Dictionary = _tuning.get(key, {})
	return out


static func upgrades() -> Array[Dictionary]:
	_load()
	return _upgrades


static func species() -> Array[Dictionary]:
	_load()
	return _species


static func species_def(id: String) -> Dictionary:
	for def: Dictionary in species():
		if def["id"] == id:
			return def
	return species()[0]


static func looks() -> Array[Dictionary]:
	_load()
	return _looks


## The art direction in use (data/looks.json); presentation reads its colours and light.
static func look() -> Dictionary:
	_load()
	for def: Dictionary in _looks:
		if def["id"] == _look_id:
			return def
	return _looks[0]


static func set_look(id: String) -> void:
	_load()
	_look_id = id


static func load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		var out: Dictionary = parsed
		return out
	push_error("Content: %s is not a JSON object" % path)
	return {}


static func _load() -> void:
	if not _tuning.is_empty():
		return
	_tuning = load_json("res://data/tuning.json")
	_upgrades = _list("res://data/upgrades.json", "upgrades")
	_species = _list("res://data/species.json", "species")
	_looks = _list("res://data/looks.json", "looks")
	_look_id = str(load_json("res://data/looks.json").get("default", ""))


static func _list(path: String, key: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var raw: Array = load_json(path).get(key, [])
	for entry: Dictionary in raw:
		out.append(entry)
	return out
