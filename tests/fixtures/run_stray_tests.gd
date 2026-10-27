extends "res://tests/lib/runner.gd"
## A fixture for tools/test_run_tests.sh, not a suite: run_checks() makes a check outside _t and _h.
## Run whole that is harmless, but run as parts (stray@1/2) the check would run once per part, so
## the part run must fail and say so (tests/lib/functions_ran.gd check_stray()).


func suite_name() -> String:
	return "Stray fixture"


func run_checks() -> void:
	check(true, "a check outside any test function")
	await _t("_check_only")


func _check_only() -> void:
	check(true, "the one call")
