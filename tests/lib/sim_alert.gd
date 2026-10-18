extends RefCounted
## The sim suite's alert ramp checks (director playtest, D-083: "a city caught unaware"): the
## army's alert climbs from 0 over army.alert's ramp after its delay; rooftop squads wake one by
## one across the ramp, and the tank and helicopter call-ins run at the alert's pace. Includes
## the player-effect fixture "army.alert": the same seeded rampage with the ramp on and off.

const DT := 1.0 / 30.0

var _check: Callable
var _make: Callable


## check: the runner's check; make(species, levels, run_index, tuning) -> RampageSim.
func _init(p_check: Callable, make: Callable) -> void:
	_check = p_check
	_make = make


func run() -> void:
	var alert: Dictionary = Content.section("army")["alert"]
	var delay := Num.f(alert["delay"])
	var ramp := Num.f(alert["ramp_seconds"])
	var sim := _new({})
	var army := sim.army_units
	var start := army.alert()
	_steps(sim, delay - 0.1)
	var held := army.alert()
	_steps(sim, 0.1 + ramp * 0.5)
	var mid := army.alert()
	_steps(sim, ramp * 0.5 + 0.1)
	_check.call(
		start == 0.0 and held == 0.0 and mid > 0.3 and mid < 0.7 and army.alert() == 1.0,
		(
			"the alert holds at 0 for %.0f s, then climbs to 1 over %.0f s (%.1f, %.1f, %.1f, %.1f)"
			% [delay, ramp, start, held, mid, army.alert()]
		)
	)
	var wakes: Array[float] = []
	for squad: Army.Squad in _new({}).army_units.squads:
		wakes.append(squad.wake)
	_check.call(
		(
			wakes.size() >= 4
			and wakes.min() >= 0.0
			and wakes.min() < ramp * 0.25
			and wakes.max() > ramp * 0.75
			and wakes.max() <= ramp
		),
		(
			"rooftop squads take up arms one by one across the ramp (%d, first %.1f s, last %.1f s)"
			% [wakes.size(), wakes.min() if wakes else 0.0, wakes.max() if wakes else 0.0]
		)
	)
	# Player effect: the kaiju stands among the roofs from the first second, with the ramp and
	# without it (delay 0, ramp 0: the city at full alert from the start, as before).
	var off_tune := Content.tuning().duplicate(true)
	off_tune["army"]["alert"] = {"delay": 0.0, "ramp_seconds": 0.0}
	var on := _new({})
	var off := _new({}, off_tune)
	var spot := on.army_units.squads[0].pos if not on.army_units.squads.is_empty() else Vector2()
	on.kaiju_pos = spot
	off.kaiju_pos = spot
	var on_first := _count(on, 10.0, "rooftop_fired")
	var off_first := _count(off, 10.0, "rooftop_fired")
	var on_tank := _first(on, delay + ramp, "tank_spawned")
	var off_tank := _first(off, delay + ramp, "tank_spawned")
	(
		_check
		. call(
			off_first >= 4 and on_first * 4 <= off_first and on_tank > off_tank,
			(
				(
					"caught unaware: rooftop volleys in the first 10 s %d vs %d at full alert; first tank"
					+ " %.1f s vs %.1f s"
				)
				% [on_first, off_first, on_tank + 10.0, off_tank + 10.0]
			)
		)
	)


func _new(levels: Dictionary, tuning: Dictionary = {}) -> RampageSim:
	var sim: RampageSim = _make.call("reptilian", levels, 0, tuning)
	sim.hp = 1.0e9  # a standing target: nothing ends the run early
	return sim


func _steps(sim: RampageSim, seconds: float) -> void:
	for i: int in ceili(seconds / DT):
		sim.step(DT, Vector2.ZERO, false)


func _count(sim: RampageSim, seconds: float, kind: String) -> int:
	var count := 0
	for i: int in ceili(seconds / DT):
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false):
			if str(event["type"]) == kind:
				count += 1
	return count


## Seconds until the first event of `kind` (within `seconds`, else `seconds`).
func _first(sim: RampageSim, seconds: float, kind: String) -> float:
	for i: int in ceili(seconds / DT):
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false):
			if str(event["type"]) == kind:
				return i * DT
	return seconds
