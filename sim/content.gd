class_name Content
extends RefCounted
## Content and balance from data/*.json, loaded once and cached. Static so test runners and
## sim code can read it without the GameData autoload; GameData only forwards here.

static var _tuning: Dictionary = {}
static var _upgrades: Array[Dictionary] = []
static var _species: Array[Dictionary] = []
static var _looks: Array[Dictionary] = []
static var _look_id := ""
static var _times: Dictionary = {}
static var _time_id := ""
static var _weather: Dictionary = {}
static var _weather_id := ""
static var _merged: Dictionary = {}
static var _landmarks: Dictionary = {}
static var _sports: Dictionary = {}
static var _materials: Array[Dictionary] = []


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


## Each landmark's baked shape (data/landmarks.json, written by tools/landmarks/bake.py): id ->
## {w, d, h, kvox, chunks (one string per floor, "1" per structural chunk, x fastest)}.
static func landmarks() -> Dictionary:
	_load()
	return _landmarks


## The stadium's matches (D-078, data/sports.json): "pitch" (where on the stadium, pace) and
## "sports" (markings, posts, kits, ball). Presentation only.
static func sports() -> Dictionary:
	_load()
	return _sports


## Building cell materials (data/materials.json, D-094): {id (the byte a fine grid cell
## holds, 1..255; 0 is empty), name (its BuildingVoxels palette key), strength, debris}.
static func materials() -> Array[Dictionary]:
	_load()
	return _materials


static func looks() -> Array[Dictionary]:
	_load()
	return _looks


## The art direction in use (data/looks.json); presentation reads its colours and light.
## Its time of day (director 2026-10-20: "all of them") is merged over it.
static func look() -> Dictionary:
	_load()
	if _merged.is_empty():
		var base: Dictionary = _looks[0]
		for def: Dictionary in _looks:
			if def["id"] == _look_id:
				base = def
		_merged = base.duplicate(true)
		var over: Dictionary = _times.get(_time_id, {})
		_merged.merge(over, true)
	return _merged


static func set_look(id: String) -> void:
	_load()
	_look_id = id
	_merged = {}


## The times of day in rotation order (data/looks.json "times"); the first is the look itself.
static func times() -> Array:
	_load()
	return _times["order"]


## The whole "times" table of data/looks.json (order, labels, each time's look overrides).
static func time_table() -> Dictionary:
	_load()
	return _times


## The time of day in use (an id of times()); presentation reads it, the sim never does.
static func time_id() -> String:
	_load()
	return _time_id


static func set_time(id: String) -> void:
	_load()
	if id == _time_id:
		return  # keeps any change a capture made to the look in use
	_time_id = id
	_merged = {}


## The weathers in rotation order (data/looks.json "weather").
static func weathers() -> Array:
	_load()
	return _weather["order"]


## The whole "weather" table of data/looks.json (order, labels).
static func weather_table() -> Dictionary:
	_load()
	return _weather


## The one current weather of the run in play (D-155): an id of weathers(). Main sets it when a
## rampage starts (Weather.pick); presentation reads it. Before any run it is the first weather.
static func weather_id() -> String:
	_load()
	return _weather_id


static func set_weather(id: String) -> void:
	_load()
	_weather_id = id


## The fixed order: run n plays the nth time of day. Captures and tests use it to land on a known
## time; the game picks with TimeOfDay (D-145).
static func time_for_run(run_index: int) -> String:
	return str(times()[posmod(run_index, times().size())])


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
	var looks_file := load_json("res://data/looks.json")
	_look_id = str(looks_file.get("default", ""))
	_times = looks_file.get("times", {"order": [""]})
	_time_id = str(_times["order"][0])
	_weather = looks_file.get("weather", {"order": [""], "labels": {}, "random_label": ""})
	_weather_id = str(_weather["order"][0])
	_landmarks = load_json("res://data/landmarks.json").get("landmarks", {})
	_sports = load_json("res://data/sports.json")
	_materials = _list("res://data/materials.json", "materials")
	var names: Dictionary = _tuning.get("names", {})
	for content: Variant in [_tuning, _upgrades, _species]:
		_fill(content, names)
	# The city plan reads landmark shapes from its config, so CityGen.map stays a function of cfg.
	var city: Dictionary = _tuning.get("city", {})
	city["landmark_shapes"] = _landmarks


static func _list(path: String, key: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var raw: Array = load_json(path).get(key, [])
	for entry: Dictionary in raw:
		out.append(entry)
	return out


## Player-facing names live once, in tuning "names" (a later rename is one line there); data text
## writes {key} where one belongs ("{beam}" is the reptilian's signature beam).
static func _fill(node: Variant, names: Dictionary) -> void:
	if node is Dictionary:
		var dict: Dictionary = node
		for key: Variant in dict:
			var value: Variant = dict[key]
			if value is String:
				dict[key] = _named(str(value), names)
			else:
				_fill(value, names)
	elif node is Array:
		var list: Array = node
		for i: int in list.size():
			if list[i] is String:
				list[i] = _named(str(list[i]), names)
			else:
				_fill(list[i], names)


static func _named(text: String, names: Dictionary) -> String:
	for key: String in names:
		text = text.replace("{%s}" % key, str(names[key]))
	return text
