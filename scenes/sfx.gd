class_name Sfx
extends Node
## The sounds of the powers (D-026, D-030), presentation only: Rampage calls a sound where it
## calls the matching AbilityFx effect. Files in assets/sfx are built by tools/sfx/build_sfx.py
## from Kenney CC0 layers and in-house synthesis; loudness lives in data/tuning.json "sfx".
## A small pool of players lets sounds overlap; Regeneration is one looping player.
## Steps and stomps land on the feet: every foot plant plays a footstep, and a sim stomp waits
## for the next plant to play its heavy thump there (or plays alone if no foot lands soon).

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
## Size-tier pitch (baby high, Behemoth low), from set_size_tier.
var _size_pitch := 1.0
## The heavy stomp waiting for the next foot plant ("" when none), and how long it has waited.
var _pending := ""
var _pending_crack := false
var _pending_age := 0.0
## Seconds since the last footstep and the last ground crack (the director's dials:
## footstep_min_interval, crack_min_interval).
var _since_step := INF
var _since_crack := INF


## rng: the presentation's own seeded stream (pitch variation only).
func _init(rng: RandomNumberGenerator) -> void:
	_rng = rng
	_tune = Content.section("sfx")


func _ready() -> void:
	var names: Array[String] = [
		"breath",
		"leap_whoosh",
		"leap_land",
		"lash",
		"ready",
		"deflect",
		"footstep",
		"stomp_crack",
		"collapse",
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


func _process(delta: float) -> void:
	_since_step += delta
	_since_crack += delta
	if _pending == "":
		return
	_pending_age += delta
	if _pending_age >= Num.f(_tune["stomp_wait"]):
		_release_stomp()


## The kaiju's size tier (RampageSim.size_tier): steps and stomps are pitched by it, so a
## baby patters and a Behemoth booms whatever model it wears.
func set_size_tier(tier: int) -> void:
	var pitches: Array = _tune["size_pitch"]
	_size_pitch = Num.f(pitches[clampi(tier - 1, 0, pitches.size() - 1)])


## A sim stomp, heavier and lower the stronger it is (power: stomp damage over the species'
## own, as AbilityFx.power gives it). It sounds on the next foot plant; crack adds the ground
## splitting (the same threshold that draws the molten cracks).
func stomp(power: float, crack: bool) -> void:
	var tier := 0
	for edge: Variant in _tune["stomp_tiers"]:
		if power >= Num.f(edge):
			tier += 1
	_pending = "stomp_%d" % mini(tier, STOMPS - 1)
	_pending_crack = crack
	_pending_age = 0.0


## A foot touched down (KaijuModel.foot_planted strength 0..1): the waiting stomp if there is
## one, else a footstep as loud as the step is hard.
func footstep(strength: float) -> void:
	if _pending != "":
		_release_stomp()
		return
	if _since_step < Num.f(_tune["footstep_min_interval"]):
		return
	_since_step = 0.0
	var quiet := Num.f(_tune["footstep_quiet_db"]) * (1.0 - clampf(strength, 0.0, 1.0))
	play("footstep", quiet)


## A building part hits the ground (sim fall_land); a toppled tower is louder and deeper.
func collapse(topple: bool) -> void:
	play("collapse", 0.0 if topple else Num.f(_tune["drop_quiet_db"]), 0.85 if topple else 1.0)


func _release_stomp() -> void:
	play(_pending)
	if _pending_crack and _since_crack >= Num.f(_tune["crack_min_interval"]):
		_since_crack = 0.0
		play("stomp_crack")
	_pending = ""


## Regeneration's bubbling, on while the kaiju heals.
func regen(healing: bool) -> void:
	if healing and not _regen.playing:
		played.append("regen_loop")
		_regen.play()
	elif not healing and _regen.playing:
		_regen.stop()


## One sound by name, slightly re-pitched each time so repeats do not sound copied; extra_db
## and pitch shade a single play (steps and stomps also take the size-tier pitch).
func play(sound: String, extra_db := 0.0, pitch := 1.0) -> void:
	played.append(sound)
	var stream: AudioStream = _streams.get(sound)
	if stream == null:
		return
	var player := _pool[_next]
	_next = (_next + 1) % POOL
	var jitter := Num.f(_tune["pitch_jitter"])
	player.stream = stream
	player.volume_db = _volume(sound) + extra_db
	if sound == "footstep" or sound.begins_with("stomp"):
		pitch *= _size_pitch
	player.pitch_scale = pitch * (1.0 + _rng.randf_range(-jitter, jitter))
	player.play()


## The pitch of the latest play (the flow suite checks the size-tier pitch with it).
func last_pitch() -> float:
	return _pool[(_next + POOL - 1) % POOL].pitch_scale


func _volume(sound: String) -> float:
	var levels: Dictionary = _tune["volume_db"]
	var key := "stomp" if sound.begins_with("stomp_") and sound != "stomp_crack" else sound
	return Num.f(levels.get(key, 0.0))
