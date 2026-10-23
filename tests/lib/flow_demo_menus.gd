extends RefCounted
## The flow suite's demo checks on the menus (D-050, D-145): a save of a species the demo leaves
## out is not continued, and settings list only the controls the playable species can use.

const GuiInput := preload("res://tests/lib/gui_input.gd")
const MAIN_SCENE := "res://scenes/main.tscn"

var t: SceneTree
var check: Callable


func _init(runner: SceneTree, p_check: Callable) -> void:
	t = runner
	check = p_check


func run() -> void:
	await _check_other_species_save()
	await _check_controls_rows()


func _screen(main: Node) -> Node:
	return main.call("screen")


func _frames(n: int) -> void:
	for _i: int in n:
		await t.process_frame


## A save from a species the demo leaves out is not offered: no Continue into a hidden kaiju.
func _check_other_species_save() -> void:
	var save := SaveFile.new_save("insectoid")
	save["runs"] = 3
	SaveFile.save_game(save)
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	t.root.add_child(main)
	await _frames(3)
	check.call(
		GuiInput.button(_screen(main), "CONTINUE") == null,
		"the demo does not continue a save of a species it leaves out"
	)
	main.queue_free()
	await _frames(2)


## Settings' controls list only what the playable species can do: the croc-only demo shows no
## insectoid Glide row; the full game does (lead, 2026-10-18).
func _check_controls_rows() -> void:
	var with_demo := await _control_names()
	var demo := Content.section("demo")
	demo["enabled"] = false
	var full_game := await _control_names()
	demo["enabled"] = true
	var glide := func(names: Array[String]) -> bool:
		return names.any(func(n: String) -> bool: return n.containsn("glide"))
	check.call(
		not glide.call(with_demo) and glide.call(full_game),
		"the demo's controls list has no insectoid Glide; the full game's has: %s" % [with_demo]
	)


func _control_names() -> Array[String]:
	var menu := ControlsCard.new()
	t.root.add_child(menu)
	await _frames(2)
	var names: Array[String] = []
	for node: Node in menu.find_children("*", "Label", true, false):
		names.append((node as Label).text)
	menu.queue_free()
	await _frames(1)
	return names
