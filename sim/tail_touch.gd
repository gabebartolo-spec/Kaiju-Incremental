class_name TailTouch
extends RefCounted
## The tail carves every building it touches in ordinary play, not only on the lash (director
## 2026-10-30: "the tail should carve whatever building it touches in general play too ... it
## doesnt work most the time and the tail just clips through"). BodyContact lays the tail rigidly
## along the heading on discs thinner than the drawn tail (its tip discs vanish under the skin) and
## only chews a building that dwarfs him, while the drawn tail is a spring chain that swings wide
## on a turn. Here the tail discs (offset at or behind tail_from) are laid along a heading that
## lags the body's at `follow` /s, widened by `pad`, swept between steps, and break every standing
## chunk they touch outright, whatever its size. Part of BodyContact; pure, no randomness.

var _sim: RampageSim
var _cfg: Dictionary
var _volume: BodyVolume
var _lay := Vector2.ZERO  # the heading the tail lies along (lags the body's)
var _last_pos := Vector2(INF, INF)
var _last_lay := Vector2.ZERO
## Chunks the tail has broken this rampage.
var broken := 0


func _init(sim: RampageSim, contact_cfg: Dictionary) -> void:
	_sim = sim
	_cfg = contact_cfg["tail"]
	_volume = BodyVolume.new(sim, contact_cfg)


## Takes the tail discs out of a stage's body discs ([offset, radius, bottom, top], scale 1).
func use_discs(discs: Array) -> void:
	var from := Num.f(_cfg["from"])
	var pad := Num.f(_cfg["pad"])
	var tail: Array = []
	for d: Array in discs:
		if Num.f(d[0]) <= from:
			tail.append([Num.f(d[0]), Num.f(d[1]) + pad, Num.f(d[2]), Num.f(d[3])])
	_volume.discs = tail
	_last_pos = Vector2(INF, INF)


func step(dt: float, heading: Vector2, lift: float) -> void:
	if _volume.discs.is_empty():
		return
	if _lay == Vector2.ZERO or _last_pos.x == INF:
		_lay = heading
	_lay = _lay.slerp(heading, 1.0 - exp(-Num.f(_cfg["follow"]) * dt)).normalized()
	var from := _sim.kaiju_pos if _last_pos.x == INF else _last_pos
	var from_lay := _lay if _last_pos.x == INF else _last_lay
	_volume.lift = lift
	var hits := _volume.touched(from, from_lay, _sim.kaiju_pos, _lay)
	for index: int in hits:
		var cells: Array[Vector3i] = []
		for c: Vector3i in hits[index]:
			cells.append(c)
		broken += _sim.damage_chunks(index, cells, INF)
	_last_pos = _sim.kaiju_pos
	_last_lay = _lay


## The tail is off the ground with the body (a leap's top, the river): it starts afresh after.
func reset() -> void:
	_last_pos = Vector2(INF, INF)
