extends Node
## The save, as an autoload for the flow (scenes/main.gd). The format, versions and migration
## live in SaveFile (autoload/save_file.gd); this forwards to it.

const VERSION := SaveFile.VERSION


func has_save() -> bool:
	return SaveFile.has_save()


func save_game(data: Dictionary) -> void:
	SaveFile.save_game(data)


func load_game() -> Dictionary:
	return SaveFile.load_game()


func delete_save() -> void:
	SaveFile.delete_save()
