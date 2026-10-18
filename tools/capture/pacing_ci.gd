extends "res://tools/pacing.gd"
## tools/pacing.gd on CI (capture.yml runs only tools/capture/ scripts), for when no local Godot
## may run. --green-share=X sets city.green_lot_share first (D-075: the same build paced with
## and without green lots). The table prints to the capture log.
##   tools/capture/ci_capture.sh pacing_ci.gd -- --species=reptilian --green-share=0.0


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--green-share="):
			var city: Dictionary = Content.tuning()["city"]
			city["green_lot_share"] = arg.substr(14).to_float()
			print("pacing with city.green_lot_share ", city["green_lot_share"])
	super._initialize()
