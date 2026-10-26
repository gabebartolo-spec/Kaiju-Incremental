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
var _ahead := 0.0


## ahead: how far the head's crown stands ahead of the hips (world units): the opening and break
## rings ring where the head comes up; the last, as it steps out, round the body.
func _init(sim: RampageSim, fx: Fx, ahead: float) -> void:
	_ahead = ahead
	_sim = sim
	_fx = fx


func _process(_delta: float) -> void:
	var emerge := _sim.emerge
	if _beat == 0 and emerge.active:
		_splash(0.6)
	elif _beat == 1 and emerge.surfaced:  # the head breaks the surface
		_splash(1.4)
	elif _beat == 2 and not emerge.active:
		_splash(1.0)


func _splash(size: float) -> void:
	_beat += 1
	var water := -Num.f(_sim.city.get("river_depth", 0.0))
	var p := _sim.kaiju_pos + (_sim.facing * _ahead if _beat < 3 else Vector2.ZERO)
	var at := Vector3(p.x, maxf(_sim.stand_y, water) + 0.02, p.y)
	# A foam ring on the water, never the street's dust puffs (they popped in at the break).
	var spray: Dictionary = Content.section("intro")["water"]
	var foam := IntroWater.foam(spray)
	_fx.ring_of(at, RING * _sim.body_scale() * size, 0.0, foam)
