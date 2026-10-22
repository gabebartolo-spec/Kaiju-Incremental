class_name TitleAmbience
extends Node
## The faint sounds under the title's burning city (comments #88, #98, #99): distant screams,
## gunfire in ragged bursts, sirens, far explosions and the slow stomps of the kaiju (the game's
## own stomp pitched well down with a generated sub thump under it, low-passed with a short dark
## reverb on a bus of its own), all far down in the mix (tuning "title" "ambience", dB on their
## own buses; the menu's click is -12). The siren's file may be missing from assets/sfx: that
## layer then stays silent. Each stomp, shot and boom is announced by a signal, so the picture
## can shake and flash with it.

## A far stomp landed (strength 0..1); a gunshot sounded far away; an explosion boomed.
signal stomped(strength: float)
signal shot
signal boomed

const SFX_DIR := "res://assets/sfx/%s.ogg"
## How far the distant rifle is pitched down (it is a long way off), as in tuning "sfx" pitch_by.
const GUN_PITCH := 0.7

var _cfg: Dictionary
var _rng := Seeds.make("title_sound", 0)
var _gun: AudioStreamPlayer
var _wait := 0.0
var _burst := 0
var _burst_gap := 0.0
var _stomp: AudioStreamPlayer
var _sub: AudioStreamPlayer
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
	var boom: Dictionary = _cfg["boom"]
	_boom.stream = load(SFX_DIR % str(boom["sound"]))
	_boom.bus = _stomp_bus
	_boom.volume_db = Num.f(boom["db"])
	_boom.pitch_scale = Num.f(boom["pitch"])
	add_child(_boom)
	_boom_wait = _boom_gap()
	_gun = AudioStreamPlayer.new()
	_gun.stream = load(SFX_DIR % "rifle")
	_gun.bus = AudioBuses.of("rifle_far")
	_gun.volume_db = Num.f(_cfg["gun_db"])
	_gun.max_polyphony = 4
	add_child(_gun)
	_wait = _gap()


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
## and a long reverb), one every few seconds with a little jitter.
func _make_stomp() -> void:
	var cfg: Dictionary = _cfg["stomp"]
	_stomp_bus = &"TitleFar"
	var at := AudioServer.get_bus_index(_stomp_bus)
	if at < 0:
		AudioServer.add_bus()
		at = AudioServer.bus_count - 1
		AudioServer.set_bus_name(at, _stomp_bus)
		AudioServer.set_bus_send(at, &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master")
		var low := AudioEffectLowPassFilter.new()
		low.cutoff_hz = Num.f(cfg["lowpass_hz"])
		AudioServer.add_bus_effect(at, low)
		var wash: Dictionary = cfg["reverb"]
		var reverb := AudioEffectReverb.new()
		reverb.room_size = Num.f(wash["room_size"])
		reverb.damping = Num.f(wash["damping"])
		reverb.wet = Num.f(wash["wet"])
		AudioServer.add_bus_effect(at, reverb)
	_stomp = AudioStreamPlayer.new()
	_stomp.stream = load(SFX_DIR % str(cfg["sound"]))
	_stomp.bus = _stomp_bus
	_stomp.volume_db = Num.f(cfg["db"])
	_stomp.pitch_scale = Num.f(cfg["pitch"])
	add_child(_stomp)
	_sub = AudioStreamPlayer.new()
	_sub.stream = _sub_thump(cfg)
	_sub.bus = _stomp_bus
	_sub.volume_db = Num.f(cfg["sub_db"])
	add_child(_sub)
	_stomp_wait = Num.f(cfg["every_s"]) * 0.5


## The sub thump: a low sine with a fast attack and an exponential decay (16-bit mono), built
## once.
static func _sub_thump(cfg: Dictionary) -> AudioStreamWAV:
	var rate := 44100
	var decay := Num.f(cfg["sub_decay_s"])
	var attack := Num.f(cfg["sub_attack_s"])
	var hz := Num.f(cfg["sub_hz"])
	var count := int(rate * decay * 5.0)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i: int in count:
		var t := float(i) / rate
		var level := minf(1.0, t / attack) * exp(-t / decay)
		bytes.encode_s16(i * 2, int(sin(TAU * hz * t) * level * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = bytes
	return wav


func _tick_stomp(delta: float) -> void:
	_stomp_wait -= delta
	if _stomp_wait > 0.0:
		return
	var cfg: Dictionary = _cfg["stomp"]
	_stomp.play()
	_sub.play()
	stomped.emit(1.0)
	_stomp_wait = Num.f(cfg["every_s"]) + _rng.randf_range(-1.0, 1.0) * Num.f(cfg["jitter_s"])


func _loop(sound: String, db: float) -> void:
	var player := AudioStreamPlayer.new()
	var stream: AudioStreamOggVorbis = load(SFX_DIR % sound)
	stream.loop = true
	player.stream = stream
	player.bus = AudioBuses.of(sound)
	player.volume_db = db
	add_child(player)
	player.play(_rng.randf() * 4.0)  # not always the same scream first


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
