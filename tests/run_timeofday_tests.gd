extends "res://tests/lib/runner.gd"
## Time-of-day suite (D-145): a rampage's time of day is a seeded random pick that is never the one
## just played, unless the options menu fixes a time; the setting steps Random -> each time ->
## Random, is saved in settings.cfg (an older file reads as Random) and an older save (no last_time)
## still plays; started through the real Main, the pick is kept in the save and is the look in use.
## Seeded by design: TimeOfDay draws from Seeds.make("time_of_day", run); no clock.
##   godot --headless --path . --script tests/run_timeofday_tests.gd

const RUNS := 200
const MAIN_SCENE := "res://scenes/main.tscn"
## Each of the four times should turn up at least this often in RUNS random picks (about 50 each).
const AT_LEAST := 30


func suite_name() -> String:
	return "TimeOfDay"


func run_checks() -> void:
	await _t("_check_never_twice")
	await _t("_check_fixed_setting")
	await _t("_check_setting_steps")
	await _t("_check_settings_file")
	await _t("_check_old_save")
	await _t("_check_through_main")


func _pick_run(last: String, setting: String, run: int) -> String:
	return TimeOfDay.pick(run, last, setting)


func _check_never_twice() -> void:
	var last := ""
	var repeats := 0
	var counts := {}
	var replay: Array[String] = []
	for run: int in RUNS:
		var id := _pick_run(last, TimeOfDay.RANDOM, run)
		if id == last:
			repeats += 1
		counts[id] = Num.i(counts.get(id, 0)) + 1
		replay.append(id)
		last = id
	var again: Array[String] = []
	last = ""
	for run: int in RUNS:
		last = _pick_run(last, TimeOfDay.RANDOM, run)
		again.append(last)
	var times := Content.times()
	var lowest := RUNS
	for id: Variant in times:
		lowest = mini(lowest, Num.i(counts.get(str(id), 0)))
	check(
		repeats == 0,
		"over %d seeded runs no time of day follows itself (%d repeats)" % [RUNS, repeats]
	)
	check(
		counts.size() == times.size() and lowest >= AT_LEAST,
		"all %d times turn up, the rarest %d of %d times: %s" % [times.size(), lowest, RUNS, counts]
	)
	check(replay == again, "the same save replays the same times (seeded by run number)")
	check(
		times.has(_pick_run("", TimeOfDay.RANDOM, 0)) and times.has(_pick_run("nonsense", "", 3)),
		"a first run (no last time) and an unknown last time still pick a real time"
	)


func _check_fixed_setting() -> void:
	var wrong := 0
	for id: Variant in Content.times():
		for run: int in 50:
			# Even when it is the time just played: a fixed setting is always honoured.
			if (
				_pick_run(str(id), str(id), run) != str(id)
				or _pick_run("", str(id), run) != str(id)
			):
				wrong += 1
	check(
		wrong == 0, "a fixed time is every run's time, even right after itself (%d wrong)" % wrong
	)
	check(
		not Content.times().has("midnight") and _pick_run("night", "midnight", 5) != "night",
		"an unknown setting counts as Random: it still never repeats the last time"
	)


func _check_setting_steps() -> void:
	var steps: Array[String] = []
	var setting := TimeOfDay.RANDOM
	for _i: int in Content.times().size() + 1:
		steps.append(setting)
		setting = TimeOfDay.next(setting)
	var expected: Array[String] = [TimeOfDay.RANDOM]
	for id: Variant in Content.times():
		expected.append(str(id))
	check(
		steps == expected and setting == TimeOfDay.RANDOM,
		"the options button steps Random, then each time, then back to Random: %s" % [steps]
	)
	check(
		TimeOfDay.label(TimeOfDay.RANDOM) == "Random" and TimeOfDay.label("night") == "Night",
		"the button reads Random (the default) or the time's name from data"
	)
	var unlabelled := Content.times().filter(
		func(id: Variant) -> bool: return TimeOfDay.label(str(id)).is_empty()
	)
	check(unlabelled.is_empty(), "every time of day has a label in data/looks.json")
	check(
		TimeOfDay.clean("night") == "night" and TimeOfDay.clean("bogus") == TimeOfDay.RANDOM,
		"a saved setting keeps a known time and turns an unknown one into Random"
	)


func _check_settings_file() -> void:
	var kept := PlayerSettings.time_of_day
	PlayerSettings.time_of_day = "morning"
	PlayerSettings.save()
	PlayerSettings.time_of_day = TimeOfDay.RANDOM
	PlayerSettings.load_saved(false)
	var round_trip := PlayerSettings.time_of_day
	# A file from before the setting existed, and one naming a time since removed.
	var cfg := ConfigFile.new()
	cfg.load(PlayerSettings.PATH)
	cfg.erase_section_key("display", "time_of_day")
	cfg.save(PlayerSettings.PATH)
	PlayerSettings.time_of_day = "noon"
	PlayerSettings.load_saved(false)
	var old_file := PlayerSettings.time_of_day
	cfg.set_value("display", "time_of_day", "twilight")
	cfg.save(PlayerSettings.PATH)
	PlayerSettings.time_of_day = "noon"
	PlayerSettings.load_saved(false)
	var unknown := PlayerSettings.time_of_day
	PlayerSettings.time_of_day = kept
	check(
		round_trip == "morning",
		"the chosen time is saved in settings.cfg and loads back: %s" % round_trip
	)
	check(
		old_file == TimeOfDay.RANDOM and unknown == TimeOfDay.RANDOM,
		(
			"an older settings.cfg, or an unknown time in it, loads as Random (%s, %s)"
			% [old_file, unknown]
		)
	)


func _check_old_save() -> void:
	var v1 := {"version": 1, "species": "reptilian", "rubble": 5, "levels": {}, "runs": 2}
	var v2 := SaveFile.new_save("reptilian")
	v2["runs"] = 4
	var ok := true
	for save: Dictionary in [SaveFile.migrate(v1), SaveFile.migrate(v2)]:
		var last := str(save.get("last_time", ""))
		var id := TimeOfDay.pick(Num.i(save["runs"]), last, TimeOfDay.RANDOM)
		ok = ok and last == "" and Content.times().has(id)
	check(ok, "a v1 and a v2 save without last_time load and still pick a time to play")
	var with_time := v2.duplicate()
	with_time["last_time"] = "night"
	check(
		str(SaveFile.migrate(with_time)["last_time"]) == "night",
		"a save that has last_time keeps it through migrate"
	)


## The real Main: Continue on a fresh save starts a rampage, whose time is kept in the save as
## last_time and is the look in use; the next start differs; a fixed setting repeats.
func _check_through_main() -> void:
	var kept := PlayerSettings.time_of_day
	var seen: Array[String] = []
	for setting: String in [TimeOfDay.RANDOM, TimeOfDay.RANDOM, "noon", "noon"]:
		PlayerSettings.time_of_day = setting
		# The first run starts a fresh save; each next one starts from what the last one saved.
		SaveFile.save_game(
			SaveFile.new_save("reptilian") if seen.is_empty() else SaveFile.load_game()
		)
		var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
		root.add_child(main)
		await process_frame
		await process_frame
		main.call("_continue")  # a save with no rampage yet starts one
		seen.append(str(SaveFile.load_game().get("last_time", "")))
		var table := Content.time_table()
		var expected := str(Look.color("sky_top").to_html(false))
		var own: Dictionary = table[seen[-1]]
		var matches := not own.has("sky_top") or expected == str(own["sky_top"]).trim_prefix("#")
		check(
			Content.times().has(seen[-1]) and matches,
			"starting a rampage (%s) keeps %s in the save and shows its sky" % [setting, seen[-1]]
		)
		main.queue_free()
		await process_frame
		await process_frame
	PlayerSettings.time_of_day = kept
	check(seen[0] != seen[1], "the second rampage's time is not the first's: %s" % [seen])
	check(
		seen[2] == "noon" and seen[3] == "noon", "a fixed noon plays noon every time: %s" % [seen]
	)
