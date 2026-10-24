extends "res://tests/lib/runner.gd"
## City sound suite (D-155 "panic then eerie quiet", D-125 music in layers): the curves in tuning
## "city_sound" shape the mix. One seeded rampage (tests/lib/city_sound_run.gd: a real RampageSim
## played by the scripted player beside a real StreetLife) feeds CitySound; the check reads the
## levels it set: panic (crowd trim, sirens) swells early and fades to nothing, gunfire, fire and
## wind carry the ruined city, and the beds equal the curve at the phase the sim gave. A planted
## bad curve (panic that never fades) fails the same check. The music layer player keeps its
## stems on one bar grid; a planted stem one bar short is caught.
## Seeded by design: Seeds "city", "army" and "civilians" 0, scripted player, fixed DT.
##   godot --headless --path . --script tests/run_city_sound_tests.gd

const Run := preload("res://tests/lib/city_sound_run.gd")
const SECONDS := 100.0
## The panic beds must peak in the first share of the run and fall this far below the peak.
const EARLY := 0.6
const DROP_DB := 25.0

var _run: Run


func suite_name() -> String:
	return "City sound"


func run_checks() -> void:
	await _t("_check_curve_data")
	await _t("_check_phase_and_level_maths")
	await _t("_check_music_data")
	_run = Run.new(self, 1, Run.LATE_BABY)
	await process_frame
	_run.run(SECONDS)
	await _t("_check_panic_then_quiet")
	await _t("_check_levels_follow_the_curve")
	await _t("_check_planted_bad_curve_fails")
	await _t("_check_stems_follow_the_phase")
	_run.finish()
	await _t("_check_music_stems_locked")
	await _t("_check_planted_stem_off_the_grid")


func _cfg() -> Dictionary:
	return Content.section("city_sound")


## Every curve starts at phase 0, ends at 1, climbs in phase order, and stays on the sound's bus.
func _check_curve_data() -> void:
	for bed: String in _cfg()["beds"]:
		var keys: Array = _cfg()["beds"][bed]["curve"]
		var ascending := true
		for i: int in range(1, keys.size()):
			ascending = ascending and Num.f(keys[i][0]) > Num.f(keys[i - 1][0])
		check(ascending, "%s: curve keys run in ascending phase" % bed)
		check(
			Num.f(keys[0][0]) == 0.0 and Num.f(keys[keys.size() - 1][0]) == 1.0,
			"%s: curve covers phase 0 to 1" % bed
		)
		if bed != "crowd":
			check(AudioBuses.of(bed) != &"SFX", "%s plays on a Bed bus, not the dry SFX bus" % bed)
	var silent := Num.f(_cfg()["silent_db"])
	for bed: String in ["crowd", "city_siren"]:
		check(CityCurve.level(bed, 1.0, _cfg()) <= silent + 1.0, "%s is gone by the end" % bed)
	for bed: String in ["city_gunfire", "city_fire", "city_wind"]:
		check(CityCurve.level(bed, 1.0, _cfg()) > silent + 20.0, "%s carries the ruined city" % bed)


func _check_phase_and_level_maths() -> void:
	var cfg := _cfg()
	var full := Num.f(cfg["phase"]["destruction_full"])
	var share := Num.f(cfg["phase"]["fled_full"])
	check(is_zero_approx(CityCurve.phase(0.0, 0, 100.0, cfg)), "no ruin, no one fled: phase 0")
	check(
		is_equal_approx(CityCurve.phase(full, roundi(share * 100.0), 100.0, cfg), 1.0),
		"a city at its full destruction with its full flight is phase 1"
	)
	check(CityCurve.phase(10.0, 1000, 100.0, cfg) == 1.0, "phase is capped at 1")
	check(
		CityCurve.phase(full * 0.5, 0, 100.0, cfg) < CityCurve.phase(full * 0.8, 0, 100.0, cfg),
		"more destruction, later phase"
	)
	var keys := [[0.0, -40.0], [0.5, -20.0], [1.0, 0.0]]
	check(is_equal_approx(CityCurve.along(keys, 0.25), -30.0), "linear between keys")
	check(
		CityCurve.along(keys, -1.0) == -40.0 and CityCurve.along(keys, 2.0) == 0.0,
		"flat past the ends"
	)


## The data names 3 tracks (baby, adolescent, adult city), each 4 stems in fade-in order.
func _check_music_data() -> void:
	var music := Content.section("music")
	var tracks: Array = music["tracks"]
	check(tracks.size() == 3, "one track per city: %d" % tracks.size())
	for row: Dictionary in tracks:
		var names: Array[String] = []
		var last_enter := -1.0
		var ordered := true
		for stem: Dictionary in row["stems"]:
			names.append(str(stem["name"]))
			ordered = ordered and Num.f(stem["enter"]) > last_enter
			last_enter = Num.f(stem["enter"])
		check(",".join(names) == "drums,bass,lead,choir", "%s stems: %s" % [row["id"], names])
		check(ordered, "%s: stems fade in one after another" % row["id"])
		check(
			Num.f(row["bpm"]) > 0.0 and MusicLayers.track_seconds(row) > 60.0,
			"%s: bpm and bars" % row["id"]
		)


## D-155 on the sim's own run: crowd and sirens peak early and are gone by the end, the ruin
## beds end louder than they began.
func _check_panic_then_quiet() -> void:
	var series := _run.samples
	check(series.size() >= int(SECONDS) - 1, "a sample a second: %d" % series.size())
	check(
		Run.panic_then_quiet(series, EARLY, DROP_DB),
		"panic peaks early, then fades to fire, wind, military"
	)
	var last: Dictionary = series[series.size() - 1]
	check(
		Num.f(last["phase"]) > 0.9,
		"the run reached the ruined city: phase %.2f" % Num.f(last["phase"])
	)
	var first_phase := 1.0
	for s: Dictionary in series:
		first_phase = minf(first_phase, Num.f(s["phase"]))
	check(first_phase < 0.1, "and began at the first stomp: phase %.2f" % first_phase)


## The phase never goes back, and once the run ends the beds settle exactly on the curve.
func _check_levels_follow_the_curve() -> void:
	var rising := true
	for i: int in range(1, _run.samples.size()):
		rising = rising and Num.f(_run.samples[i]["phase"]) >= Num.f(_run.samples[i - 1]["phase"])
	check(rising, "phase only grows (destruction and fled never fall)")
	_run.sound.advance(1000.0)  # one long frame: every fade completes at the same phase
	for bed: String in _cfg()["beds"]:
		var want := CityCurve.level(bed, _run.sound.phase, _cfg())
		check(
			is_equal_approx(Num.f(_run.sound.levels[bed]), want),
			"%s settles on its curve (%.1f dB)" % [bed, want]
		)


## The same check on a planted bad curve (sirens rise to the end, the crowd never fades) fails,
## so the check can tell a bad curve from the real one.
func _check_planted_bad_curve_fails() -> void:
	var bad: Dictionary = _cfg().duplicate(true)
	bad["beds"]["city_siren"]["curve"] = [[0.0, -60.0], [1.0, -6.0]]
	bad["beds"]["crowd"]["curve"] = [[0.0, 0.0], [1.0, 0.0]]
	var fake: Array[Dictionary] = []
	for s: Dictionary in _run.samples:
		var levels: Dictionary = {}
		for bed: String in bad["beds"]:
			levels[bed] = CityCurve.level(bed, Num.f(s["phase"]), bad)
		fake.append({"levels": levels})
	check(not Run.panic_then_quiet(fake, EARLY, DROP_DB), "a siren that only rises is caught")
	var real: Array[Dictionary] = []
	for s: Dictionary in _run.samples:
		var levels: Dictionary = {}
		for bed: String in _cfg()["beds"]:
			levels[bed] = CityCurve.level(bed, Num.f(s["phase"]), _cfg())
		real.append({"levels": levels})
	check(Run.panic_then_quiet(real, EARLY, DROP_DB), "the real curve passes on the same phases")


## Music stems follow the same phase: drums first, the choir last, never out of order.
func _check_stems_follow_the_phase() -> void:
	var levels: Array[float] = _run.sound.music.levels
	check(levels.size() == 4, "four stems on the player: %d" % levels.size())
	_run.sound.advance(1000.0)  # phase is ~1: every stem fully in
	for db: float in levels:
		check(is_zero_approx(db), "all stems are fully in at the ruined city: %.1f dB" % db)
	var music := _run.sound.music
	music.follow(0.0, 1000.0)
	check(
		levels.all(func(db: float) -> bool: return db <= -59.0),
		"at the first stomp every stem waits"
	)
	music.follow(0.06, 1000.0)
	check(levels[0] == 0.0 and levels[1] <= -59.0, "the drums start alone: %s" % [levels])
	music.follow(0.6, 1000.0)
	check(levels[0] == 0.0 and levels[1] == 0.0, "by 0.6 the drums and bass are in")
	check(levels[2] > -60.0 and levels[2] < 0.0, "the lead is swelling in: %.1f dB" % levels[2])
	check(levels[3] <= -59.0, "the choir waits for the final stretch")


## Every track's stems share one bar grid, and the player keeps them on one stream.
func _check_music_stems_locked() -> void:
	var music_cfg := Content.section("music")
	for row: Dictionary in music_cfg["tracks"]:
		var layers := MusicLayers.new(row, music_cfg)
		root.add_child(layers)
		await process_frame
		var rows: Array = row["stems"]
		check(
			layers.stream.stream_count == rows.size(),
			"%s: one stream, %d stems" % [row["id"], rows.size()]
		)
		var streams := layers._streams()
		check(
			MusicLayers.lock_error(streams, row) <= Num.f(music_cfg["lock_tolerance_s"]),
			(
				"%s: stems on the bar grid (%.4f s off)"
				% [row["id"], MusicLayers.lock_error(streams, row)]
			)
		)
		var lead: AudioStream = streams[0]
		var first := lead.get_length()
		var same := true
		for s: AudioStream in streams:
			same = (
				same and absf(s.get_length() - first) < 1.0 / Num.f(music_cfg["placeholder_rate"])
			)
		check(same, "%s: every stem the same length to the sample" % row["id"])
		check(layers.player.playing, "%s: the one player is playing all stems" % row["id"])
		for step: int in 30:  # a swell and a drop-back: volumes move, lengths and count do not
			layers.follow(float(step) / 29.0, 0.5)
		for i: int in streams.size():
			check(
				is_equal_approx(layers.stream.get_sync_stream_volume(i), layers.levels[i]),
				"%s stem %d: the player's volume is the fade's" % [row["id"], i]
			)
		check(
			MusicLayers.lock_error(layers._streams(), row) <= Num.f(music_cfg["lock_tolerance_s"]),
			"%s: still locked after the fades" % row["id"]
		)
		layers.queue_free()


## A stem one bar short drifts a bar against the others every loop; the check catches it, and a
## tempo that disagrees with the stems' length is caught the same way.
func _check_planted_stem_off_the_grid() -> void:
	var music_cfg := Content.section("music")
	var tracks: Array = music_cfg["tracks"]
	var first_row: Dictionary = tracks[0]
	var row := first_row.duplicate(true)
	var good := MusicLayers.silence(row, music_cfg)
	var short_row: Dictionary = row.duplicate(true)
	short_row["bars"] = Num.i(row["bars"]) - 1
	var short := MusicLayers.silence(short_row, music_cfg)
	var tolerance := Num.f(music_cfg["lock_tolerance_s"])
	check(MusicLayers.lock_error([good, good], row) <= tolerance, "two stems on the grid pass")
	check(
		MusicLayers.lock_error([good, short], row) > tolerance, "a stem one bar short is not locked"
	)
	var slow: Dictionary = row.duplicate(true)
	slow["bpm"] = Num.f(row["bpm"]) * 1.05
	check(
		MusicLayers.lock_error([good, good], slow) > tolerance,
		"stems cut at another tempo are not locked"
	)
