extends RefCounted
## The flow suite's voice check (kept here so run_flow_tests.gd stays under its line cap): a
## stomp keeps sounding while a burst of other sounds plays after it, instead of losing its
## tail to a voice reused too soon (tuning "sfx" "voices").

const BURST := 12  # more plays than the old 8-voice pool held


static func check_tail(check: Callable, sfx: Sfx) -> void:
	sfx.play("stomp_2")
	for i: int in BURST:
		sfx.play("shell_hit" if i % 2 == 0 else "tank_fire")
	check.call(
		sfx.sounding("stomp_2") > 0,
		(
			"a stomp keeps its tail through %d more plays (%d voices)"
			% [BURST, Num.i(Content.tuning()["sfx"]["voices"])]
		)
	)
