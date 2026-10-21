extends SceneTree
## How many sound voices a heavy autoplayed rampage holds (R 8.2): every frame counts the Sfx
## pool's playing players and how many of them sound a collapse, and notes each time a roar or
## stomp still sounding had its player taken by another sound (a hero voice stolen). Prints one
## summary line; works on the old round-robin pool too, for a before/after pair. Headless.
##
##   godot --headless --path . --fixed-fps 60 --script tools/capture/probe_sfx_voices.gd \
##     -- --species=reptilian --seconds=60

## A hero with more than this left when its player changed sound was cut, not finished.
const CUT_S := 0.1
const HEROES: Array[String] = ["roar", "stomp_0", "stomp_1", "stomp_2", "stomp_crack"]

var _species := "reptilian"
var _seconds := 60.0


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--species="):
			_species = arg.substr(10)
		elif arg.begins_with("--seconds="):
			_seconds = arg.substr(10).to_float()
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var species := Content.species_def(_species)
	var levels := {"claws": 4, "hide": 3, "rage": 3, "quake": 2, "evolve1": 1, "sig_power": 2}
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades(), levels)
	)
	var rampage := Rampage.new()
	rampage.setup(
		species, stats, CityGen.generate(Seeds.make("city", 0), Content.section("city")), 2
	)
	rampage.set_autoplay(true)
	rampage.sim.time_left = _seconds + 10.0
	root.add_child(rampage)
	var sfx := rampage.sfx
	var pool: Array[AudioStreamPlayer] = sfx._pool
	var hero_streams: Array[AudioStream] = []
	for sound: String in HEROES:
		hero_streams.append(sfx._streams[sound])
	var collapse_stream: AudioStream = sfx._streams["collapse"]
	var was: Array[AudioStream] = []
	was.resize(pool.size())
	var left: Array[float] = []  # seconds of the hero's sound still to play, last frame
	left.resize(pool.size())
	var heard := sfx.played.size()
	var most := 0
	var most_collapse := 0
	var sum := 0
	var cut := 0
	var frames := roundi(_seconds * 60.0)
	for _f: int in frames:
		await process_frame
		var busy := 0
		var rubble := 0
		for i: int in pool.size():
			var p := pool[i]
			if was[i] != null and p.stream != was[i] and left[i] > CUT_S:
				cut += 1  # a hero still sounding last frame lost its player to another sound
			was[i] = p.stream if p.playing and p.stream in hero_streams else null
			if was[i] != null:
				left[i] = (p.stream.get_length() - p.get_playback_position()) / p.pitch_scale
			if p.playing:
				busy += 1
				rubble += 1 if p.stream == collapse_stream else 0
		most = maxi(most, busy)
		most_collapse = maxi(most_collapse, rubble)
		sum += busy
	var played := sfx.played.slice(heard)
	var dropped: Variant = sfx.get_indexed(^"voices:dropped")  # null on the old pool
	print(
		(
			(
				"SFX VOICES %s %.0fs: plays %d (collapse %d), voices peak %d mean %.1f of %d,"
				+ " collapse voices peak %d, heroes cut %d, dropped %s, chunks %d"
			)
			% [
				_species,
				_seconds,
				played.size(),
				played.count("collapse"),
				most,
				float(sum) / frames,
				pool.size(),
				most_collapse,
				cut,
				"n/a" if dropped == null else str(dropped),
				rampage.sim.chunks_destroyed,
			]
		)
	)
	quit()
