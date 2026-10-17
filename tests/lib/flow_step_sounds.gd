extends RefCounted
## The flow suite's footstep round-robin check (kept here so run_flow_tests.gd stays under its
## line cap): eight steps use every step sound, in a repeating order, never one twice in a row.


static func check_walk(check: Callable, sfx: Sfx) -> void:
	var walk: Array[String] = []
	for _i: int in 8:
		sfx._process(1.0)  # past footstep_min_interval
		sfx.footstep(0.7)
		walk.append(sfx.played[-1])
	var unique := {}
	for step: String in walk:
		unique[step] = true
	check.call(
		(
			unique.size() == Sfx.STEPS.size()
			and walk.slice(0, 4) == walk.slice(4, 8)
			and range(1, walk.size()).all(func(i: int) -> bool: return walk[i] != walk[i - 1])
		),
		(
			"a walk takes turns with %d step sounds, never one twice in a row: %s"
			% [Sfx.STEPS.size(), walk]
		)
	)
