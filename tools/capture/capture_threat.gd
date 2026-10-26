extends SceneTree
## The threat bar and the in-play news crawl as the player meets them (D-259), for the director's
## clip: a seed-0 young croc rampage plays on autoplay until the army escalates and the bar
## gains its second segment
## to 2 (no state is set: the city falls by play); the crawl slides up with the line. Prints the
## movie frame of the rise ("THREAT_RISE frame=N") so the clip is cut around it. With --card it
## saves a still of the lab card (SpecimenCard, K-02 after K-01 died) instead.
## Needs a window and the no-focus override.cfg (Kit.window_ok).
##
##   godot --path . --resolution 3840x2160 --windowed --fixed-fps 60 \
##     --write-movie <dir>/threat.avi --script tools/capture/capture_threat.gd
##   godot --path . --resolution 3840x2160 --windowed --script tools/capture/capture_threat.gd \
##     -- --card --out=<dir>

const Kit := preload("res://tools/capture/capture_kit.gd")
## Play at most this long for the rise, then this long after it (frames at 60 fps).
const PLAY_CAP := 60 * 60
const AFTER_RISE := 60 * 5

var _frame := 0


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	_frame += 1
	return false


func _run() -> void:
	await process_frame
	if not Kit.window_ok():
		quit(1)
		return
	var opts := Kit.args({"card": false, "out": OS.get_user_data_dir()})
	if opts["card"]:
		await _card(str(opts["out"]))
		return
	PlayerSettings.controls_seen = true
	var rampage := Kit.rampage("reptilian", Kit.stats("reptilian", Kit.STAGE_LEVELS[0]), 0)
	root.add_child(rampage)
	await rampage.wait_loaded()
	rampage.set_autoplay(true)
	for _i: int in PLAY_CAP:
		if rampage.sim.news.level >= 2 or rampage.sim.over:
			break
		await process_frame
	print("THREAT_RISE frame=%d level=%d" % [_frame, rampage.sim.news.level])
	await Kit.frames(self, AFTER_RISE)
	quit()


func _card(out: String) -> void:
	var card := SpecimenCard.new(2)
	root.add_child(card)
	await Kit.frames(self, 20)
	print("CARD ", Kit.still(self, out, "lab_card_k02"))
	quit()
