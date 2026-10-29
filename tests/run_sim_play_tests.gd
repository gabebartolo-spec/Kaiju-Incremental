extends "res://tests/lib/sim_suite.gd"
## Sim play suite: the claw swipe scenarios on the headless, seeded sim (SimClawSwipe, the
## slowest part of the old sim suite, ~4.5 of its ~9 min) and the save migration, split out
## of the sim suite so the timing-balanced CI shards run the two halves apart.
## Set-up: tests/lib/sim_suite.gd. Seeded by design: every RampageSim takes Seeds.make(...).
##   godot --headless --path . --script tests/run_sim_play_tests.gd

const SaveScript := preload("res://autoload/save_file.gd")
const SimClawSwipe := preload("res://tests/lib/sim_claw_swipe.gd")
const SwipeWindupTicks := preload("res://tests/lib/swipe_windup_ticks.gd")


func suite_name() -> String:
	return "Sim play"


func run_checks() -> void:
	await _t("_check_save_migrate")
	await _h("SimClawSwipe", func() -> void: SimClawSwipe.new(check, _sim, _autoplay).run())
	await _h("SwipeWindupTicks", func() -> void: SwipeWindupTicks.new(check).run())


func _check_save_migrate() -> void:
	check(
		Num.i(SaveScript.migrate({"version": 1, "rubble": 5}).get("rubble", 0)) == 5,
		"a version 1 save loads"
	)
	check(SaveScript.migrate({"version": 99}).is_empty(), "a save from a newer version is refused")
