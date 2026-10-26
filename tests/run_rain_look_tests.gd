extends "res://tests/lib/runner.gd"
## Rain look suite (atmosphere, M1 weather looks): rain is many faint, fine streaks in three
## depth layers (near, mid, far) under a heavy veil, with plenty of mist puffs, not a few bright
## lines. Numbers from data/tuning.json "rain".
##   godot --headless --path . --script tests/run_rain_look_tests.gd


func suite_name() -> String:
	return "Rain look"


func run_checks() -> void:
	await _t("_check_rain_is_heavy")


func _check_rain_is_heavy() -> void:
	var cfg := Content.section("rain")
	var rows: Array = cfg["layers"]
	check(rows.size() == 3, "rain has three depth layers: %d" % rows.size())
	var total := 0
	var longest := 0.0
	for row_any: Variant in rows:
		var row: Dictionary = row_any
		total += Num.i(row["streaks"])
		longest = maxf(longest, Num.f(row["len"]))
		check(
			Num.f(row["alpha"]) >= Num.f(cfg["min_streak_alpha"]),
			(
				"%s streaks alpha %.2f is at least %.2f (faint, many)"
				% [row["name"], Num.f(row["alpha"]), Num.f(cfg["min_streak_alpha"])]
			)
		)
		check(
			Num.f(row["width"]) >= 0.0005,
			(
				"%s streaks are at least 0.05%% of the screen height thick (a 1 px floor in the shader)"
				% row["name"]
			)
		)
	var near: Dictionary = rows[0]
	var far: Dictionary = rows[2]
	check(
		Num.f(near["len"]) >= 0.02 and Num.f(near["len"]) <= 0.04,
		"near streaks are 2-4%% of the screen height (%.3f)" % Num.f(near["len"])
	)
	check(
		(
			Num.f(near["width"]) > Num.f(far["width"])
			and Num.f(near["alpha"]) > Num.f(far["alpha"])
			and Num.f(near["speed_mul"]) > Num.f(far["speed_mul"])
		),
		"near streaks are thicker, a little brighter and faster than far"
	)
	check(total >= 60000, "at least 60000 streaks in all (%d)" % total)
	check(Num.i(cfg["splashes"]) >= 8000, "at least 8000 mist puffs (%d)" % Num.i(cfg["splashes"]))
	check(
		Num.f(cfg["tint_white"]) >= 0.7,
		"streaks are lifted well toward white (%.2f)" % Num.f(cfg["tint_white"])
	)
	var rain := WeatherView.layer_of("rain")
	check(
		Num.f(rain["fog_mul"]) >= 2.0 and Num.f(rain["wet"]) >= 0.9,
		"rain has a heavy veil and wet streets"
	)
