extends "res://tests/lib/sim_suite.gd"
## Demo-end suite (D-145, D-152, D-153): which rampage ends the demo, the thanks screen's totals
## against the sim's counters, the endless free play and the demo save marker, all headless and
## seeded (tests/lib/sim_demo_end.gd). The screens' real-input checks are in the flow suite.
##   godot --headless --path . --script tests/run_demoend_tests.gd

const SimDemoEnd := preload("res://tests/lib/sim_demo_end.gd")


func suite_name() -> String:
	return "DemoEnd"


func run_checks() -> void:
	await _t("_check_demo_end")


func _check_demo_end() -> void:
	SimDemoEnd.new(check, _sim, _autoplay).run()
