extends SceneTree
## The loudest moment the demo can make, for the limiter check (D-050): on a croc Behemoth
## rampage, Atomic Breath, two collapses, three tank shots, a titan stomp with its crack and
## the roar all start together, three times a second apart. Pair with --write-movie (it records
## the master mix) and read the peak with ffmpeg volumedetect. Needs a window and the no-focus
## override.cfg.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --write-movie <dir>/loud.avi --script tools/capture/capture_loud.gd

const STACK: Array[String] = [
	"breath",
	"collapse",
	"collapse",
	"tank_fire",
	"tank_fire",
	"tank_fire",
	"stomp_2",
	"stomp_crack"
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		species,
		UpgradeTree.new(Content.upgrades(), {"claws": 3, "evolve1": 1})
	)
	var rampage := Rampage.new()
	rampage.setup(
		species, stats, CityGen.generate(Seeds.make("city", 0), Content.section("city")), 1
	)
	rampage.autoplay_signature = false
	root.add_child(rampage)
	await _wait(30)
	for _round: int in 3:
		for sound: String in STACK:
			rampage.sfx.play(sound)
		Sfx.roar(rampage)
		await _wait(60)
	await _wait(120)
	quit()


func _wait(frames: int) -> void:
	for _i: int in frames:
		await process_frame
