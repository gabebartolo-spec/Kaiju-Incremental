class_name Sfx
extends Node
## The sounds of the powers (D-026, D-030), presentation only: Rampage calls a sound where it
## calls the matching AbilityFx effect. Files in assets/sfx are built by tools/sfx/build_sfx.py
## from Kenney CC0 layers and in-house synthesis; loudness lives in data/tuning.json "sfx".
## A small pool of players lets sounds overlap; Regeneration is one looping player.
## Steps and stomps land on the feet: every foot plant plays a footstep, and a sim stomp waits
## for the next plant to play its heavy thump there (or plays alone if no foot lands soon).

const STOMPS := 3
## Footstep sounds the steps take turns with (footstep, footstep_1..3), in this order: no two
## steps in a row sound the same.
const STEPS: Array[String] = ["footstep", "footstep_2", "footstep_1", "footstep_3"]
## How fast the regen bubbles fade once their cue is over, and where a fade ends.
const REGEN_FADE_DB_PER_S := 40.0
const SILENT_DB := -60.0

## Menu sounds played (Sfx.ui), in order; read by the flow suite.
static var ui_played: Array[String] = []
static var _ui_player: AudioStreamPlayer

## Every sound played, in order; read by the flow suite.
var played: Array[String] = []
## The camera: army sounds fade with their distance from it (set by watch).
var listener: Node3D
## The powers' view: its helicopters drive the rotor loop, and it plays their gun and crash here.
var _powers: PowersView
var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _regen: AudioStreamPlayer
var _healing := false
var _regen_age := 0.0
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
## Seconds since each gap-limited sound last played (tuning "sfx" "min_interval").
var _since_sound: Dictionary = {}
## How many footsteps have played (picks the next of STEPS).
var _step := 0
## Building parts that landed this frame, as their loudness in dB: the loudest few play once
## the frame is over (tuning "sfx" "collapse_per_frame"), the rest are dropped.
var _landings: Array[float] = []


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
		"stomp_crack",
		"collapse",
		"roar",
		"tank_fire",
		"shell_hit",
		"heli_gun",
		"heli_crash",
		"rifle",
	]
	for k: int in STOMPS:
		names.append("stomp_%d" % k)
	names.append_array(STEPS)
	for sound: String in names:
		_streams[sound] = load("res://assets/sfx/%s.ogg" % sound)
	_streams["rifle_far"] = _streams["rifle"]  # a distant squad: the same shot, softer and lower
	# Enough voices that a stomp's or a tank shot's tail is not cut off by the plays after it
	# (tuning "sfx" "voices"; 8 cut a third of the stomps short under rooftop fire).
	for _i: int in Num.i(_tune["voices"]):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_pool.append(player)
	_regen = _looping("regen_loop")
	_rotor = _looping("heli_rotor")
	_crowd = _looping("crowd_panic")


## Rampage hands over its camera, its powers' view (helicopters) and its street (the crowd)
## once, at start.
func watch(camera: Node3D, powers: PowersView, street: StreetLife) -> void:
	listener = camera
	_powers = powers
	powers.sfx = self
	_street = street


func _process(delta: float) -> void:
	_sound_landings()
	if is_instance_valid(_powers):
		rotors(_powers.helis())
	_since_step += delta
	_since_crack += delta
	_since_breath += delta
	for sound: String in _since_sound:
		_since_sound[sound] = Num.f(_since_sound[sound]) + delta
	_fade_regen(delta)
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
	play(STEPS[_step % STEPS.size()], quiet)
	_step += 1


## A building part hits the ground (sim fall_land); a toppled tower is louder and deeper.
## Heard at the end of the frame, with every other landing of that frame: a mass collapse lands
## a hundred parts at once (171 in two frames, rooftops #63), and only the loudest few play.
func collapse(topple: bool) -> void:
	_landings.append(0.0 if topple else Num.f(_tune["drop_quiet_db"]))


func _sound_landings() -> void:
	if _landings.is_empty():
		return
	_landings.sort()
	_landings.reverse()
	for db: float in _landings.slice(0, Num.i(_tune["collapse_per_frame"])):
		play("collapse", db, 0.85 if db >= 0.0 else 1.0)
	_landings.clear()


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


## A shot from `at` near `centre` (the kaiju's feet): within the sound's "crack_within" (flat
## distance) it plays as itself, a crack; further off as "<sound>_far", a soft low pop, so only
## the nearest squads crack and the rest of the city is distant fire.
func play_near(sound: String, at: Vector3, centre: Vector3) -> void:
	var withins: Dictionary = _tune.get("crack_within", {})
	var within := Num.f(withins.get(sound, INF))
	var near := Vector2(at.x - centre.x, at.z - centre.z).length() <= within
	play_at(sound if near else sound + "_far", at)


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
## Bubbles only for the first regen_seconds of each healing spell, then a fade: a cue that
## healing began, not a bed under the whole rampage (mix report, 2026-10-18).
func regen(healing: bool) -> void:
	if healing and not _healing:
		played.append("regen_loop")
		_regen_age = 0.0
		_regen.volume_db = _volume("regen_loop")
		_regen.play()
	elif not healing and _regen.playing:
		_regen.stop()
	_healing = healing


func _fade_regen(delta: float) -> void:
	if not _regen.playing:
		return
	_regen_age += delta
	if _regen_age < Num.f(_tune["regen_seconds"]):
		return
	_regen.volume_db -= REGEN_FADE_DB_PER_S * delta
	if _regen.volume_db <= SILENT_DB:
		_regen.stop()


## One sound by name, slightly re-pitched each time so repeats do not sound copied; extra_db
## and pitch shade a single play (steps and stomps also take the size-tier pitch).
## A sound with a "min_interval" in tuning is skipped while its last play is younger than that
## (stretched by up to its "interval_jitter" share each time, so the gaps are ragged), so a burst
## of events (rooftop volleys) never machine-guns, types or eats the pool's voices.
func play(sound: String, extra_db := 0.0, pitch := 1.0) -> void:
	var gaps: Dictionary = _tune.get("min_interval", {})
	if gaps.has(sound):
		var gap := Num.f(gaps[sound])
		if Num.f(_since_sound.get(sound, INF)) < gap:
			return
		var stretches: Dictionary = _tune.get("interval_jitter", {})
		var stretch := Num.f(stretches.get(sound, 0.0))
		_since_sound[sound] = -gap * stretch * _rng.randf()
	played.append(sound)
	if sound == "breath":
		_since_breath = 0.0
	var stream: AudioStream = _streams.get(sound)
	if stream == null:
		return
	var player := _pool[_next]
	_next = (_next + 1) % _pool.size()
	var jitters: Dictionary = _tune.get("pitch_jitter_by", {})
	var jitter := Num.f(jitters.get(sound, _tune["pitch_jitter"]))
	var pitches: Dictionary = _tune.get("pitch_by", {})
	pitch *= Num.f(pitches.get(sound, 1.0))
	var swings: Dictionary = _tune.get("gain_jitter_db", {})  # e.g. rifles: no two cracks alike
	var swing := Num.f(swings.get(sound, 0.0))
	player.stream = stream
	player.volume_db = _volume(sound) + extra_db + _rng.randf_range(-swing, swing)
	if sound.begins_with("footstep") or sound.begins_with("stomp"):
		pitch *= _size_pitch
	player.pitch_scale = pitch * (1.0 + _rng.randf_range(-jitter, jitter))
	var starts: Dictionary = _tune.get("start_s", {})  # skips a sample's silent lead-in
	player.play(Num.f(starts.get(sound, 0.0)))


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


## The volume (dB) of the latest play, its distance fade included (read by the flow suite).
func last_volume() -> float:
	return _pool[(_next + _pool.size() - 1) % _pool.size()].volume_db


## How many voices are sounding `sound` right now (the flow suite checks tails are kept).
func sounding(sound: String) -> int:
	var stream: AudioStream = _streams.get(sound)
	return (
		_pool
		. filter(func(p: AudioStreamPlayer) -> bool: return p.playing and p.stream == stream)
		. size()
	)


## The pitch of the latest play (the flow suite checks the size-tier pitch with it).
func last_pitch() -> float:
	return _pool[(_next + _pool.size() - 1) % _pool.size()].pitch_scale


func _volume(sound: String) -> float:
	var levels: Dictionary = _tune["volume_db"]
	var key := "stomp" if sound.begins_with("stomp_") and sound != "stomp_crack" else sound
	if sound.begins_with("footstep"):
		key = "footstep"
	return Num.f(levels.get(key, 0.0))
