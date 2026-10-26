extends "res://tests/lib/runner.gd"
## Shared fixtures for the save-slots suite (run_slots_tests): the v4 save, the title scene
## opened and closed through Main, and the legacy save.json writer.

const GuiInput := preload("res://tests/lib/gui_input.gd")
const CreationWalk := preload("res://tests/lib/creation_walk.gd")
const MAIN_SCENE := "res://scenes/main.tscn"
## A save as v4 (the last single-save version) wrote it: every key a played kaiju holds.
const V4 := {
	"version": 4,
	"species": "reptilian",
	"rubble": 1234,
	"levels": {"claws": 2, "hide": 1, "evolve1": 1},
	"runs": 7,
	"best": {"rubble": 900.0, "destruction": 0.42, "toppled": 5.0},
	"city_seconds": 61.5,
	"demo": true,
	"demo_done": false,
	"totals": {"rubble": 4000.0},
	"last_time": "night",
	"last_weather": "rain",
}


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


func _screen(main: Node) -> Node:
	return main.call("screen")


func _main() -> Node:
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	root.add_child(main)
	await _frames(3)
	return main


func _close(main: Node) -> void:
	main.queue_free()
	await _frames(2)


## Deep equality with numbers compared by value (JSON reads every number back as a float).
func _same(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return Num.f(a) == Num.f(b)
	if a is Dictionary and b is Dictionary:
		var da: Dictionary = a
		var db: Dictionary = b
		if da.size() != db.size():
			return false
		for key: Variant in da:
			if not db.has(key) or not _same(da[key], db[key]):
				return false
		return true
	return typeof(a) == typeof(b) and a == b


func _write_legacy(data: Dictionary) -> void:
	var file := FileAccess.open(SaveFile.LEGACY_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
