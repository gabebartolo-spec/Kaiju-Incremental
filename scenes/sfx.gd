class_name Sfx
extends Node
## The sounds of the powers (D-026, D-030), presentation only: Rampage calls a sound where it
## calls the matching AbilityFx effect. Files in assets/sfx are built by tools/sfx/build_sfx.py
## from Kenney CC0 layers and in-house synthesis; loudness lives in data/tuning.json "sfx".
## A small pool of players lets sounds overlap; Regeneration is one looping player.

const POOL := 8
const STOMPS := 3

## Every sound played, in order; read by the flow suite.
var played: Array[String] = []
var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _regen: AudioStreamPlayer
var _rng: RandomNumberGenerator
var _tune: Dictionary


## rng: the presentation's own seeded stream (pitch variation only).
func _init(rng: RandomNumberGenerator) -> void:
	_rng = rng
	_tune = Content.section("sfx")


func _ready() -> void:
	var names: Array[String] = [
		"stomp_crack", "breath", "leap_whoosh", "leap_land", "lash", "ready", "deflect"
	]
	for k: int in STOMPS:
		names.append("stomp_%d" % k)
	for sound: String in names:
		_streams[sound] = load("res://assets/sfx/%s.ogg" % sound)
	for _i: int in POOL:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_pool.append(player)
	_regen = AudioStreamPlayer.new()
	var loop: AudioStreamOggVorbis = load("res://assets/sfx/regen_loop.ogg")
	loop.loop = true
	_regen.stream = loop
	_regen.volume_db = _volume("regen_loop")
	add_child(_regen)


## A stomp; heavy ones (the street cracks) add a crack-and-rumble layer.
func stomp(cracks: bool) -> void:
	play("stomp_%d" % _rng.randi_range(0, STOMPS - 1))
	if cracks:
		play("stomp_crack")


## Regeneration's bubbling, on while the kaiju heals.
func regen(healing: bool) -> void:
	if healing and not _regen.playing:
		played.append("regen_loop")
		_regen.play()
	elif not healing and _regen.playing:
		_regen.stop()


## One sound by name, slightly re-pitched each time so repeats do not sound copied.
func play(sound: String) -> void:
	played.append(sound)
	var stream: AudioStream = _streams.get(sound)
	if stream == null:
		return
	var player := _pool[_next]
	_next = (_next + 1) % POOL
	var jitter := Num.f(_tune["pitch_jitter"])
	player.stream = stream
	player.volume_db = _volume(sound)
	player.pitch_scale = 1.0 + _rng.randf_range(-jitter, jitter)
	player.play()


func _volume(sound: String) -> float:
	var levels: Dictionary = _tune["volume_db"]
	var key := "stomp" if sound.begins_with("stomp_") and sound != "stomp_crack" else sound
	return Num.f(levels.get(key, 0.0))
