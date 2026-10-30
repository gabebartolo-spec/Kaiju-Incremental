class_name FinalStrike
extends RefCounted
## Time's up (D-263; director 2026-10-31 "Jet run", headline AIRSTRIKE): the army's final strike.
## When the clock runs out, `jets` jets fly one low run across the screen through where he
## stands (square to his facing, so across the camera that stays behind him, D-330; which side
## they come from is seeded), `run_length` world units long in `pass_s`, at `altitude`. They drop
## `bombs` bombs spaced evenly along `bomb_span` of the run, centred on him, each landing `fall_s`
## after the lead jet passes over its point: a blow of `damage` within `radius` on the bottom
## `floors` floors (RampageSim.hit_area, the normal destruction path, so it pays biomass as any
## blow does). His death (DeathOverload's stagger, stone and shatter) starts `death_after_s` after
## the last bomb. Part of DeathOverload; pure: one derived stream, no clock.
## Events: airstrike {from, to, seconds, jets, altitude}, airstrike_bomb {x, z, radius}.

var sim: RampageSim
var cfg: Dictionary
## Seconds since the strike began.
var t := 0.0
var from := Vector2.ZERO
var to := Vector2.ZERO
## The bombs still to land: [seconds after the start, ground point].
var bombs: Array[Array] = []
## What the bombs broke (chunks), for tests.
var chunks := 0
var _end := 0.0


func _init(p_sim: RampageSim, p_cfg: Dictionary) -> void:
	sim = p_sim
	cfg = p_cfg


## The run begins now: the line, the bombs, the event.
func start(rng: RandomNumberGenerator) -> void:
	t = 0.0
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	var dir := sim.facing.orthogonal().normalized() * side
	var half := Num.f(cfg["run_length"]) * 0.5
	from = sim.kaiju_pos - dir * half
	to = sim.kaiju_pos + dir * half
	var pass_s := Num.f(cfg["pass_s"])
	var count := Num.i(cfg["bombs"])
	var span := Num.f(cfg["bomb_span"])
	bombs.clear()
	for i: int in count:
		var along := (float(i) / maxf(1.0, count - 1.0) - 0.5) * span  # from his centre
		var at := (along + half) / (2.0 * half) * pass_s + Num.f(cfg["fall_s"])
		bombs.append([at, sim.clamp_to_arena(sim.kaiju_pos + dir * along)])
	_end = Num.f(bombs[-1][0]) + Num.f(cfg["death_after_s"]) if count > 0 else pass_s
	(
		sim
		. events
		. append(
			{
				"type": "airstrike",
				"from": from,
				"to": to,
				"seconds": pass_s,
				"jets": Num.i(cfg["jets"]),
				"altitude": Num.f(cfg["altitude"]),
			}
		)
	)


## One step: the bombs that land now. True once his death should begin.
func step(dt: float) -> bool:
	t += dt
	while not bombs.is_empty() and t >= Num.f(bombs[0][0]):
		var at: Vector2 = bombs.pop_front()[1]
		_land(at)
	return t >= _end


func _land(at: Vector2) -> void:
	var radius := Num.f(cfg["radius"])
	sim.events.append({"type": "airstrike_bomb", "x": at.x, "z": at.y, "radius": radius})
	var before := sim.chunks_destroyed
	var force := func(p: Vector2, r: float) -> float:
		return RampageSim.falloff(maxf(0.0, p.distance_to(at) - r), radius)
	sim.hit_area(force, Num.f(cfg["damage"]), 0, Num.i(cfg["floors"]))
	chunks += sim.chunks_destroyed - before
