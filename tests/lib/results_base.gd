extends "res://tests/lib/runner.gd"
## Shared set-up for the Results suite (tests/run_results_tests.gd): the ending table, the
## screen and frame helpers, the layout and text probes of a ResultsScreen, and the helpers that
## end a rampage by each reason and read the slot afterwards. It defines no test function, so it
## adds none to the suite's count.

const GuiInput := preload("res://tests/lib/gui_input.gd")
const CreationWalk := preload("res://tests/lib/creation_walk.gd")
## Every way a rampage ends (the sim's end reasons) and whether the kaiju dies in it.
const ENDINGS := {"city_fallen": false, "time": true, "defeated": true, "ended": true}
## At most this many frames for a set ending to land (the rise from the river runs first).
const END_WAIT_FRAMES := 60 * 20
## The lab card's 2 s, with room to spare.
const LAB_CARD_WAIT_MS := 6000


func _screen(main: Node) -> Node:
	return main.call("screen")


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


func _tree() -> UpgradeTree:
	return UpgradeTree.new(Content.upgrades())


func _cells(b: RampageSim.Building) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for x: int in b.w:
		for z: int in b.d:
			for y: int in b.height:
				if b.frame.alive(Vector3i(x, y, z)):
					out.append(Vector3i(x, y, z))
	return out


func _layout_misses(screen: ResultsScreen, scale: float) -> Array[String]:
	var out: Array[String] = []
	var view := root.get_visible_rect()
	var m := UiKit.safe_margin() * (view.size.y / 1080.0)
	var safe := view.grow_individual(-m.x, -m.y, -m.x, -m.y)
	var crawl_top := view.end.y
	for node: Node in screen.find_children("*", "NewsTicker", true, false):
		crawl_top = minf(crawl_top, (node as Control).get_global_rect().position.y)
	for node: Node in screen.find_children("*", "Control", true, false):
		var c := node as Control
		if not (c is Label or c is Button) or not c.is_visible_in_tree():
			continue
		if _in_crawl(c):
			continue
		var r := c.get_global_rect()
		var at := " at %d%%" % roundi(scale * 100.0)
		var text: String = c.get("text")
		if not safe.encloses(r) or r.end.y > crawl_top:
			out.append("'%s'%s outside %s: %s" % [text, at, safe, r])
		if c.get_theme_font_size("font_size") < UiKit.SIZE_BODY:
			out.append("'%s'%s under 24 px" % [text, at])
	return out


func _in_crawl(c: Control) -> bool:
	var p := c.get_parent()
	while p != null:
		if p is NewsTicker:
			return true
		p = p.get_parent()
	return false


func _texts(screen: Node) -> Array[String]:
	var out: Array[String] = []
	for node: Node in screen.find_children("*", "Label", true, false):
		out.append((node as Label).text)
	return out


## The value and badge after the row named `label` (the grid holds name, value, badge).
func _row_texts(screen: Node, label: String) -> Array:
	for node: Node in screen.find_children("*", "Label", true, false):
		if (node as Label).text == label:
			var grid := node.get_parent()
			var i := node.get_index()
			return [(grid.get_child(i + 1) as Label).text, (grid.get_child(i + 2) as Label).text]
	return []


## After a death the lab card shows about 2 s before the next rise (D-260): wait it out.
func _past_lab_card(main: Node) -> void:
	var start := Time.get_ticks_msec()
	while _screen(main) is SpecimenCard and Time.get_ticks_msec() - start < LAB_CARD_WAIT_MS:
		await process_frame


## The ending's headline as data writes it (tuning "results" "endings").
func _data_headline(reason: String) -> String:
	var endings: Dictionary = Content.section("results")["endings"]
	var ending: Dictionary = endings[reason]
	return str(ending["headline"])


## Ends `rampage` for `reason`: End rampage through the pause menu by clicks, else the sim's
## state set so its own rule ends the run. Returns the report once the beat is skipped.
func _end_by(rampage: Rampage, reason: String) -> ResultsScreen:
	var sim := rampage.sim
	if reason == "ended":
		await GuiInput.key(self, KEY_ESCAPE)
		var menu := GuiInput.find_script(rampage, PauseMenu)
		await GuiInput.click(self, GuiInput.button(menu, "END RAMPAGE"))
		await GuiInput.click(self, GuiInput.button(menu, "YES"))
	for _i: int in END_WAIT_FRAMES:
		if sim.over:
			break
		match reason:
			"time":
				sim.time_left = 0.0
			"defeated":
				sim.hp = -sim.max_hp  # below whatever it regrows in a step
			"city_fallen":
				sim.chunks_destroyed = sim.chunks_total
		await process_frame
	check(sim.end_reason == reason, "the run ends as '%s' (%s)" % [reason, sim.end_reason])
	var burst := sim.death.phase == DeathOverload.Phase.SHATTER
	check(burst == (reason != "city_fallen"), "'%s': results wait for a death's burst" % reason)
	await _frames(RampageHud.BEAT_MIN_FRAMES + 2)
	await GuiInput.key(self, KEY_ENTER)
	await _frames(2)
	return GuiInput.find_script(rampage, ResultsScreen) as ResultsScreen


## After the four endings: four rampages banked with every new best key, three deaths.
func _slot_after_endings() -> void:
	var save := SaveFile.load_game(1)
	var best: Dictionary = save.get("best", {})
	check(
		(
			Num.i(save.get("runs", 0)) == ENDINGS.size()
			and best.has("landmarks")
			and best.has("agents")
		),
		"slot 1 banked every run with the new bests: runs %s, best %s" % [save.get("runs"), best]
	)
	check(
		Num.i(save.get("specimen", 0)) == 4,
		"three deaths make the fourth specimen: %s" % save.get("specimen")
	)
