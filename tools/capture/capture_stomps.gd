extends SceneTree
## A clip of stomps only, at the three stomp-sound tiers (light, heavy, titan), for a listening
## check: the reptilian walks and stomps for a few seconds per tier with its signature held back,
## so nothing else makes a sound. Pair with --write-movie (it records the audio). Needs a window
## and the no-focus override.cfg.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --write-movie <dir>/stomps.avi --script tools/capture/capture_stomps.gd

const Kit := preload("res://tools/capture/capture_kit.gd")
const SECONDS_PER_TIER := 5.0
const TIERS: Array[Dictionary] = [
	{"label": "TIER 1  LIGHT  (no stomp upgrades)", "levels": {}},
	{"label": "TIER 2  HEAVY  (Sharpened Claws 2)", "levels": {"claws": 2}},
	{"label": "TIER 3  TITAN  (Claws 3 + Behemoth)", "levels": {"claws": 3, "evolve1": 1}},
]


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	for tier: Dictionary in TIERS:
		var levels: Dictionary = tier["levels"]
		await _tier(str(tier["label"]), levels)
	quit()


func _tier(label: String, levels: Dictionary) -> void:
	var rampage := Kit.rampage("reptilian", Kit.stats("reptilian", levels), 1)
	rampage.set_autoplay(true)
	rampage.autoplay_signature = false
	root.add_child(rampage)
	var layer := CanvasLayer.new()
	layer.layer = 10
	var text := UiKit.label(label, UiKit.SIZE_HEAD)
	text.position = Vector2(40, 160)
	layer.add_child(text)
	root.add_child(layer)
	await Kit.frames(self, roundi(SECONDS_PER_TIER * 60))
	rampage.queue_free()
	layer.queue_free()
	await process_frame
