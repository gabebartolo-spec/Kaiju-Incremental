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
