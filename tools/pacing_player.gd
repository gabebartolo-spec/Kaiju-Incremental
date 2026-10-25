class_name PacingPlayer
extends RefCounted
## The scripted player of tools/pacing.gd and tools/sim_leak_probe.gd: walks to the nearest standing
## building (heading for `goal` first, when it has one), presses the signature and the ultimate
## whenever they are ready and glides half the time, until the rampage ends.

## The step the scripted player plays at (15 Hz).
const DT := 1.0 / 15.0


## Plays `sim` to its end (or, when max_steps > 0, that many steps) and returns the steps taken.
## goal: where to head first, or Vector2(INF, INF) for the nearest building from the start.
static func play(sim: RampageSim, start_goal: Vector2, max_steps: int = 0) -> int:
	var goal := start_goal
	var target := Vector2(INF, INF)
	var steps := 0
	while not sim.over and (max_steps <= 0 or steps < max_steps):
		if steps % 8 == 0:
			target = sim.nearest_standing(goal if goal.x < INF else sim.kaiju_pos)
			if target.x < INF and goal.x < INF and target.distance_to(goal) > 20.0:
				goal = Vector2(INF, INF)  # the landmark is down: on to the nearest
		var move := Vector2.ZERO
		if target.x < INF and not sim.body.stomp_reaches(target):
			move = (target - sim.kaiju_pos).normalized()
		var held := RampageSim.HELD if steps % 30 < 15 else 0
		sim.step(
			DT,
			move,
			sim.ability_ready_in <= 0.0,
			held | RampageSim.ULTIMATE | Dash.BUTTON | RampageSim.STOMP
		)
		steps += 1
	return steps
