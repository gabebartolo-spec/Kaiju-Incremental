extends "res://tests/lib/runner.gd"
## Results suite (D-259 results, D-263 "Headline per ending", D-265 End rampage is a death): the
## headline and the crawl's last line per ending; the sim counts landmarks felled; the save slot
## keeps the new personal bests; NEW RECORD stamps land on beaten rows only; best combo shows a
## dash until the combo feeds it; the report fits the title-safe area with text 24 px or more;
## and every ending reaches its own report by real input through Main.
## Seeded by design: the landmark check breaks chunks by hand; the played runs only need an
## ending (set on the sim), not an outcome, and use the pinned city stream.
##   godot --headless --path . --script tests/run_results_tests.gd

const GuiInput := preload("res://tests/lib/gui_input.gd")
const CreationWalk := preload("res://tests/lib/creation_walk.gd")
const MAIN_SCENE := "res://scenes/main.tscn"
## Every way a rampage ends (the sim's end reasons) and whether the kaiju dies in it.
const ENDINGS := {"city_fallen": false, "time": true, "defeated": true, "ended": true}
## The director's TV (D-027); headless windows start at 64x64.
const TV_SIZE := Vector2i(3840, 2160)
## At most this many frames for a set ending to land (the rise from the river runs first).
const END_WAIT_FRAMES := 60 * 20
const SAMPLE := {
	"rubble": 420,
	"destruction": 0.37,
	"toppled": 6,
	"tallest_topple": 14,
	"landmarks": 2,
	"civilians": 88,
	"tanks": 5,
	"helis": 1,
	"agents": 3,
	"reason": "time",
}


func suite_name() -> String:
	return "Results"


func run_checks() -> void:
	SaveFile.wipe()
	await _t("_check_headlines")
	await _t("_check_landmarks_felled")
	await _t("_check_bests_in_slot")
	await _t("_check_record_stamps")
	await _t("_check_combo_hook")
	await _t("_check_fits_safe_area")
	await _t("_check_endings_by_input")
	SaveFile.wipe()
	SaveFile.slot = 1


func _screen(main: Node) -> Node:
	return main.call("screen")


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


## Each ending has its own headline (data), none the fallback; every death closes the crawl on
## the remains, the city's fall does not.
func _check_headlines() -> void:
	var seen: Dictionary = {}
	for reason: String in ENDINGS:
		var line := ResultsScreen.headline(reason)
		check(
			line != ResultsScreen.DEFAULT_HEADLINE and not seen.has(line),
			"ending '%s' has its own headline: %s" % [reason, line]
		)
		seen[line] = true
		var crawl := ResultsScreen.news({"reason": reason})
		var close: String = crawl[crawl.size() - 1]
		var dies: bool = ENDINGS[reason]
		check(
			close.contains("REMAINS") == dies,
			"ending '%s' closes the crawl on %s: %s" % [reason, "the remains" if dies else "it", close]
		)
	check(
		ResultsScreen.headline("") == ResultsScreen.DEFAULT_HEADLINE,
		"a result with no reason gets the plain report title"
	)


## A landmark counts as felled once it lost the data share of its chunks; a plain building
## never counts, however flat.
func _check_landmarks_felled() -> void:
	var layout: Array[Dictionary] = [
		{"x": 0.0, "z": 0.0, "w": 4, "d": 4, "h": 4, "tier": 1, "style": 0, "landmark": "spire"},
		{"x": -8.0, "z": 0.0, "w": 3, "d": 3, "h": 3, "tier": 1, "style": 1},
	]
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), Content.species_def("reptilian"), _tree()
	)
	var sim := RampageSim.new(stats, Content.tuning(), layout, Seeds.make("army", 0))
	var share := Num.f(Content.section("results")["landmark_felled_share"])
	var mark := sim.buildings[0]
	var cells := _cells(mark)
	var under := ceili(share * cells.size()) - 1
	for c: Vector3i in cells.slice(0, under):
		mark.frame.remove(c)
	for c: Vector3i in _cells(sim.buildings[1]):
		sim.buildings[1].frame.remove(c)
	check(
		Num.i(sim.result()["landmarks"]) == 0,
		"a landmark short of the share (%d of %d chunks gone) and a flattened block count 0"
		% [under, cells.size()]
	)
	mark.frame.remove(cells[under])
	check(
		Num.i(sim.result()["landmarks"]) == 1,
		"the chunk that reaches the share fells the landmark (%s)" % sim.result()["landmarks"]
	)


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


## The new records (landmarks, agents, best combo) are kept per stat in the slot's own save, and
## a save from before them loads with nothing to beat.
func _check_bests_in_slot() -> void:
	var old := {"rubble": 100.0, "toppled": 9.0}
	var merged := SaveFile.merge_best(old, SAMPLE.merged({"best_combo": 1.6}))
	check(
		(
			Num.i(merged["landmarks"]) == 2
			and Num.i(merged["agents"]) == 3
			and is_equal_approx(Num.f(merged["best_combo"]), 1.6)
			and Num.i(merged["toppled"]) == 9
		),
		"the bests take the new stats and keep a higher old one: %s" % [merged]
	)
	check(
		not SaveFile.merge_best(old, SAMPLE).has("best_combo"),
		"no best combo is recorded while the run reports none"
	)
	var save := SaveFile.new_save("reptilian")
	save["best"] = merged
	SaveFile.save_game(save, 2)
	var back: Dictionary = SaveFile.load_game(2).get("best", {})
	check(
		Num.i(back.get("landmarks", 0)) == 2 and Num.i(back.get("agents", 0)) == 3,
		"slot 2 reloads its bests: %s" % [back]
	)
	check(not SaveFile.has_save(1), "slot 1 is untouched by slot 2's records")
	SaveFile.delete_save(2)


## Beaten rows wear the NEW RECORD stamp once the count lands; missed rows show their best.
func _check_record_stamps() -> void:
	var best := {"rubble": 500.0, "landmarks": 1.0, "agents": 5.0, "toppled": 6.0}
	var screen := ResultsScreen.new(SAMPLE, best)
	root.add_child(screen)
	await _frames(3)
	var during := _texts(screen).count(ResultsScreen.STAMP_TEXT)
	await GuiInput.key(self, KEY_ENTER)
	await _frames(2)
	var texts := _texts(screen)
	check(during == 0, "no stamp shows before the count lands (%d)" % during)
	check(
		screen.records().has("landmarks") and not screen.records().has("agents"),
		"landmarks beat their best, agents did not: %s" % [screen.records()]
	)
	check(
		texts.count(ResultsScreen.STAMP_TEXT) == screen.records().size(),
		"one NEW RECORD stamp per beaten row: %d for %s" % [texts.count("NEW RECORD"), screen.records()]
	)
	check(texts.has("best 5") and texts.has("best 6"), "missed and tied rows show their best")
	check(
		screen.title.text == _data_headline("time"),
		"the report is headed by its ending: %s" % screen.title.text
	)
	screen.queue_free()
	await _frames(1)


## Best combo: a dash and no best or stamp until the run reports it; then a multiplier.
func _check_combo_hook() -> void:
	var bare := ResultsScreen.new(SAMPLE, {"rubble": 1.0, "best_combo": 1.2})
	var fed := ResultsScreen.new(SAMPLE.merged({"best_combo": 1.8}), {"rubble": 1.0, "best_combo": 1.2})
	for screen: ResultsScreen in [bare, fed]:
		root.add_child(screen)
	await _frames(2)
	bare.skip()
	fed.skip()
	var row := ResultsScreen.ROWS.find(["best_combo", "Best combo", "combo", "biomass"])
	check(row >= 0, "the results list a best combo row")
	var b := _row_texts(bare, "Best combo")
	var f := _row_texts(fed, "Best combo")
	check(
		b == [ResultsScreen.NO_VALUE, ""] and not bare.records().has("best_combo"),
		"with no combo fed the row shows a dash, no best, no stamp: %s" % [b]
	)
	check(
		f == ["x1.8", ResultsScreen.STAMP_TEXT],
		"a fed combo shows as a multiplier and can set a record: %s" % [f]
	)
	bare.queue_free()
	fed.queue_free()
	await _frames(1)


## On the TV at every UI scale: every text inside the title-safe area, above the crawl, 24 px or
## more at 1080p; the stamp included.
func _check_fits_safe_area() -> void:
	var window := root.size
	root.size = TV_SIZE
	var misses: Array[String] = []
	var best := {"rubble": 1.0, "tallest_topple": 1.0, "landmarks": 0.0, "civilians": 1.0}
	for scale: float in PlayerSettings.UI_SCALES:
		PlayerSettings.ui_scale = scale
		PlayerSettings.apply()
		var screen := ResultsScreen.new(SAMPLE, best)
		root.add_child(screen)
		await _frames(3)
		screen.skip()
		await _frames(2)
		misses.append_array(_layout_misses(screen, scale))
		screen.queue_free()
		await _frames(1)
	PlayerSettings.ui_scale = PlayerSettings.UI_SCALES[0]
	PlayerSettings.apply()
	root.size = window
	check(misses.is_empty(), "the report fits the title-safe area, 24 px+: %s" % [misses])


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


## A new kaiju through Main by real clicks, then each ending in turn: the run ends that way, the
## end beat is skipped with Enter, the report shows that ending's headline, a click on EVOLVE
## opens the tree and a click on RAMPAGE starts the next. The slot's bests and specimen follow.
func _check_endings_by_input() -> void:
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	root.add_child(main)
	await _frames(3)
	await GuiInput.click(self, GuiInput.button(_screen(main), "NEW KAIJU"))
	await _frames(2)
	await CreationWalk.walk(self, main)
	for reason: String in ENDINGS:
		var rampage := _screen(main) as Rampage
		check(rampage != null, "a rampage is on before '%s'" % reason)
		if rampage == null:
			break
		await rampage.wait_loaded()
		var results := await _end_by(rampage, reason)
		var heading := results.title.text if results != null else "no report"
		check(
			heading == _data_headline(reason),
			"ending '%s' by play shows its headline: %s" % [reason, heading]
		)
		if results == null:
			break
		await GuiInput.key(self, KEY_ENTER)  # SKIP the count
		await GuiInput.click(self, GuiInput.button(results, "EVOLVE"))
		await _frames(2)
		var tree := _screen(main) as UpgradeScreen
		check(tree != null, "EVOLVE after '%s' opens the tree" % reason)
		if tree == null:
			break
		await GuiInput.click(self, GuiInput.button(tree, "RAMPAGE"))
		await _frames(2)
	_slot_after_endings()
	main.queue_free()
	await _frames(2)


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
	await _frames(RampageHud.BEAT_MIN_FRAMES + 2)
	await GuiInput.key(self, KEY_ENTER)
	await _frames(2)
	return GuiInput.find_script(rampage, ResultsScreen) as ResultsScreen


## After the four endings: four rampages banked with every new best key, three deaths.
func _slot_after_endings() -> void:
	var save := SaveFile.load_game(1)
	var best: Dictionary = save.get("best", {})
	check(
		Num.i(save.get("runs", 0)) == ENDINGS.size() and best.has("landmarks") and best.has("agents"),
		"slot 1 banked every run with the new bests: runs %s, best %s" % [save.get("runs"), best]
	)
	check(
		Num.i(save.get("specimen", 0)) == 4,
		"three deaths make the fourth specimen: %s" % save.get("specimen")
	)
