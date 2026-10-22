class_name CitySound
extends Node
## The city's sound atmosphere (D-155, "panic then eerie quiet"; D-125, music in layers): ONE driver
## that reads the sim's destruction share and the street's people-fled count, works out where the
## rampage is (CityCurve.phase) and sets every city bed from the curves in tuning "city_sound":
## the crowd's panic loop, sirens, distant gunfire, the fire's roar and the wind. Crowds and sirens
## swell early, then fade as people flee; the ruined city is fire, wind and the military only. The
## music stems (MusicLayers) fade in on the same phase. Presentation only: it reads the sim and
## decides nothing. A bed whose sound file is missing or fails to load is still driven (its level is
## in `levels`) and simply stays silent.

## Where the rampage is, 0..1 (CityCurve.phase), and every bed's current level in dB.
var phase := 0.0
var levels: Dictionary = {}
var music: MusicLayers
var _sim: RampageSim
var _street: StreetLife
var _sfx: Sfx
var _cfg: Dictionary
var _players: Dictionary = {}
var _population := 0.0


## sfx: its crowd loop is trimmed by this driver, and nothing sounds until it is live (null: a
## test that drives advance() itself).
func _init(sim: RampageSim, street: StreetLife, sfx: Sfx) -> void:
	_sim = sim
	_street = street
	_sfx = sfx
	_cfg = Content.section("city_sound")
	for bed: String in _cfg["beds"]:
		levels[bed] = 0.0 if bed == "crowd" else Num.f(_cfg["silent_db"])


func _ready() -> void:
	for bed: String in _cfg["beds"]:
		var file := "res://assets/sfx/%s.ogg" % bed
		var loop: AudioStreamOggVorbis = null
		if bed != "crowd" and ResourceLoader.exists(file):
			loop = load(file) as AudioStreamOggVorbis  # null if it fails to load: that bed stays silent
		if loop != null:
			_players[bed] = _player(bed, loop)
	var tracks: Array = Content.section("music")["tracks"]
	var row: Dictionary = tracks[clampi(_sim.size_tier() - 1, 0, tracks.size() - 1)]
	music = MusicLayers.new(row, Content.section("music"))
	add_child(music)


func _process(delta: float) -> void:
	if _sfx == null or _sfx.live:
		advance(delta)


## One frame: the phase from the sim and the street, then each bed a step toward its curve.
func advance(delta: float) -> void:
	if _population <= 0.0:  # the street's people at the start: what the fled share is of
		_population = float(_street.pos.size())
	phase = CityCurve.phase(_sim.destruction(), _street.fled, _population, _cfg)
	var rate := Num.f(_cfg["fade_db_per_s"]) * delta
	for bed: String in _cfg["beds"]:
		levels[bed] = move_toward(Num.f(levels[bed]), CityCurve.level(bed, phase, _cfg), rate)
		_apply(bed)
	if music != null and music.stream != null:
		music.follow(phase, delta)


func _apply(bed: String) -> void:
	var db := Num.f(levels[bed])
	if bed == "crowd":
		if _sfx != null:
			_sfx._crowd_mix.trim_db = db
		return
	var player: AudioStreamPlayer = _players.get(bed)
	if player == null:
		return
	player.volume_db = db
	var audible := db > Num.f(_cfg["silent_db"]) + 1.0
	if audible and not player.playing:
		player.play()
	elif not audible and player.playing:
		player.stop()


func _player(bed: String, loop: AudioStreamOggVorbis) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = AudioBuses.of(bed)
	loop.loop = true
	player.stream = loop
	player.volume_db = Num.f(_cfg["silent_db"])
	add_child(player)
	return player
