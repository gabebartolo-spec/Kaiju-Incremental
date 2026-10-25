extends RefCounted
## Turning with weight (director comments #16, 2026-10-20: "pivoting from left to right is too
## slidey, our kaiju should have real weight behind them ... without feeling unresponsive"). The
## baby reptilian on open ground at 30 Hz: a 180-degree stick flip at full stride walks an arc
## instead of reversing on the spot, every step moves the body along its own heading (no sideways
## slide), and the about-face still lands on the new way within a second and a half.

const DT := 1.0 / 30.0
const NORTH := Vector2(0, -1)
const START := Vector2(-20, 10)
## The arc a full-stride about-face swings out to the side (world units; the baby is ~10 long).
const MIN_ARC := 0.75
## Sideways share of a step allowed (rounding only): 0.01 is about half a degree.
const MAX_SLIP := 0.01
## The about-face must land within this long (s): weight, not unresponsiveness.
const MAX_TURN_S := 1.5


## make(species, levels, layout, at) -> RampageSim: the powers suite's _sim.
static func check(check: Callable, make: Callable) -> void:
	var empty: Array[Dictionary] = []
	var sim: RampageSim = make.call("reptilian", {}, empty, START)
	var slip := 0.0
	for i: int in roundi(2.0 / DT):
		slip = maxf(slip, _step(sim, NORTH))
	var arc := 0.0
	var landed := INF
	for i: int in roundi(3.0 / DT):
		slip = maxf(slip, _step(sim, -NORTH))
		arc = maxf(arc, absf(sim.kaiju_pos.x - START.x))
		if landed == INF and sim.facing.dot(-NORTH) > 0.999:
			landed = (i + 1) * DT
	check.call(
		arc > MIN_ARC,
		(
			"a full-stride about-face walks an arc, not a slide back (%.2f > %.2f m out)"
			% [arc, MIN_ARC]
		)
	)
	check.call(
		slip <= MAX_SLIP,
		"every step moves along the body's heading (sideways share %.3f <= %.3f)" % [slip, MAX_SLIP]
	)
	check.call(
		landed <= MAX_TURN_S,
		"the about-face lands on the new way in %.2f s (<= %.1f s)" % [landed, MAX_TURN_S]
	)


## One step with the stick at `move`; returns the sideways share of the step against the heading.
static func _step(sim: RampageSim, move: Vector2) -> float:
	var from := sim.kaiju_pos
	sim.step(DT, move, false, RampageSim.STOMP)
	var d := sim.kaiju_pos - from
	if d.length() < 0.0001:
		return 0.0
	return absf(d.dot(sim.body.heading.orthogonal())) / d.length()
