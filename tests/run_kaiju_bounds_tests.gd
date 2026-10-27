extends "res://tests/lib/runner.gd"
## Kaiju shadow bounds (render plan item 2, render_opt.kaiju_tight_bounds): the box the croc
## titan's skin gives the engine holds every cube and filler vertex through the idle, walk and
## roar clips at every stage, is at most half the fixed 24 m box when idle, and the flag off keeps
## the fixed box. The cube maths is redone on the CPU from the baked .vskin
## (tests/lib/kaiju_bounds.gd). Render plan item 14 (render_opt.kaiju_three_faces): the cubes are
## drawn as three faces turned to each camera, and that draws every face the eye sees
## (tests/lib/kaiju_three_faces.gd).
##   godot --headless --path . --script tests/run_kaiju_bounds_tests.gd
## Seeded by design: fixed 60 Hz steps, fixed seeds.

const KaijuBounds := preload("res://tests/lib/kaiju_bounds.gd")
const KaijuThreeFaces := preload("res://tests/lib/kaiju_three_faces.gd")


func suite_name() -> String:
	return "Kaiju bounds"


func run_checks() -> void:
	await _t("_check_bounds")
	await _t("_check_three_faces")


func _check_bounds() -> void:
	await _h("KaijuBounds", func() -> void: await KaijuBounds.new(check, root).run())


func _check_three_faces() -> void:
	await _h("KaijuThreeFaces", func() -> void: await KaijuThreeFaces.new(check, root).run())
