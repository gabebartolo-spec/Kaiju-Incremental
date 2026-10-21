extends SceneTree
## A two-minute autoplayed croc Behemoth rampage for the mix report (D-050): writes every sound
## the game starts (frame, name, the player's volume dB and pitch) and, every 3 frames, the
## loops' volumes, so tools/sfx/mix_report.py can rebuild one stem per sound category and
## measure it. Pair with --write-movie to keep the real master mix for comparison. Needs a
## window and the no-focus override.cfg.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --write-movie <dir>/mix.avi --script tools/capture/capture_mix_log.gd -- <dir>/mix_log.txt
##   ("-- --out=<dir>" writes <dir>/mix_log.txt instead: the form ci_capture.sh passes)

const SECONDS := 120.0
const LEVELS := {"claws": 3, "evolve1": 1, "hide": 1, "regen": 1}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var log := FileAccess.open(_log_path(), FileAccess.WRITE)
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades(), LEVELS)
	)
	var rampage := Rampage.new()
	rampage.setup(
		species, stats, CityGen.generate(Seeds.make("city", 0), Content.section("city")), 1
	)
	rampage.set_autoplay(true)
	rampage.sim.air.cfg["max"] = 2
	rampage.sim.air.cfg["after_chunks"] = 0
	rampage.sim.time_left = SECONDS + 10.0
	root.add_child(rampage)
	var sfx := rampage.sfx
	sfx.log_voices = true
	var seen := 0
	for frame: int in roundi(SECONDS * 60):
		await process_frame
		while seen < sfx.voice_log.size():
			var voice: Array = sfx.voice_log[seen]
			seen += 1
			log.store_line("SND %d %s %.2f %.4f" % [frame, voice[0], voice[1], voice[2]])
		if frame % 3 == 0:
			var loops: Array[String] = []
			for loop: AudioStreamPlayer in [sfx._regen, sfx._rotor, sfx._crowd]:
				loops.append("%.2f %d" % [loop.volume_db, 1 if loop.playing else 0])
			log.store_line("LOOP %d %s" % [frame, " ".join(loops)])
	log.close()
	quit()


func _log_path() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			return arg.substr(6).path_join("mix_log.txt")
	return OS.get_cmdline_user_args()[0]
