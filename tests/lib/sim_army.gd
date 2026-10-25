extends RefCounted
## The sim suite's army check, split out to keep the runner small: standing still, the army
## arrives and hurts the kaiju, and armoured scales cut what a tank shot does. The run starts at
## the river bank (D-083), out of the tanks' reach, so both kaiju wait for the first tank and then
## stand where it is: they meet the same army.

const DT := 1.0 / 30.0
const ARRIVE_STEPS := 30 * 15
const FIGHT_STEPS := 30 * 15

var _check: Callable
var _make: Callable


## check: the runner's check; make(species, levels, run_index, tuning) -> RampageSim.
func _init(p_check: Callable, make: Callable) -> void:
	_check = p_check
	_make = make


func run() -> void:
	var soft: RampageSim = _make.call("reptilian", {}, 0, {})
	var armoured: RampageSim = _make.call("reptilian", {"hide": 1, "scales": 4}, 0, {})
	for i: int in ARRIVE_STEPS:
		soft.step(DT, Vector2.ZERO, false, RampageSim.STOMP)
		armoured.step(DT, Vector2.ZERO, false, RampageSim.STOMP)
	if soft.tanks.size() > 0:
		soft.kaiju_pos = soft.tanks[0].pos
		armoured.kaiju_pos = soft.tanks[0].pos
	var soft_hit := 0.0
	var armoured_hit := 0.0
	for i: int in FIGHT_STEPS:
		soft_hit = maxf(soft_hit, _tank_hit(soft))
		armoured_hit = maxf(armoured_hit, _tank_hit(armoured))
	_check.call(
		soft.tanks.size() > 0 and soft_hit > 0.0,
		"standing still, the army arrives and hurts the kaiju (a tank shot took %.1f)" % soft_hit
	)
	_check.call(
		armoured_hit > 0.0 and armoured_hit < soft_hit,
		"armoured scales cut the damage a tank shot does (%.1f vs %.1f)" % [armoured_hit, soft_hit]
	)


## One step; the health a tank shot took off the kaiju this step (0 when none fired, or when a
## rooftop volley landed too, so the shot is not mixed with another).
func _tank_hit(sim: RampageSim) -> float:
	var before := sim.hp
	var fired := false
	var other := false
	for event: Dictionary in sim.step(DT, Vector2.ZERO, false, RampageSim.STOMP):
		fired = fired or str(event["type"]) == "tank_fired" and event.has("tank")
		other = other or str(event["type"]) == "rooftop_fired"
	return before - sim.hp if fired and not other else 0.0
