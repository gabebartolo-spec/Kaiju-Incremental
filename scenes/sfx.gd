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

## Menu sounds played (Sfx.ui), in order; read by the flow suite.
static var ui_played: Array[String] = []
static var _ui_player: AudioStreamPlayer

## Every sound played, in order; read by the flow suite.
var played: Array[String] = []
## The camera: army sounds fade with their distance from it (set by watch).
var listener: Node3D
## Returns the helicopters in the air (Array[Node3D]); the rotor loop follows them.
var _helis: Callable
var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _regen: AudioStreamPlayer
## The city's panic (crowd_panic loop), faded by the street's fleeing people and the
## destruction rate; _street is null on a stage with no streets.
var _crowd: AudioStreamPlayer
var _street: StreetLife
var _crowd_db := -80.0
var _since_breath := INF
var _chunks_before := 0
var _chunk_rate := 0.0
var _rotor: AudioStreamPlayer
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
		"roar",
		"tank_fire",
		"shell_hit",
		"jet_flyby",
		"jet_cannon",
	]
	for k: int in STOMPS:
		names.append("stomp_%d" % k)
	for sound: String in names:
		_streams[sound] = load("res://assets/sfx/%s.ogg" % sound)
	for _i: int in POOL:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_pool.append(player)
	_regen = _looping("regen_loop")
	_rotor = _looping("heli_rotor")
	_crowd = _looping("crowd_panic")


## Rampage hands over its camera, its helicopters (PowersView.helis) and its street (the
## crowd) once, at start.
func watch(camera: Node3D, helis: Callable, street: StreetLife) -> void:
	listener = camera
	_helis = helis
	_street = street


func _process(delta: float) -> void:
	if _helis.is_valid():
		var helis: Array[Node3D] = _helis.call()
		rotors(helis)
	_since_step += delta
	_since_crack += delta
	_since_breath += delta
	_update_crowd(delta)
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


## A menu sound (ui_click, ui_confirm, ui_deny) on one shared player under the tree's root,
## so a sound outlives the screen that made it.
static func ui(sound: String) -> void:
	ui_played.append(sound)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	if not is_instance_valid(_ui_player):
		_ui_player = AudioStreamPlayer.new()
		_ui_player.bus = "SFX"
		_ui_player.max_polyphony = 4
		tree.root.add_child.call_deferred(_ui_player)
	var levels: Dictionary = Content.section("sfx")["volume_db"]
	_ui_player.stream = load("res://assets/sfx/%s.ogg" % sound)
	_ui_player.volume_db = Num.f(levels[sound])
	if _ui_player.is_inside_tree():
		_ui_player.play()
	else:
		_ui_player.ready.connect(_ui_player.play, CONNECT_ONE_SHOT)


## The croc titan's roar, played at once from its own player under `parent` (screens with no
## rampage, such as the evolution reveal and the demo end card, call this). Returns the player.
static func roar(parent: Node) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = "SFX"
	player.stream = load("res://assets/sfx/roar.ogg")
	var levels: Dictionary = Content.section("sfx")["volume_db"]
	player.volume_db = Num.f(levels["roar"])
	parent.add_child(player)
	player.play()
	return player


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


## The army's sounds where they happen (tank_fire, shell_hit): quieter the further they are
## from the camera, down to a floor so a far tank is still heard.
func play_at(sound: String, at: Vector3) -> void:
	play(sound, _distance_db(at))


## The helicopters' rotor loop: on while any is flying, as loud as the nearest one.
func rotors(helis: Array[Node3D]) -> void:
	if helis.is_empty():
		if _rotor.playing:
			_rotor.stop()
		return
	var near := INF
	for heli: Node3D in helis:
		near = minf(near, _distance_db(heli.global_position) * -1.0)
	_rotor.volume_db = _volume("heli_rotor") - near
	if not _rotor.playing:
		played.append("heli_rotor")
		_rotor.play()


func _distance_db(at: Vector3) -> float:
	if listener == null or not listener.is_inside_tree():
		return 0.0
	var ratio := listener.global_position.distance_to(at) / Num.f(_tune["near_distance"])
	return maxf(Num.f(_tune["far_floor_db"]), -20.0 * log(maxf(1.0, ratio)) / log(10.0))


func _looping(sound: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = "SFX"
	var loop: AudioStreamOggVorbis = load("res://assets/sfx/%s.ogg" % sound)
	loop.loop = true
	player.stream = loop
	player.volume_db = _volume(sound)
	add_child(player)
	return player


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
	if sound == "breath":
		_since_breath = 0.0
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


## The crowd's level in dB for a panic `intensity` (0..1), pulled down while Atomic Breath
## roars (ducked); tuning "sfx" "crowd".
func crowd_target(intensity: float, ducked: bool) -> float:
	var cfg: Dictionary = _tune["crowd"]
	if intensity <= Num.f(cfg["min_intensity"]):
		return Num.f(cfg["silent_db"])
	var level := lerpf(Num.f(cfg["quiet_db"]), _volume("crowd_panic"), clampf(intensity, 0.0, 1.0))
	return level - (Num.f(cfg["duck_db"]) if ducked else 0.0)


func _update_crowd(delta: float) -> void:
	if _street == null or not is_instance_valid(_street):
		return
	var cfg: Dictionary = _tune["crowd"]
	var chunks := _street.sim.chunks_destroyed
	var rate := float(chunks - _chunks_before) / maxf(delta, 0.001)
	_chunks_before = chunks
	_chunk_rate = lerpf(_chunk_rate, rate, minf(1.0, delta * 2.0))
	var intensity := (
		clampf(float(_street.panicking()) / Num.f(cfg["full_panic"]), 0.0, 1.0) * 0.7
		+ clampf(_chunk_rate / Num.f(cfg["full_rate"]), 0.0, 1.0) * 0.3
	)
	var target := crowd_target(intensity, _since_breath < Num.f(cfg["duck_seconds"]))
	_crowd_db = move_toward(_crowd_db, target, Num.f(cfg["fade_db_per_s"]) * delta)
	_crowd.volume_db = _crowd_db
	var audible := _crowd_db > Num.f(cfg["silent_db"]) + 1.0
	if audible and not _crowd.playing:
		played.append("crowd_panic")
		_crowd.play()
	elif not audible and _crowd.playing:
		_crowd.stop()


## The pitch of the latest play (the flow suite checks the size-tier pitch with it).
func last_pitch() -> float:
	return _pool[(_next + POOL - 1) % POOL].pitch_scale


func _volume(sound: String) -> float:
	var levels: Dictionary = _tune["volume_db"]
	var key := "stomp" if sound.begins_with("stomp_") and sound != "stomp_crack" else sound
	return Num.f(levels.get(key, 0.0))
