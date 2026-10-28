extends "res://tests/lib/runner.gd"
## Stream-view suite: the building stream follows the camera's view, so no stand-in box shows
## where the camera looks, even through the fastest camera moves, a walk and a dash
## (BuildingStream).
## Headless; real stages 2 and 3 stream under the real camera path, on a fixed 60 fps clock.
##   godot --headless --path . --script tests/run_streamview_tests.gd

const StreamView := preload("res://tests/lib/stream_view.gd")


func suite_name() -> String:
	return "StreamView"


func run_checks() -> void:
	for stage: int in StreamView.STAGES:
		for group: int in StreamView.GROUPS:
			await _t("_check_stream_view", [stage, group])


func _check_stream_view(stage: int, group: int) -> void:
	await StreamView.new(check, root).run(stage, group)
