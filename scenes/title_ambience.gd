class_name TitleAmbience
extends Node
## The faint sounds under the title's burning city (comments #88, #98, #99): distant screams,
## gunfire in ragged bursts, sirens, far explosions and the slow stomps of the kaiju (the game's
## own stomp pitched well down, a generated 40 Hz sub thump and an 80-120 Hz body thump under it,
## low-passed with a short dark reverb on a bus of its own, and a short 1-3 kHz crack so the
## step carries on a TV's small speakers), all far down in the mix (tuning "title" "ambience", dB
## on their own buses; the menu's click is -12). The siren's file may be missing from
## assets/sfx: that layer then stays silent. Each shot and boom is announced by a signal, so the
## picture can flash with it; a stomp shows nothing (the camera is still, #99).

## A far stomp landed (the water shivers with it); a gunshot sounded far away; an explosion boomed.
signal stomped
signal shot
signal boomed

const SFX_DIR := "res://assets/sfx/%s.ogg"
## How far the distant rifle is pitched down (it is a long way off), as in tuning "sfx" pitch_by.
const GUN_PITCH := 0.7
const RATE := 44100
## Where the bed's fade-in starts (dB).
const FADE_FROM_DB := -60.0
## The body thump's attack (s), how many sines make the crack and their peak level (of 1).
const BODY_ATTACK := 0.004
const CRACK_PARTIALS := 24
const CRACK_GAIN := 0.5

var _cfg: Dictionary
var _rng := Seeds.make("title_sound", 0)
var _gun: AudioStreamPlayer
var _wait := 0.0
var _burst := 0
var _burst_gap := 0.0
var _stomp: AudioStreamPlayer
var _sub: AudioStreamPlayer
var _body: AudioStreamPlayer
var _crack: AudioStreamPlayer
var _stomp_wait := 0.0
var _stomp_bus := &""
var _boom: AudioStreamPlayer
var _boom_wait := 0.0


func _ready() -> void:
	_cfg = Content.section("title")["ambience"]
	_loop("crowd_panic", Num.f(_cfg["crowd_db"]))
	var siren := str(_cfg["siren"])
	if ResourceLoader.exists(SFX_DIR % siren):
		_loop(siren, Num.f(_cfg["siren_db"]))
	_make_stomp()
	_boom = AudioStreamPlayer.new()
	_boom.name = "boom"
	var boom: Dictionary = _cfg["boom"]
	_boom.stream = load(SFX_DIR % str(boom["sound"]))
	var boom_low := AudioEffectLowPassFilter.new()
	boom_low.cutoff_hz = Num.f(boom["lowpass_hz"])
	var boom_wash: Dictionary = _cfg["stomp"]["reverb"]
	_make_bus(&"TitleBoom", [boom_low, _reverb(boom_wash, 0.8)])
	_boom.bus = &"TitleBoom"
	_boom.volume_db = Num.f(boom["db"])
	_boom.pitch_scale = Num.f(boom["pitch"])
	add_child(_boom)
	_boom_wait = _boom_gap()
	_gun = AudioStreamPlayer.new()
	_gun.name = "gun"
	_gun.stream = load(SFX_DIR % "rifle")
	_gun.bus = AudioBuses.of("rifle_far")
	_gun.volume_db = Num.f(_cfg["gun_db"])
	_gun.max_polyphony = 4
	add_child(_gun)
	_wait = _gap()


## The city stands and the first flashes can be seen: the first shots and the first explosion
## come soon from here (tuning "first_gun_s", "first_boom_s"), then at their usual pace.
func flashes_begin() -> void:
	_wait = minf(_wait, Num.f(_cfg["first_gun_s"]))
	_boom_wait = minf(_boom_wait, Num.f(_cfg["first_boom_s"]))


func _process(delta: float) -> void:
	_tick_stomp(delta)
	_boom_wait -= delta
	if _boom_wait <= 0.0:
		_boom.play()
		boomed.emit()
		_boom_wait = _boom_gap()
	if _burst > 0:
		_burst_gap -= delta
		if _burst_gap <= 0.0:
			_shoot()
			_burst -= 1
			_burst_gap = Num.f(_cfg["gun_burst_gap_s"]) * _rng.randf_range(0.7, 1.4)
		return
	_wait -= delta
	if _wait <= 0.0:
		var shots: Array = _cfg["gun_burst"]
		_burst = _rng.randi_range(Num.i(shots[0]), Num.i(shots[1]))
		_wait = _gap()


## The kaiju's far footsteps: the game's stomp pitched down and played on its own bus (a low-pass
## and a long reverb), one every few seconds with a little jitter; the body thump rides the same
## bus, the crack a bus of its own that keeps its high end (a short reverb only).
func _make_stomp() -> void:
	var cfg: Dictionary = _cfg["stomp"]
	_stomp_bus = &"TitleFar"
	var wash: Dictionary = cfg["reverb"]
	var low := AudioEffectLowPassFilter.new()
	low.cutoff_hz = Num.f(cfg["lowpass_hz"])
	_make_bus(_stomp_bus, [low, _reverb(wash, 1.0)])
	_make_bus(&"TitleCrack", [_reverb(wash, 0.5)])
	_stomp = _player(
		"stomp", load(SFX_DIR % str(cfg["sound"])) as AudioStream, _stomp_bus, Num.f(cfg["db"])
	)
	_stomp.pitch_scale = Num.f(cfg["pitch"])
	_sub = _player("sub", _sub_thump(cfg), _stomp_bus, Num.f(cfg["sub_db"]))
	_body = _player("body", _body_thump(cfg), _stomp_bus, Num.f(cfg["body_db"]))
	_crack = _player("crack", _crack_burst(cfg), &"TitleCrack", Num.f(cfg["crack_db"]))
	_stomp_wait = Num.f(cfg["every_s"]) * 0.5


func _player(label: String, stream: AudioStream, bus: StringName, db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = label
	player.stream = stream
	player.bus = bus
	player.volume_db = db
	add_child(player)
	return player


func _reverb(wash: Dictionary, wet_scale: float) -> AudioEffectReverb:
	var reverb := AudioEffectReverb.new()
	reverb.room_size = Num.f(wash["room_size"])
	reverb.damping = Num.f(wash["damping"])
	reverb.wet = Num.f(wash["wet"]) * wet_scale
	return reverb


## A bus that sends to SFX (or Master), with these effects; left as it is when it exists.
func _make_bus(label: StringName, effects: Array[AudioEffect]) -> void:
	if AudioServer.get_bus_index(label) >= 0:
		return
	AudioServer.add_bus()
	var at := AudioServer.bus_count - 1
	AudioServer.set_bus_name(at, label)
	AudioServer.set_bus_send(at, &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master")
	for effect: AudioEffect in effects:
		AudioServer.add_bus_effect(at, effect)


## The sub thump: a low sine with a fast attack and an exponential decay (16-bit mono), built
## once.
static func _sub_thump(cfg: Dictionary) -> AudioStreamWAV:
	var decay := Num.f(cfg["sub_decay_s"])
	var attack := Num.f(cfg["sub_attack_s"])
	var hz := Num.f(cfg["sub_hz"])
	var count := int(RATE * decay * 5.0)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i: int in count:
		var t := float(i) / RATE
		samples[i] = sin(TAU * hz * t) * minf(1.0, t / attack) * exp(-t / decay)
	return _wav(samples)


## The body thump: a sine that falls from the first to the second pitch of "body_hz" as it dies
## away, the part of the step a small speaker can reproduce.
static func _body_thump(cfg: Dictionary) -> AudioStreamWAV:
	var pitch: Array = cfg["body_hz"]
	var decay := Num.f(cfg["body_decay_s"])
	var count := int(RATE * decay * 6.0)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	for i: int in count:
		var t := float(i) / RATE
		var hz := lerpf(Num.f(pitch[1]), Num.f(pitch[0]), exp(-t / decay))
		phase += TAU * hz / RATE
		samples[i] = sin(phase) * minf(1.0, t / BODY_ATTACK) * exp(-t / decay)
	return _wav(samples)


## The crack: many sines at random pitches between the two of "crack_hz", a click that dies in a
## few tens of milliseconds (a seeded stand-in for band-limited noise).
static func _crack_burst(cfg: Dictionary) -> AudioStreamWAV:
	var band: Array = cfg["crack_hz"]
	var decay := Num.f(cfg["crack_decay_s"])
	var count := int(RATE * decay * 6.0)
	var rng := Seeds.make("title_crack", 0)
	var partials: Array[Vector2] = []
	for _i: int in CRACK_PARTIALS:
		partials.append(Vector2(rng.randf_range(Num.f(band[0]), Num.f(band[1])), rng.randf() * TAU))
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i: int in count:
		var t := float(i) / RATE
		var sum := 0.0
		for part: Vector2 in partials:
			sum += sin(TAU * part.x * t + part.y)
		samples[i] = sum / sqrt(CRACK_PARTIALS) * exp(-t / decay) * CRACK_GAIN
	return _wav(samples)


## 16-bit mono at RATE from samples in -1..1.
static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i: int in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = bytes
	return wav


func _tick_stomp(delta: float) -> void:
	_stomp_wait -= delta
	if _stomp_wait > 0.0:
		return
	var cfg: Dictionary = _cfg["stomp"]
	# No two steps alike: each is a little higher or lower, heavier or lighter.
	var vary: Dictionary = _cfg["step_vary"]
	var weight := _rng.randf_range(-1.0, 1.0) * Num.f(vary["db"])
	var pitch := 1.0 + _rng.randf_range(-1.0, 1.0) * Num.f(vary["pitch"])
	_stomp.pitch_scale = Num.f(cfg["pitch"]) * pitch
	_stomp.volume_db = Num.f(cfg["db"]) + weight
	_sub.volume_db = Num.f(cfg["sub_db"]) + weight
	_body.pitch_scale = pitch
	_body.volume_db = Num.f(cfg["body_db"]) + weight
	_crack.pitch_scale = 1.0 + (pitch - 1.0) * 0.5
	_crack.volume_db = Num.f(cfg["crack_db"]) + weight
	_stomp.play()
	_sub.play()
	_body.play()
	_crack.play()
	stomped.emit()
	_stomp_wait = Num.f(cfg["every_s"]) + _rng.randf_range(-1.0, 1.0) * Num.f(cfg["jitter_s"])


func _loop(sound: String, db: float) -> void:
	var stream: AudioStreamOggVorbis = load(SFX_DIR % sound)
	stream.loop = true
	var player := _player(sound, stream, AudioBuses.of(sound), db)
	player.play(_rng.randf() * 4.0)  # not always the same scream first
	# The bed swells in from nothing, so the title never opens on a full wall of sound.
	player.volume_db = FADE_FROM_DB
	create_tween().tween_property(player, "volume_db", db, Num.f(_cfg["fade_in_s"]))


func _shoot() -> void:
	_gun.pitch_scale = GUN_PITCH * _rng.randf_range(0.92, 1.08)
	_gun.volume_db = Num.f(_cfg["gun_db"]) + _rng.randf_range(-3.0, 3.0)
	_gun.play()
	shot.emit()


func _gap() -> float:
	var gap: Array = _cfg["gun_gap_s"]
	return _rng.randf_range(Num.f(gap[0]), Num.f(gap[1]))


func _boom_gap() -> float:
	var gap: Array = _cfg["boom"]["every_s"]
	return _rng.randf_range(Num.f(gap[0]), Num.f(gap[1]))
