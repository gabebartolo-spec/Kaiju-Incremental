extends RefCounted
## The flow suite's mixer checks (R 8.1, tuning "audio"): the bus layout with its sends, the
## Hero -> Music and Hero -> Bed sidechain ducks, the limiter on Master, and that every sound the
## game plays resolves to a known bus. Moved out of flow_sfx.gd and run_flow_tests.gd, which sit at
## their line caps.

const SFX_DIR := "res://assets/sfx"


static func run(root: Node, check: Callable) -> void:
	var cfg := Content.section("audio")
	_layout(cfg, check)
	_ducks(cfg, check)
	_sounds(cfg, check)
	_players(root, check)


## Every bus in tuning exists, sends to the bus tuning names, and that bus is on its left (Godot
## only sends leftwards); the four bed buses feed Bed, the UI skips every duck.
static func _layout(cfg: Dictionary, check: Callable) -> void:
	var defs: Array = cfg.get("buses", [])
	check.call(defs.size() == 9, "tuning audio lists the 9 buses (found %d)" % defs.size())
	var wrong: Array[String] = []
	for def: Dictionary in defs:
		var at := AudioServer.get_bus_index(str(def["name"]))
		var to := AudioServer.get_bus_index(AudioServer.get_bus_send(at)) if at >= 0 else -1
		if at < 0 or str(AudioServer.get_bus_send(at)) != str(def["send"]) or to >= at:
			wrong.append(
				"%s -> %s" % [def["name"], AudioServer.get_bus_send(at) if at >= 0 else "?"]
			)
	check.call(wrong.is_empty(), "every bus exists and sends to its left as tuned: %s" % [wrong])
	var feeders: Array[String] = []
	for def: Dictionary in defs:
		if str(def["send"]) == "Bed":
			feeders.append(str(def["name"]))
	feeders.sort()
	check.call(
		feeders == ["Ambience", "Crowd", "Debris", "Military"],
		"Debris, Crowd, Military and Ambience route into Bed: %s" % [feeders]
	)
	check.call(
		_compressor("Hero") == null and _compressor("UI") == null,
		"Hero and UI carry no duck: nothing dips them"
	)


## Music and Bed each have a compressor listening to Hero with the tuned numbers; the Bed duck
## is the deeper one (higher ratio, lower threshold) with a release of 600-1000 ms.
static func _ducks(cfg: Dictionary, check: Callable) -> void:
	var ducks: Dictionary = cfg.get("ducks", {})
	var music := _compressor("Music")
	var bed := _compressor("Bed")
	check.call(music != null and bed != null, "Music and Bed each carry a compressor")
	if music == null or bed == null:
		return
	check.call(
		music.sidechain == &"Hero" and bed.sidechain == &"Hero",
		"both ducks are sidechained to Hero: %s, %s" % [music.sidechain, bed.sidechain]
	)
	for pair: Array in [["music", music], ["bed", bed]]:
		var want: Dictionary = ducks.get(pair[0], {})
		var got: AudioEffectCompressor = pair[1]
		check.call(
			(
				is_equal_approx(got.threshold, Num.f(want.get("threshold_db", INF)))
				and is_equal_approx(got.ratio, Num.f(want.get("ratio", INF)))
				and is_equal_approx(got.attack_us, Num.f(want.get("attack_us", INF)))
				and is_equal_approx(got.release_ms, Num.f(want.get("release_ms", INF)))
			),
			"the %s duck applies its tuned threshold, ratio, attack and release" % pair[0]
		)
	check.call(
		bed.ratio > music.ratio and bed.threshold < music.threshold,
		(
			"Bed ducks deeper than Music (ratio %s > %s, threshold %s < %s)"
			% [bed.ratio, music.ratio, bed.threshold, music.threshold]
		)
	)
	check.call(
		bed.release_ms >= 600.0 and bed.release_ms <= 1000.0,
		"Bed's duck lets go over 600-1000 ms (release %s ms)" % bed.release_ms
	)


## Each sound file in assets/sfx has a bus in tuning, and every tuned bus is a real one.
static func _sounds(cfg: Dictionary, check: Callable) -> void:
	var sounds: Dictionary = cfg.get("sounds", {})
	var unrouted: Array[String] = []
	for file: String in DirAccess.get_files_at(SFX_DIR):
		if file.get_extension() == "ogg" and not sounds.has(file.get_basename()):
			unrouted.append(file.get_basename())
	check.call(
		unrouted.is_empty() and not sounds.is_empty(), "every sound file has a bus: %s" % [unrouted]
	)
	var unknown: Array[String] = []
	for sound: String in sounds:
		if AudioServer.get_bus_index(str(sounds[sound])) < 0:
			unknown.append("%s -> %s" % [sound, sounds[sound]])
	check.call(unknown.is_empty(), "every sound's bus is on the mixer: %s" % [unknown])


## The players the game makes: every pool voice, loop and menu or roar player sits on a known
## bus, and a played roar, stomp and toppled tower go to Hero while a dropped part goes to Debris.
static func _players(root: Node, check: Callable) -> void:
	var sfx := Sfx.new(Seeds.make("sfx", 0))
	root.add_child(sfx)
	sfx.live = true
	var heard: Dictionary = {}
	for sound: String in ["roar", "stomp_1", "tank_fire", "rifle_far", "footstep", "ready"]:
		sfx.play(sound)
		heard[sound] = sfx._pool[(sfx._next + sfx._pool.size() - 1) % sfx._pool.size()].bus
	sfx.collapse(true)
	sfx._process(0.0)
	heard["topple"] = sfx._pool[(sfx._next + sfx._pool.size() - 1) % sfx._pool.size()].bus
	sfx.collapse(false)
	sfx._process(0.0)
	heard["drop"] = sfx._pool[(sfx._next + sfx._pool.size() - 1) % sfx._pool.size()].bus
	check.call(
		(
			heard["roar"] == &"Hero"
			and heard["stomp_1"] == &"Hero"
			and heard["topple"] == &"Hero"
			and heard["drop"] == &"Debris"
			and heard["tank_fire"] == &"Military"
			and heard["rifle_far"] == &"Military"
			and heard["footstep"] == &"SFX"
		),
		"roar, stomp and a toppled tower play on Hero, a dropped part on Debris: %s" % [heard]
	)
	check.call(
		sfx._crowd.bus == &"Crowd" and sfx._rotor.bus == &"Military" and sfx._regen.bus == &"SFX",
		"the loops play on their buses: %s %s %s" % [sfx._crowd.bus, sfx._rotor.bus, sfx._regen.bus]
	)
	var routed: Dictionary = Content.section("audio").get("sounds", {})
	var stray: Array[String] = []
	for sound: String in sfx._streams:
		if not routed.has(sound):
			stray.append(sound)
	check.call(stray.is_empty(), "every sound the Sfx loads has a bus: %s" % [stray])
	var roar := Sfx.roar(root)
	Sfx.ui("ui_click")
	check.call(
		roar.bus == &"Hero" and Sfx._ui_player.bus == &"UI",
		(
			"the title roar plays on Hero and a menu click on UI: %s, %s"
			% [roar.bus, Sfx._ui_player.bus]
		)
	)
	roar.free()
	sfx.free()


static func _compressor(bus_name: String) -> AudioEffectCompressor:
	var at := AudioServer.get_bus_index(bus_name)
	for i: int in AudioServer.get_bus_effect_count(at) if at >= 0 else 0:
		var effect := AudioServer.get_bus_effect(at, i)
		if effect is AudioEffectCompressor:
			return effect as AudioEffectCompressor
	return null
