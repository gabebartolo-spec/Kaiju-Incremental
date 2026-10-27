extends "res://tests/lib/runner.gd"
## Soft smoke (render plan item 13, tuning render_opt.soft_smoke / soft_smoke_m): smoke and street
## dust share smoke.gdshader; it reads the scene depth under each pixel and fades its alpha over the
## gap, so a puff melts into the roof or street it meets instead of cutting a hard line. The width
## comes from data through a global shader uniform (tests/lib/soft_smoke.gd); the flag off sets it
## to 0 and the shader skips the fade. The headless renderer draws nothing, so this checks the
## shader source, the data, the class that feeds the uniform and the project that declares it.
##   godot --headless --path . --script tests/run_soft_smoke_tests.gd
## Seeded by design: no random numbers.

const SoftSmoke := preload("res://tests/lib/soft_smoke.gd")


func suite_name() -> String:
	return "Soft smoke"


func run_checks() -> void:
	await _t("_check_soft_smoke")


func _check_soft_smoke() -> void:
	await _h("SoftSmoke", func() -> void: SoftSmoke.new(check).run())
