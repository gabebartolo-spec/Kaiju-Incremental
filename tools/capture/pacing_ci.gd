extends "res://tools/pacing.gd"
## tools/pacing.gd on CI (capture.yml runs only tools/capture/ scripts), for when no local Godot
## may run. --no-green empties city.green_lot_every first (D-075: the same build paced with and
## without green lots). The table prints to the capture log.
##   tools/capture/ci_capture.sh pacing_ci.gd -- --species=reptilian [--no-green]


func _initialize() -> void:
	if "--no-green" in OS.get_cmdline_user_args():
		var city: Dictionary = Content.tuning()["city"]
		city["green_lot_every"] = []
		print("pacing without green lots")
	super._initialize()
