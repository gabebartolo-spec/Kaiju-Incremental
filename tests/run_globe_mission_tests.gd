extends "res://tests/lib/runner.gd"
## Globe mission suite (Overworld plan row G5; D-454): a picked continent's panel and LAUNCH. Ostia
## Minor, Carthago and Thule start their real cities at their stage, the globe hidden, started and
## banked as any rampage (RunStart, SaveFile.bank), the results shown, then WIN / LOSE; the rest
## open the stand-in mission. One save between the globe and its host. Seeded, no clock.
##   godot --headless --path . --script tests/run_globe_mission_tests.gd

const GLOBE := "res://scenes/globe_view.tscn"
const RUBBLE := 40  # the test city's biomass


func suite_name() -> String:
	return "Globe missions"


func run_checks() -> void:
	await _t("_check_globe_mission")
	await _t("_check_globe_real_cities")
	await _t("_check_threat_readout")
	await _t("_check_globe_one_save")


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
	for want: String in ["OSTIA MINOR", "Young croc", "Threat +10%"]:
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
	var readout := _missions(globe).threat_label
	check(readout.text == "Threat 0%", "before the mission Threat reads 0%%: %s" % readout.text)
	var before: Dictionary = globe.save().duplicate(true)
	panel.launch_button().pressed.emit()
	await _past_card(globe, before)
	var city := _missions(globe).city
	check(not readout.visible, "no Threat readout while the city plays")
	check(city != null and not globe.visible, "LAUNCH starts Ostia Minor's city, the globe hidden")
	if city == null:
		return
	check(not mission.visible, "no WIN / LOSE while the city plays")
	await city.wait_loaded()
	check(str(city.sim.stats.get("continent", "")) == id, "the rampage plays Ostia Minor's city")
	_expect_run_setup(globe, city, before)
	# The first city is lost to the army (a death), the second falls (none).
	var reason := "city_fallen" if won else "defeated"
	var result := {"rubble": RUBBLE, "reason": reason, "toppled": 3}
	city.finished.emit(result)
	await process_frame
	await process_frame
	_expect_banked(globe, before, result)
	var results := _missions(globe).results
	check(results != null and results.is_inside_tree(), "the city's results show (DESIGN Loop)")
	check(not globe.visible and not mission.visible, "the results first, over the wrecked city")
	if results == null:
		return
	results.continued.emit()
	await process_frame
	await process_frame
	check(globe.visible and _missions(globe).city == null, "the rampage over, the globe is back")
	check(mission.visible and mission.id == id, "the city's end opens Ostia Minor's WIN / LOSE")
	mission.buttons()[0 if won else 1].pressed.emit()
	if won:
		var picks := mission.buttons()
		check(picks.size() == 3, "WIN offers three bonuses, keep one (D-421): %d" % picks.size())
		picks[1].pressed.emit()
	var outcome := "won" if won else "lost"
	var conquered: Array = globe.save().get("conquered", [])
	check(not mission.visible, "%s: the mission closes" % outcome)
	var want: Array = [id] if won else []
	check(conquered == want, "%s: conquered %s" % [outcome, conquered])
	check(globe.locked("carthago") != won, "%s: Carthago is open: %s" % [outcome, won])
	var shown := "Threat %d%%" % roundi(Num.f(globe.save().get("threat", 0.0)))
	var want_text := "Threat 10%" if won else "Threat 0%"
	check(readout.visible, "%s: the Threat readout is back with the globe" % outcome)
	check(
		readout.text == want_text and readout.text == shown,
		"%s: Threat reads %s (save %s): %s" % [outcome, want_text, shown, readout.text]
	)
	check(globe.marker(id).ink() == UiKit.ACCENT, "%s: Ostia Minor's marker stays lit" % outcome)
	if won:
		var bonuses: Dictionary = globe.save()["bonuses"]
		var kept: String = bonuses.get(id, "")
		check(kept == "bonus_ostia_minor_2", "the second bonus is kept: %s" % bonuses)
		check(globe.selected == "" and not panel.visible, "won: the globe flies back out")
	else:
		check(panel.visible and globe.selected == id, "lost: back on Ostia Minor's panel")


## After a death the lab card shows before the city (as Main's next run), the globe hidden;
## read, the city starts and the card is owed no more.
func _past_card(globe: GlobeView, before: Dictionary) -> void:
	var missions := _missions(globe)
	if before.get("lab_card", false) != true:
		check(missions.card == null, "no death last time: no lab card")
		return
	var card := missions.card
	check(card != null and missions.city == null, "a death last time: the lab card first")
	check(not globe.visible, "the lab card hides the globe")
	if card == null:
		return
	card.done.emit()
	await process_frame
	await process_frame
	check(missions.card == null and missions.city != null, "the card read, the city starts")
	var owed: bool = globe.save().get("lab_card", true) == true
	check(not owed, "the lab card is owed no more")


## The city starts as Main starts a run (RunStart): the time of day and weather picked and
## remembered, the clock carried, the whole intro only at a new size.
func _expect_run_setup(globe: GlobeView, city: Rampage, before: Dictionary) -> void:
	var save := globe.save()
	var tier := Num.i(city.sim.stats["size"])
	check(str(save.get("last_time", "")) != "", "the city's time of day is remembered: %s" % save)
	check(str(save.get("last_weather", "")) != "", "the city's weather is remembered")
	check(Num.i(save.get("intro_size", -1)) == tier, "the intro size is the city's: %d" % tier)
	var full := Num.i(before.get("intro_size", -1)) != tier
	check(city.full_intro == full, "the whole intro only at a new size: %s" % city.full_intro)
	var clock := Num.f(before.get("city_seconds", 0.0))
	check(city.city_seconds == clock, "the Taskforce's clock carries in: %s" % city.city_seconds)


## The player effect, banked vs thrown away: the city's biomass, one run and its bests reach the
## save; a death makes the next rise a new specimen and owes the lab card.
func _expect_banked(globe: GlobeView, before: Dictionary, result: Dictionary) -> void:
	var save := globe.save()
	var rubble := Num.i(before.get("rubble", 0)) + RUBBLE
	check(Num.i(save.get("rubble", 0)) == rubble, "the city's biomass is banked: %s" % save)
	var runs := Num.i(before.get("runs", 0)) + 1
	check(Num.i(save.get("runs", 0)) == runs, "the city counts as a run: %s" % save.get("runs"))
	var best: Dictionary = save.get("best", {})
	check(Num.f(best.get("rubble", 0.0)) >= RUBBLE, "the city's bests are kept: %s" % best)
	var reason := str(result["reason"])
	var died := SaveFile.DEATHS.has(reason)
	var specimen := Num.i(before.get("specimen", 1)) + (1 if died else 0)
	check(Num.i(save.get("specimen", 1)) == specimen, "%s: specimen %d" % [reason, specimen])
	var owed: bool = save.get("lab_card", false) == true
	check(owed == died, "a death owes the lab card: %s" % died)


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
	var readout := _missions(globe).threat_label
	var five := "Threat %d%%" % roundi(minf(shares, Campaign.THREAT_CAP))
	check(readout.text == five, "five conquests read %s: %s" % [five, readout.text])
	check(globe.locked("aurelia"), "five conquests: Aurelia stays locked")
	save = Campaign.conquer(save, Content.continent(outside[-1]), "")
	_missions(globe).use_save(save)
	check(readout.text == "Threat 100%", "the sixth conquest reads 100%%: %s" % readout.text)
	check(not globe.locked("aurelia"), "the sixth conquest opens Aurelia (D-422)")
	globe.mission_panel().show_for(Content.continent("ostia_minor"))
	await process_frame
	await process_frame
	var screen := globe.get_viewport().get_visible_rect()
	var box := readout.get_global_rect()
	check(screen.encloses(box), "the readout is on screen: %s in %s" % [box, screen])
	var card := globe.mission_panel().get_global_rect()
	check(not box.intersects(card), "the readout clears the panel: %s vs %s" % [box, card])
	globe.free()


## One save: the globe plays on the save its host hands in; a conquest is written to the slot and
## reaches the host on saved, never a second copy that a later write of the host's would erase.
func _check_globe_one_save() -> void:
	SaveFile.wipe()
	var globe: GlobeView = (load(GLOBE) as PackedScene).instantiate()
	globe.spin = false
	root.add_child(globe)
	var missions := _missions(globe)
	var hosted := SaveFile.new_save("reptilian")
	hosted["rubble"] = 7
	var heard: Array[Dictionary] = []
	missions.saved.connect(func(save: Dictionary) -> void: heard.append(save))
	missions.host(hosted)
	missions.mission.start(Content.continent("ostia_minor"))
	missions.mission.buttons()[0].pressed.emit()
	missions.mission.buttons()[0].pressed.emit()
	check(heard.size() == 1, "the conquest is one write: %d" % heard.size())
	var got: Dictionary = heard[-1] if not heard.is_empty() else {}
	var conquered: Array = got.get("conquered", [])
	check(conquered == ["ostia_minor"], "the host hears the conquest: %s" % [conquered])
	check(Num.i(got.get("rubble", 0)) == 7, "on the host's own save: %s" % got.get("rubble"))
	var disk: Array = SaveFile.load_game().get("conquered", [])
	check(disk == ["ostia_minor"], "the slot holds the conquest: %s" % [disk])
	globe.free()
	SaveFile.wipe()
