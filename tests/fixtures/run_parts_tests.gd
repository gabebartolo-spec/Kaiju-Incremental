extends "res://tests/lib/runner.gd"
## A fixture for tools/test_run_tests.sh, not a suite (tools/run_tests.sh only finds
## tests/run_*_tests.gd): five calls, one function called twice and one helper. Run whole it
## makes 3 functions and 8 checks; run as the parts parts@1/2 and parts@2/2 the two parts must
## make exactly those between them (tests/lib/functions_ran.gd part()).


func suite_name() -> String:
	return "Parts fixture"


func run_checks() -> void:
	await _t("_check_one")
	await _t("_check_twice", [1])
	await _h("Helper", func() -> void: check(true, "the helper's check"))
	await _t("_check_twice", [2])
	await _t("_check_three")


func _check_one() -> void:
	check(true, "one, first")
	check(true, "one, second")


func _check_twice(n: int) -> void:
	check(n > 0, "twice, call %d" % n)


func _check_three() -> void:
	check(true, "three, first")
	check(true, "three, second")
	check(true, "three, third")
