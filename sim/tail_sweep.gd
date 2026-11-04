class_name TailSweep
extends RefCounted
## The tail sweep (D-459, director 2026-11-03: "lets remove claw from our croc, doesnt really suit
## him anyway, refocus damage around the tail"); on its own button since D-467 (director
## 2026-11-05: the automatic sweep every 2 s curled him into a ball on every walk). A press winds
## the tail up for sweep_windup, then it swings out to one side, the sides alternating,
## and hits the ground and floors beside and behind the body
## (the lash's half ring,
## D-329: within the tail's reach, all round past sweep_arc_dot, the 360 clip), up to
## sweep_top. It never touches his position or speed, so the run is never broken. Each level of
## the tail nodes hits harder (sweep_damage) and reaches further (sweep_width); a body without
## the stats never sweeps. sweep_interval is the cooldown between presses.
## Separate from the signature lash (SpeciesPowers.lash): its own counters and events. Part of
## SpeciesPowers; pure, no randomness.

var sim: RampageSim
var cfg: Dictionary
## Sweeps so far, and the chunks they broke themselves (not what falls after).
var sweeps := 0
var cut := 0
## Fine cells the sweeps carved themselves (carving on, D-094 WP7).
var carved := 0
## This step's press (RampageSim.SWEEP); held: the button kept down (a sweep every cooldown).
var pressed := false
var held := false
## Seconds until a press sweeps again; the wind-up's seconds left (< 0: not winding up).
var ready_in := 0.0
var _side := 1.0
var _wind := -1.0


## cfg: the "powers" tuning (sweep_interval, sweep_windup, sweep_top, tail_reach, sweep_arc_dot).
func _init(p_sim: RampageSim, p_cfg: Dictionary) -> void:
	sim = p_sim
	cfg = p_cfg


func step(dt: float) -> void:
	var press := pressed or held
	pressed = false
	if sim.stat("sweep_damage") <= 0.0:
		return
	ready_in = maxf(0.0, ready_in - dt)
	if _wind >= 0.0:
		_wind -= dt
		if _wind < 0.0:
			_sweep()
		return
	var busy := sim.airborne or sim.body.dash.on()  # nor a sweep through a leap
	if not press or busy or ready_in > 0.0:
		return
	# The tail draws back this long before the sweep lands (presentation's cue only).
	ready_in = Num.f(cfg["sweep_interval"])
	_wind = Num.f(cfg["sweep_windup"])
	sim.events.append({"type": "tail_auto_windup", "side": -_side})


## How far the sweep reaches from his centre now (world units).
func reach() -> float:
	var base := Num.f(cfg["tail_reach"]) + sim.stat("tail_reach") + sim.stat("sweep_width")
	return base * sim.body_scale()


func _sweep() -> void:
	var bs := sim.body_scale()
	var far := reach()
	var top := sim.stand_y + Num.f(cfg["sweep_top"]) * bs
	var centre := sim.kaiju_pos
	var ahead := sim.facing
	var arc := Num.f(cfg["sweep_arc_dot"])  # 1.0: the tail-360 clip passes the front too
	_side = -_side
	sweeps += 1
	sim.events.append({"type": "tail_auto", "side": _side, "reach": far, "top": top})
	var before := sim.chunks_destroyed
	var before_cells := sim.carving.cells_carved
	var zone := func(p: Vector2, r: float) -> float:
		var to := p - centre
		if to.length() > far + r:
			return 0.0
		return 1.0 if to.length() <= r or ahead.dot(to.normalized()) <= arc else 0.0
	var floor_lo := maxi(0, floori(sim.stand_y))
	var dmg := sim.stat("sweep_damage") * sim.powers.hit_mult()
	SimDamage.area(sim, zone, dmg, floor_lo, ceili(top), true)  # the tail throws tanks (D-437)
	sim.army_units.taskforce.swat(zone, top)  # a jetpack agent in the air is swatted (D-139)
	cut += sim.chunks_destroyed - before
	carved += sim.carving.cells_carved - before_cells
