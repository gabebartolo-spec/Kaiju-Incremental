class_name RiverView
extends Node
## The splash of the kaiju's rise from the river at the start of a run (D-083; the sim's
## Emergence holds the rise and the kaiju's height): a ring on the sunk water as the run opens, a
## big one as the body breaks the surface, and a last one as it steps out. Rings from the
## existing Fx, tinted like spray; presentation only.

const RING := 5.0  # ring radius per body scale

var _sim: RampageSim
var _fx: Fx
var _beat := 0  # splashes made so far


func _init(sim: RampageSim, fx: Fx) -> void:
	_sim = sim
	_fx = fx


func _process(_delta: float) -> void:
	var emerge := _sim.emerge
	if _beat == 0 and emerge.active:
		_splash(0.6, false)
	elif _beat == 1 and emerge.surfaced:  # the head breaks the surface
		_splash(1.4, true)
	elif _beat == 2 and not emerge.active:
		_splash(1.0, false)


func _splash(size: float, tail: bool) -> void:
	_beat += 1
	var water := -Num.f(_sim.city.get("river_depth", 0.0))
	var at := Vector3(_sim.kaiju_pos.x, maxf(_sim.stand_y, water) + 0.02, _sim.kaiju_pos.y)
	_fx.shockwave(at, RING * _sim.body_scale() * size, tail)
