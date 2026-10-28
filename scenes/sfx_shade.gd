class_name SfxShade
extends RefCounted
## How a single play of a sound is shaded (Sfx.play), presentation only: a sound with a
## "min_interval" in tuning is skipped while its last play is younger than that (stretched by up to
## its "interval_jitter" share each time, so the gaps are ragged); each play gets its own gain swing
## ("gain_jitter_db") and pitch ("pitch_by", "pitch_jitter", and the size tier for steps and
## stomps). Every draw comes from the presentation's own seeded stream. Tuning "sfx".

var _tune: Dictionary
var _rng: RandomNumberGenerator
var _since: Dictionary = {}  # sound -> seconds since its last play (negative: a stretched gap)
var _size_pitch := 1.0


func _init(rng: RandomNumberGenerator, tune: Dictionary) -> void:
	_rng = rng
	_tune = tune


## Time passes for every sound with a minimum interval.
func advance(delta: float) -> void:
	for sound: String in _since:
		_since[sound] = Num.f(_since[sound]) + delta


## The kaiju's size tier (RampageSim.size_tier): steps and stomps are pitched by it, so a
## baby patters and a Behemoth booms whatever model it wears.
func set_size_tier(tier: int) -> void:
	var pitches: Array = _tune["size_pitch"]
	_size_pitch = Num.f(pitches[clampi(tier - 1, 0, pitches.size() - 1)])


## Whether `sound` is still inside its minimum interval; when it is not, this play starts the next.
func too_soon(sound: String) -> bool:
	var gaps: Dictionary = _tune.get("min_interval", {})
	if not gaps.has(sound):
		return false
	var gap := Num.f(gaps[sound])
	if Num.f(_since.get(sound, INF)) < gap:
		return true
	var stretches: Dictionary = _tune.get("interval_jitter", {})
	var stretch := Num.f(stretches.get(sound, 0.0))
	_since[sound] = -gap * stretch * _rng.randf()
	return false


## A random gain (dB) for this play, e.g. rifles: no two cracks alike.
func swing(sound: String) -> float:
	var swings: Dictionary = _tune.get("gain_jitter_db", {})
	var amount := Num.f(swings.get(sound, 0.0))
	return _rng.randf_range(-amount, amount)


## `base` pitch for this play: the sound's own tuning, the size tier for steps and stomps, and a
## little random each time.
func pitched(sound: String, base: float) -> float:
	var jitters: Dictionary = _tune.get("pitch_jitter_by", {})
	var jitter := Num.f(jitters.get(sound, _tune["pitch_jitter"]))
	var pitches: Dictionary = _tune.get("pitch_by", {})
	var out := base * Num.f(pitches.get(sound, 1.0))
	if sound.begins_with("footstep") or sound.begins_with("stomp"):
		out *= _size_pitch
	return out * (1.0 + _rng.randf_range(-jitter, jitter))
