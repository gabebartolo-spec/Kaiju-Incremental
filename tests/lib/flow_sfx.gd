extends RefCounted
## The flow suite's sound checks that need no rampage (moved out of run_flow_tests.gd so it keeps
## room under its 400-line cap): the Master limiter, the SFX bus, stomps landing on foot plants
## and the size-tier step pitch. Sound PRs add their own checks here.

const FlowSounds := preload("res://tests/lib/flow_sounds.gd")


## A sim stomp waits for the next foot plant to sound (so the thump lands on a foot), then
## plays its tier and the ground crack instead of a footstep; steps pitch by size tier.
static func run(root: Node, check: Callable) -> void:
	var sfx := Sfx.new(Seeds.make("sfx", 0))
	root.add_child(sfx)
	sfx.stomp(2.0, true)
	var dynamics: Dictionary = Content.section("sfx")["dynamics"]
	var ceiling := INF
	for i: int in AudioServer.get_bus_effect_count(0):
		var effect := AudioServer.get_bus_effect(0, i)
		if effect is AudioEffectHardLimiter:
			ceiling = (effect as AudioEffectHardLimiter).ceiling_db
	check.call(
		is_equal_approx(ceiling, Num.f(dynamics["ceiling_db"])),
		"a hard limiter holds Master under %s dBFS (found %s)" % [dynamics["ceiling_db"], ceiling]
	)
	var early := sfx.played.duplicate()
	var buses: Array[String] = []
	for player: Node in sfx.get_children():
		buses.append((player as AudioStreamPlayer).bus)
	check.call(
		buses.all(func(b: String) -> bool: return b == "SFX"),
		"every power sound plays on the SFX bus: %s" % [buses]
	)
	sfx.footstep(0.7)
	check.call(
		early.is_empty() and sfx.played == ["stomp_2", "stomp_crack"],
		"a stomp sounds on the next foot plant, not before: %s then %s" % [early, sfx.played]
	)
	FlowSounds.crowd(check, sfx)
	preload("res://tests/lib/flow_step_sounds.gd").check_walk(check, sfx)
	var pitches: Array[float] = []
	for tier: int in [1, 4]:
		sfx.set_size_tier(tier)
		sfx._process(1.0)  # past footstep_min_interval
		sfx.footstep(1.0)
		pitches.append(sfx.last_pitch())
	check.call(
		pitches[0] > pitches[1] * 1.2,
		"a baby's steps sound higher than a Behemoth's (pitch %s)" % [pitches]
	)
	FlowSounds.regen(check, sfx)
	preload("res://tests/lib/flow_voice_sounds.gd").check_tail(check, sfx)
	sfx.free()
