extends "res://tests/lib/runner.gd"
## A fixture for tools/test_run_tests.sh, not a suite: every check passes, but the suite drops two
## objects that count each other, so the engine's exit report names them ("ObjectDB instances were
## leaked", "resources still in use at exit") and the run must fail with that (debt row 2).


## Two of these pointing at each other are never freed.
class Ring:
	extends RefCounted
	var other: Ring


func suite_name() -> String:
	return "Leak fixture"


func run_checks() -> void:
	await _t("_check_ring")


func _check_ring() -> void:
	var first := Ring.new()
	var second := Ring.new()
	first.other = second
	second.other = first
	check(first.other == second and second.other == first, "two objects count each other")
