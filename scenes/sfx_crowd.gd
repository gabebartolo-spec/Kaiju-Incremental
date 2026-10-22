class_name SfxCrowd
extends RefCounted
## The city's panic loop for Sfx (moved out of sfx.gd to keep it under its line cap): faded by
## the fleeing people and the destruction rate, and pulled down while Atomic Breath roars
## (tuning "sfx" "crowd"). Presentation only.

var player: AudioStreamPlayer
## CitySound's trim in dB over the panic level (0 = none): the crowd fades as the city's people
## flee (D-155); never above the loop's own level.
var trim_db := 0.0
var _cfg: Dictionary
var _full_db: float
var _db := -80.0
var _chunks_before := 0
var _chunk_rate := 0.0


## full_db: the loop's level at full panic (tuning "sfx" "volume_db" crowd_panic).
func _init(loop: AudioStreamPlayer, cfg: Dictionary, full_db: float) -> void:
	player = loop
	_cfg = cfg
	_full_db = full_db


## The crowd's level in dB for a panic `intensity` (0..1), less "duck_db" while ducked.
func target(intensity: float, ducked: bool) -> float:
	if intensity <= Num.f(_cfg["min_intensity"]):
		return Num.f(_cfg["silent_db"])
	var level := lerpf(Num.f(_cfg["quiet_db"]), _full_db, clampf(intensity, 0.0, 1.0))
	return level - (Num.f(_cfg["duck_db"]) if ducked else 0.0)


## One frame: returns true when the loop started this frame (Sfx logs it as played).
func update(street: StreetLife, since_breath: float, delta: float) -> bool:
	var chunks := street.sim.chunks_destroyed
	var rate := float(chunks - _chunks_before) / maxf(delta, 0.001)
	_chunks_before = chunks
	_chunk_rate = lerpf(_chunk_rate, rate, minf(1.0, delta * 2.0))
	var intensity := (
		clampf(float(street.panicking()) / Num.f(_cfg["full_panic"]), 0.0, 1.0) * 0.7
		+ clampf(_chunk_rate / Num.f(_cfg["full_rate"]), 0.0, 1.0) * 0.3
	)
	var goal := target(intensity, since_breath < Num.f(_cfg["duck_seconds"]))
	goal = maxf(Num.f(_cfg["silent_db"]), goal + minf(trim_db, 0.0))
	_db = move_toward(_db, goal, Num.f(_cfg["fade_db_per_s"]) * delta)
	player.volume_db = _db
	var audible := _db > Num.f(_cfg["silent_db"]) + 1.0
	if audible and not player.playing:
		player.play()
		return true
	if not audible and player.playing:
		player.stop()
	return false
