extends "res://tests/lib/runner.gd"
## Stream-view suite: the building stream follows the camera's view, so no stand-in box shows
## where the camera looks, even through the fastest camera swing and a dash (BuildingStream).
## Headless; real stages 2 and 4 stream under the real camera path in real time.
##   godot --headless --path . --script tests/run_streamview_tests.gd

const StreamView := preload("res://tests/lib/stream_view.gd")


func suite_name() -> String:
	return "StreamView"


func run_checks() -> void:
	await _t("_check_stream_view")


func _check_stream_view() -> void:
	await StreamView.new(check, root).run()
