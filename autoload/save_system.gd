extends Node
## Versioned save. One file: species, rubble bank, upgrade levels, run history.
## A save from a newer version is refused, never half-loaded.

const PATH := "user://save.json"
const VERSION := 1


func has_save() -> bool:
	return FileAccess.file_exists(PATH)


func save_game(data: Dictionary) -> void:
	var payload: Dictionary = data.duplicate(true)
	payload["version"] = VERSION
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: cannot write %s" % PATH)
		return
	file.store_string(JSON.stringify(payload, "\t"))


func load_game() -> Dictionary:
	if not has_save():
		return {}
	return migrate(Content.load_json(PATH))


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


static func migrate(data: Dictionary) -> Dictionary:
	var version: int = Num.i(data.get("version", 0))
	if version > VERSION or version < 1:
		push_warning("SaveSystem: save version %d not supported" % version)
		return {}
	return data
