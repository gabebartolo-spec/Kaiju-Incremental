extends "res://tests/lib/runner.gd"
## Scans suite: the per-frame scans that were indexed give exactly the results of the old full
## scans, frame by frame, along recorded camera paths (BuildingFade, LightPool.nearest), and print
## their old and new cost per frame. Headless.
##   godot --headless --path . --script tests/run_scans_tests.gd

const Scans := preload("res://tests/lib/scans.gd")


func suite_name() -> String:
	return "Scans"


func run_checks() -> void:
	await _h("ScansFade", func() -> void: Scans.fade(check))
	await _h("ScansLights", func() -> void: Scans.lights(root, check))
