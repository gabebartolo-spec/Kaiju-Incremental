extends RefCounted
## The flow suite's sound-level checks that need no scene (kept here so run_flow_tests.gd stays
## under its line cap).


## The crowd panic is silent when the street is calm, loud in a panic, and ducks under the
## breath (Sfx.crowd_target, tuning "sfx" "crowd").
static func crowd(check: Callable, sfx: Sfx) -> void:
	var calm := sfx.crowd_target(0.0, false)
	var panic := sfx.crowd_target(0.8, false)
	var ducked := sfx.crowd_target(0.8, true)
	check.call(
		calm < -50.0 and panic > calm + 20.0 and ducked < panic - 6.0,
		(
			"the crowd is silent when calm, loud in a panic, and ducks under the breath"
			+ " (%.0f, %.0f, %.0f)" % [calm, panic, ducked]
		)
	)


## The regen bubbles start on each heal, fade within seconds while healing goes on, and start
## again on the next heal (a cue, not a bed: mix report, 2026-10-18).
static func regen(check: Callable, sfx: Sfx) -> void:
	sfx.regen(true)
	var bubbling := sfx._regen.playing
	for _i: int in 4:
		sfx._process(1.0)
		sfx.regen(true)  # still healing
	var faded := not sfx._regen.playing
	sfx.regen(false)
	sfx.regen(true)
	check.call(
		bubbling and faded and sfx._regen.playing,
		"regen bubbles start each heal and fade within seconds (%s, %s)" % [bubbling, faded]
	)
	sfx.regen(false)
