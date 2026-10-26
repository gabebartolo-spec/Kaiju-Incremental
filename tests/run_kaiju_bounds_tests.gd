extends "res://tests/lib/runner.gd"
## Kaiju shadow bounds (render plan item 2, render_opt.kaiju_tight_bounds): the box the croc
## titan's skin gives the engine holds every cube and filler vertex through the idle, walk and
## roar clips at every stage, is at most half the fixed 24 m box when idle, and the flag off keeps
## the fixed box. The cube maths is redone on the CPU from the baked .vskin
## (tests/lib/kaiju_bounds.gd).
##   godot --headless --path . --script tests/run_kaiju_bounds_tests.gd
## Seeded by design: fixed 60 Hz steps, no random numbers.

const KaijuBounds := preload("res://tests/lib/kaiju_bounds.gd")


func suite_name() -> String:
	return "Kaiju bounds"


func run_checks() -> void:
	await _t("_check_bounds")


func _check_bounds() -> void:
	await _h("KaijuBounds", func() -> void: await KaijuBounds.new(check, root).run())
