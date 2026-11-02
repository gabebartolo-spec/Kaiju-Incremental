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


## Settings' controls list only what the playable species can do: the croc's Breath row in the
## demo and the full game alike, and no Glide in either (the insectoid is not playable, D-438).
func _check_controls_rows() -> void:
	var with_demo := await _control_names()
	var demo := Content.section("demo")
	demo["enabled"] = false
	var full_game := await _control_names()
	demo["enabled"] = true
	var has := func(names: Array[String], word: String) -> bool:
		return names.any(func(n: String) -> bool: return n.containsn(word))
	check.call(
		(
			has.call(with_demo, "breath")
			and has.call(full_game, "breath")
			and not has.call(with_demo, "glide")
			and not has.call(full_game, "glide")
		),
		"both controls lists show the croc's Breath and no Glide: %s / %s" % [with_demo, full_game]
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
