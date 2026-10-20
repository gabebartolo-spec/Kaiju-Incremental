extends SceneTree
## Ground ripples at game speed, for before/after review: the reptilian walks and stomps
## (footfalls, stomps), then the insectoid fires its Leap Slam. Real autoplayed rampage, no
## overlays but a caption. Pair with --write-movie; needs a window (CI xvfb or off-screen).
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --write-movie <dir>/shockwaves.avi --script tools/capture/capture_shockwaves.gd

const PARTS: Array[Dictionary] = [
	{"label": "FOOTFALLS AND STOMPS (young reptilian)", "species": "reptilian", "seconds": 9.0},
	{"label": "LEAP SLAM (insectoid)", "species": "insectoid", "seconds": 12.0},
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	for part: Dictionary in PARTS:
		await _part(str(part["label"]), str(part["species"]), Num.f(part["seconds"]))
	quit()


func _part(label: String, species_id: String, seconds: float) -> void:
	var species := Content.species_def(species_id)
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades(), {})
	)
	var rampage := Rampage.new()
	rampage.setup(
		species, stats, CityGen.generate(Seeds.make("city", 0), Content.section("city")), 1
	)
	rampage.set_autoplay(true)
	rampage.autoplay_signature = species_id != "reptilian"
	root.add_child(rampage)
	var layer := CanvasLayer.new()
	layer.layer = 10
	var text := UiKit.label(label, UiKit.SIZE_HEAD)
	text.position = Vector2(40, 160)
	layer.add_child(text)
	root.add_child(layer)
	for _i: int in roundi(seconds * 60):
		await process_frame
	rampage.queue_free()
	layer.queue_free()
	await process_frame
