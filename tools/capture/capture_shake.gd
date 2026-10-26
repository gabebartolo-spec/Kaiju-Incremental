extends SceneTree
## A clip of the camera shake (R 19.2) at game speed: a heavy croc (Claws 3 + Behemoth) autoplays
## through the city with its signature held back, so the shake on screen is stomps, toppling
## towers and falling parts. Runs on the old and the new shake alike, for a before/after pair;
## --label= prints a caption at the top left. Needs a window or CI (capture.yml).
##
##   tools/capture/ci_capture.sh --movie capture_shake.gd -- --label=AFTER --out=dir

const SECONDS := 16.0
const LEVELS := {"claws": 3, "evolve1": 1, "quake": 2}

var _label := ""


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--label="):
			_label = arg.substr(8)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades(), LEVELS)
	)
	var rampage := Rampage.new()
	rampage.setup(
		species, stats, CityGen.generate(Seeds.make("city", 0), Content.section("city")), 1
	)
	rampage.set_autoplay(true)
	rampage.autoplay_signature = false
	root.add_child(rampage)
	var layer := CanvasLayer.new()
	layer.layer = 10
	var text := UiKit.label(_label, UiKit.SIZE_HEAD)
	text.position = Vector2(40, 160)
	layer.add_child(text)
	root.add_child(layer)
	var stomps := rampage.stomp_ring_at.size()
	await create_timer(SECONDS).timeout  # game time: the movie's fixed frame clock
	var falls := rampage.sfx.played.count("collapse")
	print(
		(
			"SHAKE CLIP %s: %d stomps, %d collapse sounds in %.0f s"
			% [_label, rampage.stomp_ring_at.size() - stomps, falls, SECONDS]
		)
	)
	quit()
