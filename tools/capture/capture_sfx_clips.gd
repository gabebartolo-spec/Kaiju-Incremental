extends SceneTree
## One autoplayed croc titan rampage at the game camera, with sound, for the SFX listening
## clips (stomp, building fall, breath). Prints "SOUND <frame> <name>" for every sound so the
## clips can be cut around the first of each. Pair with --write-movie (it records the audio).
## Needs a window and the no-focus override.cfg. With "-- --army" the kaiju has no armour and
## tanks and helicopters come early and fast (shell hits, not glances) and rooftop squads fire from
## further off, for the army clips.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --write-movie <dir>/sfx.avi --script tools/capture/capture_sfx_clips.gd

const SECONDS := 20.0
const LEVELS := {"claws": 3, "evolve1": 1, "hide": 1, "scales": 2, "regen": 2}
const ARMY_LEVELS := {"claws": 3, "evolve1": 1}


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var army := OS.get_cmdline_user_args().has("--army")
	var species := Content.species_def("reptilian")
	var levels: Dictionary = ARMY_LEVELS if army else LEVELS
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades(), levels)
	)
	var rampage := Rampage.new()
	rampage.setup(
		species, stats, CityGen.generate(Seeds.make("city", 0), Content.section("city")), 1
	)
	rampage.set_autoplay(true)
	if army:
		rampage.sim.army["start_interval"] = 1.0
		rampage.sim.army["min_interval"] = 1.0
		rampage.sim.army["speed"] = 12.0
		rampage.sim.air.cfg["max"] = 3
		rampage.sim.air.cfg["after_chunks"] = 0
		rampage.sim.air.cfg["max_per_chunks"] = 1
		rampage.sim.army["rooftop"]["range"] = 60.0
	root.add_child(rampage)
	var seen := 0
	for frame: int in roundi(SECONDS * 60):
		await process_frame
		var heard := rampage.sfx.played
		while seen < heard.size():
			print("SOUND %d %s" % [frame, heard[seen]])
			seen += 1
	quit()
