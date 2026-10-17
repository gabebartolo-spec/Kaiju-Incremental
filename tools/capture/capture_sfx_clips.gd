extends SceneTree
## One autoplayed croc titan rampage at the game camera, with sound, for the SFX listening
## clips (stomp, building fall, breath). Prints "SOUND <frame> <name>" for every sound so the
## clips can be cut around the first of each. Pair with --write-movie (it records the audio).
## Needs a window and the no-focus override.cfg.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --write-movie <dir>/sfx.avi --script tools/capture/capture_sfx_clips.gd

const SECONDS := 20.0
const LEVELS := {"claws": 3, "evolve1": 1, "hide": 1, "scales": 2, "regen": 2}


func _initialize() -> void:
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
	root.add_child(rampage)
	var seen := 0
	for frame: int in roundi(SECONDS * 60):
		await process_frame
		var heard := rampage.sfx.played
		while seen < heard.size():
			print("SOUND %d %s" % [frame, heard[seen]])
			seen += 1
	quit()
