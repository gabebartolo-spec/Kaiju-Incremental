extends "res://tests/lib/runner.gd"
## Kaiju Creation suite (D-207): New Game opens the lab, where only the croc genome can be picked
## (the Komodo and serpent genomes greyed and locked, read from data and the save); the pick and
## the injection are real input (keyboard, then pad); the pick sends the injector's needle into
## the croc's vial and then the dish (no vial flies); the sequence runs on its data timings into
## the black with the egg crack, and the first run starts with the river rise. Seeded: the city
## and the army use pinned streams and the lab draws no random numbers.
##   godot --headless --path . --script tests/run_creation_tests.gd

const GuiInput := preload("res://tests/lib/gui_input.gd")
const MAIN_SCENE := "res://scenes/main.tscn"
const RACK_SCRIPT := "res://scenes/creation_rack.gd"
## Ticks a step may take at most before the check gives up (a hang fails instead of stalling).
const STEP_CAP := 60 * 20
## Ticks the sequence after the injection may differ from its data timings by.
const TICK_SLACK := 3


func suite_name() -> String:
	return "Creation"


func run_checks() -> void:
	SaveFile.delete_save()
	await _t("_check_new_game_opens_lab")
	await _t("_check_rack_reads_save")
	SaveFile.delete_save()


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


func _screen(main: Node) -> Node:
	return main.call("screen")


func _is_lab(node: Node) -> bool:
	if node == null:
		return false
	var script: Script = node.get_script()
	return script != null and script.get_global_name() == "KaijuCreation"


## New Kaiju opens the lab; only the croc genome is lit and focused; Esc goes back to the title;
## Enter picks the croc, pad A injects it, and the run starts with the river rise after the black
## and the egg crack, on the data's timings.
func _check_new_game_opens_lab() -> void:
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	root.add_child(main)
	await _frames(3)
	await GuiInput.click(self, GuiInput.button(_screen(main), "NEW KAIJU"))
	await _frames(2)
	var lab := _screen(main)
	check(_is_lab(lab), "NEW KAIJU opens Kaiju Creation, not %s" % [lab])
	if not _is_lab(lab):
		main.queue_free()
		await _frames(2)
		return
	await _rack_ok(lab)
	await GuiInput.key(self, KEY_ESCAPE)
	await _frames(2)
	check(_screen(main) is TitleScreen, "Esc in the lab goes back to the title, nothing saved")
	check(not SaveFile.has_save(), "backing out of the lab writes no save")
	await GuiInput.click(self, GuiInput.button(_screen(main), "NEW KAIJU"))
	await _frames(2)
	lab = _screen(main)
	await GuiInput.key(self, KEY_ENTER)
	var trip := await _watch_place(lab)
	var inject: Button = trip.get("inject")
	check(
		inject != null and inject.has_focus(),
		"Enter puts the croc genome in the dish, then INJECT SPECIAL K takes the focus"
	)
	var visited: bool = trip["vial"] == true and trip["dish"] == true
	check(visited, "the needle goes down into the croc's vial, then into the dish: %s" % [trip])
	var still: bool = trip["moved"] == false
	check(still, "the croc's vial stays in the rack (no vial flies to the dish)")
	if inject == null:
		main.queue_free()
		await _frames(2)
		return
	await _sequence_ok(main, lab)
	main.queue_free()
	await _frames(2)


## The rack: croc lit and focused, the other two greyed, locked and out of the focus order; every
## line of text 24 px or more at 1080p.
func _rack_ok(lab: Node) -> void:
	var croc := GuiInput.button(lab, "CROC")
	var komodo := GuiInput.button(lab, "KOMODO")
	var serpent := GuiInput.button(lab, "SERPENT")
	check(
		croc != null and komodo != null and serpent != null,
		"the rack shows the croc, Komodo and serpent genomes"
	)
	if croc == null or komodo == null or serpent == null:
		return
	check(
		not croc.disabled and komodo.disabled and serpent.disabled,
		"only the croc genome can be picked; the Komodo and serpent are locked"
	)
	check(
		komodo.focus_mode == Control.FOCUS_NONE and serpent.focus_mode == Control.FOCUS_NONE,
		"the locked genomes are out of the keyboard and pad focus order"
	)
	check(croc.has_focus(), "the croc genome has the focus from the start")
	var small: Array[String] = []
	for node: Node in lab.find_children("*", "Control", true, false):
		var c: Control = node
		if (c is Label or c is Button) and c.is_visible_in_tree():
			var px := c.get_theme_font_size("font_size")
			if px < UiKit.SIZE_BODY:
				small.append("%s %d" % [c.name, px])
	check(small.is_empty(), "every line in the lab is 24 px or more at 1080p: %s" % [small])


## Waits out the pick and watches the injector's trip (director 2026-10-25: "injector rotates to
## the croc vial, drains it, moves to dish and puts croc gene into dish", "i do NOT want the vials
## magically flying over to the dish"): the needle tip goes down into the croc's vial, then into
## the dish, and the vial's liquid never leaves the rack. Returns what it saw and the INJECT
## button.
func _watch_place(lab: Node) -> Dictionary:
	var room: CreationLab = lab.get("lab")
	var vial_at := room.vial_point(0)
	var liquid: Node3D = room.vials[0].node
	var home := liquid.global_position
	var cfg: Dictionary = CreationSet.cfg()["injector"]
	var near := Num.f(CreationSet.cfg()["voxel"]) * 3.0
	var seen := {"vial": false, "dish": false, "moved": false}
	for _i: int in STEP_CAP:
		var tip := room.injector.tip
		var off_vial := Vector2(tip.x - vial_at.x, tip.z - vial_at.z).length()
		if off_vial < near and tip.y < Num.f(cfg["vial_top"]):
			seen["vial"] = true
		var in_dish := Vector2(tip.x, tip.z).length() < near and tip.y < Num.f(cfg["cradle_top"])
		if seen["vial"] == true and in_dish:
			seen["dish"] = true
		if liquid.global_position.distance_to(home) > 0.001:
			seen["moved"] = true
		var b := GuiInput.button(lab, "INJECT")
		if b != null and not b.disabled and b.has_focus():
			seen["inject"] = b
			return seen
		await physics_frame
	return seen


func _wait_inject(lab: Node) -> Button:
	for _i: int in STEP_CAP:
		var b := GuiInput.button(lab, "INJECT")
		if b != null and not b.disabled and b.has_focus():
			return b
		await physics_frame
	return null


## Pad A injects; the screen turns black, the egg crack is heard in the black, and the run starts
## on the data's timings with the kaiju rising from the river.
func _sequence_ok(main: Node, lab: Node) -> void:
	var cues: Array = lab.get("cues")
	var timing: Dictionary = Content.section("creation")["timing"]
	var want := 0
	for key: String in ["inject_s", "takeover_s", "zoom_s", "black_s"]:
		want += roundi(Num.f(timing[key]) * Engine.physics_ticks_per_second)
	await GuiInput.pad(self, JOY_BUTTON_A)
	var ticks := 2  # GuiInput.pad waited a frame for the press and one for the release
	var crack_black := false
	while not (_screen(main) is Rampage) and ticks < STEP_CAP:
		if not crack_black and cues.has("egg_crack") and is_instance_valid(lab):
			crack_black = Num.f(lab.call("black")) >= 0.99
		await physics_frame
		ticks += 1
	check(cues.has("egg_crack"), "the egg crack cue plays: %s" % [cues])
	check(crack_black, "the egg crack is heard over a black screen")
	check(
		absi(ticks - want) <= TICK_SLACK,
		"injection to the run takes the data's %d ticks, took %d" % [want, ticks]
	)
	var rampage := _screen(main) as Rampage
	check(
		rampage != null and str(rampage.species["id"]) == "reptilian",
		"the croc genome starts a reptilian run"
	)
	if rampage == null:
		return
	await rampage.wait_loaded()
	check(rampage.sim.emerge.active, "the first run opens with the baby rising from the river")
	var save := SaveFile.load_game()
	check(
		str(save.get("species", "")) == "reptilian" and Num.i(save.get("runs", -1)) == 0,
		"the new save is a reptilian with no rampages yet: %s" % [save.get("species")]
	)


## The rack's data: croc, Komodo, serpent in order, the croc unlocked; a titan unlocked in the
## save reads unlocked (the replay for each new titan), but only a titan with a species to play
## can be picked.
func _check_rack_reads_save() -> void:
	check(ResourceLoader.exists(RACK_SCRIPT), "the rack's rules live in %s" % RACK_SCRIPT)
	if not ResourceLoader.exists(RACK_SCRIPT):
		return
	var rack: GDScript = load(RACK_SCRIPT)
	var fresh: Array = rack.call("titans", {})
	var ids: Array[String] = []
	var locked: Array[bool] = []
	for t: Dictionary in fresh:
		ids.append(str(t["id"]))
		locked.append(t["locked"] == true)
	check(ids == ["croc", "komodo", "serpent"], "the rack holds croc, Komodo, serpent: %s" % [ids])
	check(locked == [false, true, true], "a new player has the croc only: %s" % [locked])
	var later: Array = rack.call("titans", {"titans_unlocked": ["komodo"]})
	var komodo: Dictionary = later[1]
	var shown: bool = komodo["locked"] == false and komodo["selectable"] == false
	check(
		shown,
		"a Komodo unlocked in the save reads unlocked, yet has no titan to play yet: %s" % [komodo]
	)
