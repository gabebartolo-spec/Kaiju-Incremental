extends "res://tests/lib/runner.gd"
## Planted defect for the Phase 0 gate audit: a suite with no line in tests/expected_checks.txt.


func suite_name() -> String:
	return "Audit"


func run_checks() -> void:
	check(true, "audit placeholder")
