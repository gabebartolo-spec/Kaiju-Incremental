extends "res://tests/lib/runner.gd"
## Weather suite (D-155): a rampage's weather is a seeded random pick that is never the one just
## played, unless the options menu fixes one; the setting steps Random -> each weather -> Random,
## is saved in settings.cfg (an older file reads as Random); the pick is kept in the save as
## last_weather (an older save without it still plays) and is the run's one current weather,
## Content.weather_id(); the options row steps it by a real click.
## Seeded by design: Weather draws from Seeds.make("weather", run); no clock.
##   godot --headless --path . --script tests/run_weather_tests.gd

const GuiInput := preload("res://tests/lib/gui_input.gd")
const RUNS := 200
const MAIN_SCENE := "res://scenes/main.tscn"
## Each of the five weathers should turn up at least this often in RUNS random picks (about 40).
const AT_LEAST := 20


func suite_name() -> String:
	return "Weather"


func run_checks() -> void:
	await _t("_check_never_twice")
	await _t("_check_fixed_setting")
	await _t("_check_setting_steps")
	await _t("_check_settings_file")
	await _t("_check_old_save")
	await _t("_check_options_row")
	await _t("_check_through_main")


func _sequence(setting: String) -> Array[String]:
	var out: Array[String] = []
	var last := ""
	for run: int in RUNS:
		last = Weather.pick(run, last, setting)
		out.append(last)
	return out


func _check_never_twice() -> void:
	var seq := _sequence(Weather.RANDOM)
	var repeats := 0
	var counts := {}
	for i: int in seq.size():
		counts[seq[i]] = Num.i(counts.get(seq[i], 0)) + 1
		if i > 0 and seq[i] == seq[i - 1]:
			repeats += 1
	var all := Content.weathers()
	var lowest := RUNS
	for id: Variant in all:
		lowest = mini(lowest, Num.i(counts.get(str(id), 0)))
	check(all.size() == 5, "the weathers are clear, overcast, rain, fog and thunderstorm: %s" % [all])
	check(repeats == 0, "over %d seeded runs no weather follows itself (%d repeats)" % [RUNS, repeats])
	check(
		counts.size() == all.size() and lowest >= AT_LEAST,
		"all %d weathers turn up, the rarest %d of %d: %s" % [all.size(), lowest, RUNS, counts]
	)
	check(seq == _sequence(Weather.RANDOM), "the same save replays the same weather (seeded by run)")
	check(
		all.has(Weather.pick(0, "", Weather.RANDOM)) and all.has(Weather.pick(3, "nonsense", "")),
		"a first run (no last weather) and an unknown last weather still pick a real one"
	)


func _check_fixed_setting() -> void:
	var wrong := 0
	for id: Variant in Content.weathers():
		for run: int in 50:
			# Even when it is the weather just played: a fixed setting is always honoured.
			if (
				Weather.pick(run, str(id), str(id)) != str(id)
				or Weather.pick(run, "", str(id)) != str(id)
			):
				wrong += 1
	check(
		wrong == 0,
		"a fixed weather is every run's weather, even right after itself (%d wrong)" % wrong
	)
	check(
		not Content.weathers().has("hail") and Weather.pick(5, "rain", "hail") != "rain",
		"an unknown setting counts as Random: it still never repeats the last weather"
	)


func _check_setting_steps() -> void:
	var steps: Array[String] = []
	var setting := Weather.RANDOM
	for _i: int in Content.weathers().size() + 1:
		steps.append(setting)
		setting = Weather.next(setting)
	var expected: Array[String] = [Weather.RANDOM]
	for id: Variant in Content.weathers():
		expected.append(str(id))
	check(
		steps == expected and setting == Weather.RANDOM,
		"the options button steps Random, then each weather, then back to Random: %s" % [steps]
	)
	check(
		Weather.label(Weather.RANDOM) == "Random each rampage" and Weather.label("fog") == "Fog banks",
		"the button reads Random (the default) or the weather's name from data"
	)
	var unlabelled := Content.weathers().filter(
		func(id: Variant) -> bool: return Weather.label(str(id)).is_empty()
	)
	check(unlabelled.is_empty(), "every weather has a label in data/looks.json")
	check(
		Weather.clean("rain") == "rain" and Weather.clean("bogus") == Weather.RANDOM,
		"a saved setting keeps a known weather and turns an unknown one into Random"
	)


func _check_settings_file() -> void:
	var kept := PlayerSettings.weather
	PlayerSettings.weather = "fog"
	PlayerSettings.save()
	PlayerSettings.weather = Weather.RANDOM
	PlayerSettings.load_saved(false)
	var round_trip := PlayerSettings.weather
	# A file from before the setting existed, and one naming a weather since removed.
	var cfg := ConfigFile.new()
	cfg.load(PlayerSettings.PATH)
	cfg.erase_section_key("display", "weather")
	cfg.save(PlayerSettings.PATH)
	PlayerSettings.weather = "rain"
	PlayerSettings.load_saved(false)
	var old_file := PlayerSettings.weather
	cfg.set_value("display", "weather", "hail")
	cfg.save(PlayerSettings.PATH)
	PlayerSettings.weather = "rain"
	PlayerSettings.load_saved(false)
	var unknown := PlayerSettings.weather
	PlayerSettings.weather = kept
	check(
		round_trip == "fog",
		"the chosen weather is saved in settings.cfg and loads back: %s" % round_trip
	)
	check(
		old_file == Weather.RANDOM and unknown == Weather.RANDOM,
		(
			"an older settings.cfg, or an unknown weather in it, loads as Random (%s, %s)"
			% [old_file, unknown]
		)
	)


func _check_old_save() -> void:
	var old := SaveFile.new_save("reptilian")
	old["runs"] = 4
	var last := str(SaveFile.migrate(old).get("last_weather", ""))
	check(
		last == "" and Content.weathers().has(Weather.pick(4, last, Weather.RANDOM)),
		"a save without last_weather loads (default none) and still picks a weather to play"
	)
	var with_weather := old.duplicate()
	with_weather["last_weather"] = "rain"
	SaveFile.save_game(with_weather)
	check(
		str(SaveFile.load_game()["last_weather"]) == "rain",
		"last_weather survives a save and load round trip"
	)


## The real options menu: clicking the Weather button steps the setting and its text.
func _check_options_row() -> void:
	var kept := PlayerSettings.weather
	PlayerSettings.weather = Weather.RANDOM
	var menu := SettingsMenu.new()
	root.add_child(menu)
	await process_frame
	await process_frame
	var buttons := menu.find_children("*", "Button", true, false).filter(
		func(b: Node) -> bool: return (b as Button).text == "< RANDOM EACH RAMPAGE >"
	)
	check(
		buttons.size() == 2,
		"the options show a time-of-day and a weather button: %d" % buttons.size()
	)
	if buttons.size() == 2:
		var weather: Button = buttons[1]
		await GuiInput.click(self, weather)
		check(
			(
				PlayerSettings.weather == str(Content.weathers()[0])
				and weather.text == "< %s >" % Weather.label(PlayerSettings.weather).to_upper()
			),
			"clicking the weather button steps to the first weather and shows it: %s" % weather.text
		)
	PlayerSettings.weather = kept
	menu.queue_free()
	await process_frame


## The real Main: Continue on a fresh save starts a rampage, whose weather is kept in the save as
## last_weather and is Content.weather_id(); the next start differs; a fixed weather repeats.
func _check_through_main() -> void:
	var kept := PlayerSettings.weather
	var seen: Array[String] = []
	for setting: String in [Weather.RANDOM, Weather.RANDOM, "rain", "rain"]:
		PlayerSettings.weather = setting
		SaveFile.save_game(
			SaveFile.new_save("reptilian") if seen.is_empty() else SaveFile.load_game()
		)
		var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
		root.add_child(main)
		await process_frame
		await process_frame
		main.call("_continue")  # a save with no rampage yet starts one
		seen.append(str(SaveFile.load_game().get("last_weather", "")))
		check(
			Content.weathers().has(seen[-1]) and Content.weather_id() == seen[-1],
			"starting a rampage (%s) keeps %s in the save and as the current weather" % [setting, seen[-1]]
		)
		main.queue_free()
		await process_frame
		await process_frame
	PlayerSettings.weather = kept
	check(seen[0] != seen[1], "the second rampage's weather is not the first's: %s" % [seen])
	check(seen[2] == "rain" and seen[3] == "rain", "a fixed rain plays rain every time: %s" % [seen])
