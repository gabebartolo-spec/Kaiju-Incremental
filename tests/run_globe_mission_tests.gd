extends "res://tests/lib/runner.gd"
## Globe mission suite (Overworld plan row G5; D-454): a picked continent's panel and LAUNCH. Ostia
## Minor, Carthago and Thule start their real cities at their stage, the globe hidden, and the
## rampage's end comes back on WIN / LOSE; the rest open the stand-in mission. Seeded, no clock.
##   godot --headless --path . --script tests/run_globe_mission_tests.gd

const GLOBE := "res://scenes/globe_view.tscn"


func suite_name() -> String:
	return "Globe missions"


func run_checks() -> void:
	await _t("_check_globe_mission")
	await _t("_check_globe_real_cities")
	await _t("_check_threat_readout")
	await _t("_check_threat_plate")
	await _t("_check_panel_threat_line")
	await _t("_check_returns_to_host")
	await _t("_check_main_flow")
	await _t("_check_start_and_banking")


## The globe's mission flow (GlobeMissions), the scene's child.
func _missions(globe: GlobeView) -> GlobeMissions:
	for child: Node in globe.get_children():
		if child is GlobeMissions:
			return child as GlobeMissions
	return null


## Turns the globe so a point in its own frame faces the camera.
func _face(globe: GlobeView, local: Vector3) -> void:
	globe.yaw = -atan2(local.x, local.z)
	globe.set_tilt(asin(local.y))
	globe._process(0.0)


func _click(globe: GlobeView, at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = at
		globe._unhandled_input(click)


## Plan row G5 (director 2026-11-01: right side column, Win/Lose stub + pick), on vs off. A click on
## Ostia Minor opens its panel: name, stage, Threat and its bonuses in plain words. LAUNCH starts
## its city, whose end opens the stub mission; LOSE comes back to the panel with nothing changed.
## Launched again, WIN shows the three bonuses; keeping the second conquers Ostia Minor with it, the
## globe flies out and Carthago opens.
func _check_globe_mission() -> void:
	var globe: GlobeView = (load(GLOBE) as PackedScene).instantiate()
	globe.spin = false
	root.add_child(globe)
	var panel := globe.mission_panel()
	check(not panel.visible, "no panel before a pick")
	var id := "ostia_minor"
	_face(globe, globe.anchor_of(id))
	_click(globe, globe.camera().unproject_position(globe.surface_global(globe.anchor_of(id))))
	var words := _texts(panel)
	check(panel.visible and panel.id == id, "a click on Ostia Minor opens its panel")
	var add := Num.i(Content.continent(id)["threat"])
	var line := "Threat +%d%% (to %d%%)" % [add, add]
	for want: String in ["OSTIA MINOR", "Young croc", line]:
		check(words.has(want), "the panel reads '%s': %s" % [want, words])
	check(words.has("Stomps hit 15% harder"), "a bonus reads in plain words: %s" % [words])
	await process_frame
	var screen := globe.get_viewport().get_visible_rect()
	var card := panel.get_global_rect()
	check(
		card.size.y < screen.size.y / 2.0,
		"the card fits its lines (D-432): %s in %s" % [card, screen]
	)
	check(screen.encloses(card), "the card is on screen: %s in %s" % [card, screen])
	for won: bool in [false, true]:
		await _play(globe, won)
	globe.free()


## LAUNCH starts Ostia Minor's real city (D-454): a rampage at its stage, the globe hidden; when it
## is over the globe returns on WIN / LOSE. Then WIN and the second bonus, or LOSE; checks the save
## and the globe after.
func _play(globe: GlobeView, won: bool) -> void:
	var id := "ostia_minor"
	var panel := globe.mission_panel()
	var mission := globe.mission()
	var readout := _missions(globe).threat
	var share := Num.i(Content.continent(id)["threat"])  # Ostia Minor's share (data, D-422)
	var at_start := "%d%%" % 0
	check(
		readout.value_text() == at_start,
		"before the mission Threat reads 0%%: %s" % readout.value_text()
	)
	panel.launch_button().pressed.emit()
	var city := _missions(globe).city
	check(not readout.visible, "no Threat readout while the city plays")
	check(city != null and not globe.visible, "LAUNCH starts Ostia Minor's city, the globe hidden")
	if city == null:
		return
	check(not mission.visible, "no WIN / LOSE while the city plays")
	await city.wait_loaded()
	check(str(city.sim.stats.get("continent", "")) == id, "the rampage plays Ostia Minor's city")
	# A city is a normal rampage (D-462): its result banks into the save, and its results show over
	# the wrecked city before the WIN / LOSE.
	var save := globe.save()
	var rubble_before := Num.i(save.get("rubble", 0))
	var runs_before := Num.i(save.get("runs", 0))
	city.finished.emit({"rubble": 40, "reason": "hunted"})
	await process_frame
	await process_frame
	check(
		Num.i(save.get("rubble", 0)) == rubble_before + 40,
		"the city's rubble banks: %s -> %s" % [rubble_before, save.get("rubble")]
	)
	check(Num.i(save.get("runs", 0)) == runs_before + 1, "the city counts as a run")
	var best: Dictionary = save.get("best", {})
	check(Num.f(best.get("rubble", 0.0)) >= 40.0, "the city sets the bests")
	var shown := _missions(globe).results
	check(shown != null and not mission.visible, "the results show before WIN / LOSE")
	if shown != null:
		shown.continued.emit()
	await process_frame
	await process_frame
	check(globe.visible and _missions(globe).city == null, "the rampage over, the globe is back")
	check(mission.visible and mission.id == id, "the city's end opens Ostia Minor's WIN / LOSE")
	mission.buttons()[0 if won else 1].pressed.emit()
	if won:
		var picks := mission.buttons()
		check(picks.size() == 3, "WIN offers three bonuses, keep one (D-421): %d" % picks.size())
		picks[1].pressed.emit()
	var result := "won" if won else "lost"
	var conquered: Array = globe.save().get("conquered", [])
	check(not mission.visible, "%s: the mission closes" % result)
	var want: Array = [id] if won else []
	check(conquered == want, "%s: conquered %s" % [result, conquered])
	check(globe.locked("carthago") != won, "%s: Carthago is open: %s" % [result, won])
	var shown_text := "%d%%" % floori(Num.f(globe.save().get("threat", 0.0)))
	var want_text := "%d%%" % (share if won else 0)
	check(readout.visible, "%s: the Threat readout is back with the globe" % result)
	check(
		readout.value_text() == want_text and readout.value_text() == shown_text,
		"%s: Threat reads %s (save %s): %s" % [result, want_text, shown_text, readout.value_text()]
	)
	check(globe.marker(id).ink() == UiKit.ACCENT, "%s: Ostia Minor's marker stays lit" % result)
	if won:
		var bonuses: Dictionary = globe.save()["bonuses"]
		var kept: String = bonuses.get(id, "")
		check(kept == "bonus_ostia_minor_2", "the second bonus is kept: %s" % bonuses)
		check(globe.selected == "" and not panel.visible, "won: the globe flies back out")
	else:
		check(panel.visible and globe.selected == id, "lost: back on Ostia Minor's panel")


## Every Label's text under a node.
func _texts(node: Node) -> Array[String]:
	var out: Array[String] = []
	for child: Node in node.find_children("*", "Label", true, false):
		out.append((child as Label).text)
	return out


## D-454: LAUNCH starts the real city where one exists, at the continent's stage, each its own
## street plan; the rest keep the stand-in mission.
func _check_globe_real_cities() -> void:
	var real: Array[String] = []
	for def: Dictionary in Content.continents():
		if Campaign.real_city(def):
			real.append(str(def["id"]))
	check(real == ["ostia_minor", "carthago", "thule"], "real cities: %s" % [real])
	var kinds := {}
	for id: String in real:
		var def := Content.continent(id)
		var stats := Campaign.city_stats({"size": 3}, def)
		var want := Num.i(def["stage"]) + 1
		check(Num.i(stats["size"]) == want, "%s plays at its stage: %s" % [id, stats["size"]])
		var city: Dictionary = CityGrowth.for_stats(stats)["city"]
		var layout: Dictionary = city.get("layout", {})
		kinds[id] = str(layout.get("kind", "bay"))
	check(str(kinds["carthago"]) == "cothon", "Carthago is the cothon harbour: %s" % [kinds])
	check(str(kinds["thule"]) == "fjord", "Thule is the fjord: %s" % [kinds])
	check(
		not str(kinds["ostia_minor"]) in ["cothon", "fjord"],
		"Ostia Minor is today's bay: %s" % [kinds]
	)
	var globe: GlobeView = (load(GLOBE) as PackedScene).instantiate()
	globe.spin = false
	root.add_child(globe)
	globe.mission_panel().show_for(Content.continent("silvania"))
	globe.mission_panel().launch_button().pressed.emit()
	check(_missions(globe).city == null, "Silvania has no real city yet: no rampage")
	check(globe.mission().visible, "Silvania opens the stand-in WIN / LOSE")
	globe.free()


## D-422, the value the player sees: five conquests before the capital read their summed shares
## (under the 99% cap) with Aurelia locked; the sixth sets 100% and opens Aurelia. The readout is on
## screen and clear of the mission panel.
func _check_threat_readout() -> void:
	var globe: GlobeView = (load(GLOBE) as PackedScene).instantiate()
	globe.spin = false
	root.add_child(globe)
	var save := {"conquered": [], "bonuses": {}, "threat": 0.0}
	var outside: Array[String] = []
	for def: Dictionary in Content.continents():
		if not def.get("capital", false):
			outside.append(str(def["id"]))
	var shares := 0.0
	for id: String in outside.slice(0, outside.size() - 1):
		save = Campaign.conquer(save, Content.continent(id), "")
		shares += Num.f(Content.continent(id)["threat"])
	_missions(globe).use_save(save)
	var readout := _missions(globe).threat
	var five := "%d%%" % floori(minf(shares, Campaign.THREAT_CAP))
	check(
		readout.value_text() == five, "five conquests read %s: %s" % [five, readout.value_text()]
	)
	check(globe.locked("aurelia"), "five conquests: Aurelia stays locked")
	save = Campaign.conquer(save, Content.continent(outside[-1]), "")
	_missions(globe).use_save(save)
	var full := "%d%%" % int(Campaign.THREAT_FULL)
	check(
		readout.value_text() == full,
		"the sixth conquest reads %s: %s" % [full, readout.value_text()]
	)
	check(not globe.locked("aurelia"), "the sixth conquest opens Aurelia (D-422)")
	# The edge: a Threat just under full reads under it (truncated), so 100 shows only once the
	# capital is open (D-422 says 99 at most until then).
	_missions(globe).use_save({"conquered": [], "bonuses": {}, "threat": Campaign.THREAT_CAP + 0.5})
	var edge := "%d%%" % int(Campaign.THREAT_CAP)
	check(
		readout.value_text() == edge,
		"99.5 reads %s, never 100 with Aurelia locked: %s" % [edge, readout.value_text()]
	)
	globe.mission_panel().show_for(Content.continent("ostia_minor"))
	await process_frame
	await process_frame
	var screen := globe.get_viewport().get_visible_rect()
	var box := readout.get_global_rect()
	check(screen.encloses(box), "the readout is on screen: %s in %s" % [box, screen])
	var card := globe.mission_panel().get_global_rect()
	check(not box.intersects(card), "the readout clears the panel: %s vs %s" % [box, card])
	globe.free()


## D-461 (director 2026-11-04), the plate: about 20 px tall, a yellow edge on a plate, label yellow,
## on the safe-margin corner on both axes; the value runs from the ramp's first colour at 0 to its
## last at the cap, redder as it climbs (on vs off: the same plate at 0 and at 99 differs).
func _check_threat_plate() -> void:
	var plate := ThreatReadout.new()
	root.add_child(plate)
	await process_frame
	await process_frame
	var cfg := ThreatReadout.config()
	var tall := plate.get_global_rect().size.y
	check(absf(tall - Num.f(cfg["height"])) <= 2.0, "the plate is about 20 px tall: %s" % tall)
	check(plate.position == UiKit.safe_margin(), "the plate sits on the safe margin, both axes")
	var edge := plate.edge_colour()
	check(edge == UiKit.ACCENT, "the plate's edge is the hazard yellow")
	var ramp: Array = cfg["ramp"]
	var first: Array = ramp[0]
	var last: Array = ramp[-1]
	var calm_colour: Color = ThreatReadout.PALETTE[str(first[1])]
	var alarm_colour: Color = ThreatReadout.PALETTE[str(last[1])]
	check(ThreatReadout.colour_for(0.0) == calm_colour, "calm at 0")
	check(ThreatReadout.colour_for(100.0) == alarm_colour, "alarm at 100")
	check(ThreatReadout.colour_for(100.0) == UiKit.ALERT, "the last stop is alert red")
	var reds := 0
	var prev := ThreatReadout.colour_for(0.0)
	for level: int in range(1, 101):
		var now := ThreatReadout.colour_for(float(level))
		reds += 1 if now.g <= prev.g + 0.0001 and now.r >= prev.r - 0.0001 else 0
		prev = now
	check(reds == 100, "the value never turns calmer as the level climbs: %d" % reds)
	plate.show_level(0.0)
	var calm := plate.value_colour()
	plate.show_level(99.0)
	check(plate.value_colour() != calm, "the value's colour moves with the level")
	check(plate.value_colour().g < calm.g, "at 99 it is redder than at 0")
	plate.free()


## D-461, reconcile: the panel's line says what the conquest adds and where it leaves the corner
## value (the same percent units, out of the cap).
func _check_panel_threat_line() -> void:
	var globe: GlobeView = (load(GLOBE) as PackedScene).instantiate()
	globe.spin = false
	root.add_child(globe)
	var missions := _missions(globe)
	missions.use_save({"conquered": [], "bonuses": {}, "threat": 0.0})
	missions.show_panel("ostia_minor")
	var add := Num.i(Content.continent("ostia_minor")["threat"])
	var want := "Threat +%d%% (to %d%%)" % [add, add]
	check(_texts(globe.mission_panel()).has(want), "the panel reads '%s'" % want)
	var fresh := {"conquered": [], "bonuses": {}, "threat": 0.0}
	var save := Campaign.conquer(fresh, Content.continent("ostia_minor"), "")
	missions.use_save(save)
	missions.show_panel("carthago")
	var more := Num.i(Content.continent("carthago")["threat"])
	var after := "Threat +%d%% (to %d%%)" % [more, add + more]
	check(_texts(globe.mission_panel()).has(after), "the panel reads '%s' after one win" % after)
	globe.free()


## D-462: a mission resolving hands back to the host: WIN (bonus kept) and LOSE each emit
## `returned`; the host's save carries the conquest on a WIN and nothing on a LOSE.
func _check_returns_to_host() -> void:
	for won: bool in [true, false]:
		var globe: GlobeView = (load(GLOBE) as PackedScene).instantiate()
		globe.spin = false
		root.add_child(globe)
		var seen: Array[bool] = []
		globe.returned().connect(func(w: bool) -> void: seen.append(w))
		globe.use_save({"conquered": [], "bonuses": {}, "threat": 0.0})
		var mission := globe.mission()
		mission.start(Content.continent("silvania"))
		mission.buttons()[0 if won else 1].pressed.emit()
		if won:
			check(seen.is_empty(), "WIN waits for the bonus pick before returning")
			mission.buttons()[0].pressed.emit()
		check(seen == [won], "the host hears %s: %s" % [won, seen])
		var conquered: Array = globe.save().get("conquered", [])
		check(conquered.has("silvania") == won, "conquered %s on won=%s" % [conquered, won])
		globe.free()


## D-462, the game's flow through Main: a new game's creation and Continue both land on the globe;
## a city's WIN or LOSE lands on the TREE, the WIN carrying its conquest and kept bonus into the
## game's save (on vs off: LOSE leaves the save as it was). No file is written for the slot but
## the one this check makes.
func _check_main_flow() -> void:
	for won: bool in [true, false]:
		SaveFile.wipe()
		SaveFile.save_game(SaveFile.new_save("reptilian"))
		var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
		root.add_child(main)
		await process_frame
		await process_frame
		main.call("_continue_slot", 1)
		var shown: Node = main.call("screen")
		var globe := shown as GlobeView
		check(globe != null, "Continue (won=%s) opens the globe, not a run or the tree" % won)
		if globe == null:
			main.queue_free()
			continue
		var mission := globe.mission()
		mission.start(Content.continent("ostia_minor"))
		mission.buttons()[0 if won else 1].pressed.emit()
		if won:
			mission.buttons()[0].pressed.emit()
		await process_frame
		await process_frame
		var current: Node = main.call("screen")
		var tree := current as UpgradeScreen
		var saved := SaveFile.load_game()
		var conquered: Array = saved.get("conquered", [])
		var word := "WIN" if won else "LOSE"
		check(tree != null, "%s lands back on the tree: %s" % [word, current])
		check(conquered.has("ostia_minor") == won, "%s: the save's conquests %s" % [word, conquered])
		var share := Num.f(Content.continent("ostia_minor")["threat"]) if won else 0.0
		check(Num.f(saved.get("threat", 0.0)) == share, "%s: Threat %s" % [word, saved.get("threat")])
		var bonuses: Dictionary = saved.get("bonuses", {})
		check(bonuses.has("ostia_minor") == won, "%s: the kept bonus %s" % [word, bonuses])
		main.queue_free()
		await process_frame
	SaveFile.wipe()


## D-462, the globe is the loop: the tree's START goes to the globe (no plain rampage), and a city
## played from it banks like any rampage into the slot's file (biomass, run, best), then lands on
## the tree. Nothing is banked before the city ends (on vs off).
func _check_start_and_banking() -> void:
	SaveFile.wipe()
	SaveFile.save_game(SaveFile.new_save("reptilian"))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.call("_continue_slot", 1)
	check(main.call("screen") is GlobeView, "Continue opens the globe")
	main.call("_show_tree")
	var now: Node = main.call("screen")
	var tree := now as UpgradeScreen
	check(tree != null, "the tree opens")
	if tree == null:
		main.queue_free()
		return
	tree.start_pressed.emit()
	await process_frame
	await process_frame
	var at: Node = main.call("screen")
	var globe := at as GlobeView
	check(globe != null, "the tree's START opens the globe, not a rampage: %s" % main.call("screen"))
	if globe == null:
		main.queue_free()
		return
	check(Num.i(SaveFile.load_game().get("runs", 0)) == 0, "nothing banked before a city ends")
	globe.mission_panel().show_for(Content.continent("ostia_minor"))
	globe.mission_panel().launch_button().pressed.emit()
	var city := _missions(globe).city
	check(city != null, "LAUNCH starts the city from a hosted globe")
	if city != null:
		await city.wait_loaded()
		city.finished.emit({"rubble": 25, "reason": "hunted"})
		await process_frame
		await process_frame
		var banked := SaveFile.load_game()
		check(Num.i(banked.get("runs", 0)) == 1, "the city banks one run: %s" % banked.get("runs"))
		check(Num.i(banked.get("rubble", 0)) == 25, "the city banks its rubble")
		var shown := _missions(globe).results
		check(shown != null, "its results show")
		if shown != null:
			shown.continued.emit()
			await process_frame
			await process_frame
			globe.mission().buttons()[1].pressed.emit()  # LOSE
			await process_frame
			await process_frame
			check(main.call("screen") is UpgradeScreen, "after the city the player lands on the tree")
	main.queue_free()
	await process_frame
	SaveFile.wipe()
