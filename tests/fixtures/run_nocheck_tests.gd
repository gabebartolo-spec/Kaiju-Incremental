extends "res://tests/lib/runner.gd"
## A fixture for tools/test_run_tests.sh, not a suite: `_check_empty` runs and makes no
## check, so the run must fail by that name.


func suite_name() -> String:
	return "No-check fixture"


func run_checks() -> void:
	await _t("_check_called")
	await _t("_check_empty")


func _check_called() -> void:
	check(true, "this one runs")


func _check_empty() -> void:
	var nothing: Array[int] = []
	for n: int in nothing:  # an empty loop: its check never runs
		check(n >= 0, "never reached")
