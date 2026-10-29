extends RefCounted
## Which intro a run started through Main plays, from a real save on disk (R 20.4): the first run
## plays the whole intro, a run after an evolution (a bigger size than the last run's) plays it
## whole too, any other run plays the short cut; Main notes the size it showed in the save
## ("intro_size"). Driven by real clicks (Continue, Slot 1, RAMPAGE). Seeded by design: no
## randomness is read; the saves are fixtures.

const GuiInput := preload("res://tests/lib/gui_input.gd")
const MAIN_SCENE := "res://scenes/main.tscn"


static func run(tree: SceneTree, check: Callable) -> void:
	# The full game: the demo ends on the first evolution, so it is off here (as FlowDemo does).
	var demo := Content.section("demo")
	var was: Variant = demo.get("enabled", false)
	demo["enabled"] = false
	# The first run (Continue on a save with no run yet starts it at once).
	await _case(tree, check, {"runs": 0}, true, "the first run")
	# A later run at the size the last run showed.
	await _case(tree, check, {"runs": 3, "intro_size": 1}, false, "a run with nothing new")
	# The first run after the first evolution (size 2, the last run showed size 1).
	var evolved := {"runs": 3, "intro_size": 1, "levels": {"evolve1": 1}}
	await _case(tree, check, evolved, true, "the first run after an evolution")
	SaveFile.delete_save()
	demo["enabled"] = was


static func _case(
	tree: SceneTree, check: Callable, fields: Dictionary, full: bool, what: String
) -> void:
	var save := SaveFile.new_save("reptilian")
	save.merge(fields, true)
	SaveFile.save_game(save)
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	tree.root.add_child(main)
	await _frames(tree, 3)
	var title: Node = main.call("screen")
	await GuiInput.click(tree, GuiInput.button(title, "CONTINUE"))
	var slots: Node = main.call("screen")  # the save slots
	await GuiInput.click(tree, GuiInput.button(slots, "SLOT 1"))
	await _frames(tree, 3)
	var screen: Node = main.call("screen")
	if screen is UpgradeScreen:
		await GuiInput.click(tree, GuiInput.button(screen, "RAMPAGE"))
		await _frames(tree, 3)
		screen = main.call("screen")
	var rampage := screen as Rampage
	var tier := rampage.sim.size_tier() if rampage != null else -1
	var noted: Dictionary = main.get("_save")
	(
		check
		. call(
			rampage != null and rampage.full_intro == full and Num.i(noted["intro_size"]) == tier,
			(
				"%s (save %s) plays the %s intro: %s; Main notes size %s for the next run"
				% [
					what,
					fields,
					"whole" if full else "short",
					rampage.full_intro if rampage != null else "no rampage",
					noted.get("intro_size", "nothing"),
				]
			)
		)
	)
	main.queue_free()
	await _frames(tree, 2)


static func _frames(tree: SceneTree, n: int) -> void:
	for _i: int in n:
		await tree.process_frame
