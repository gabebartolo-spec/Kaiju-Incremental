extends RefCounted
## The flow suite's sound checks that need no rampage (moved out of run_flow_tests.gd so it keeps
## room under its 400-line cap): the Master limiter, the mixer buses, stomps landing on foot plants
## and the size-tier step pitch. Sound PRs add their own checks here.

const FlowSounds := preload("res://tests/lib/flow_sounds.gd")


## A sim stomp waits for the next foot plant to sound (so the thump lands on a foot), then
## plays its tier and the ground crack instead of a footstep; steps pitch by size tier.
static func run(root: Node, check: Callable) -> void:
	var sfx := Sfx.new(Seeds.make("sfx", 0))
	root.add_child(sfx)
	sfx.live = true  # past the start gate (gate() checks the gate itself)
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
		if player is AudioStreamPlayer:  # not the start gate (SfxGate)
			buses.append((player as AudioStreamPlayer).bus)
	check.call(
		buses.all(func(b: String) -> bool: return AudioServer.get_bus_index(b) >= 0),
		"every power sound's player sits on a bus the mixer has: %s" % [buses]
	)
	preload("res://tests/lib/flow_buses.gd").run(root, check)
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


## Nothing plays while the rampage loads (director's playtest: "gunfire audio kicks in while the
## visuals are still loading"): a fresh Sfx drops sounds until tuning "sfx" "start_gate"
## smooth_frames smooth frames have passed, then plays them.
static func gate(root: Node, check: Callable) -> void:
	var sfx := Sfx.new(Seeds.make("sfx", 0))
	root.add_child(sfx)
	sfx.play("rifle")
	sfx.play("tank_fire")
	var early := sfx.played.duplicate()
	var gate: Dictionary = Content.section("sfx")["start_gate"]
	for _i: int in Num.i(gate["smooth_frames"]) + 2:
		await root.get_tree().process_frame
	sfx.play("rifle")
	check.call(
		early.is_empty() and sfx.live and sfx.played == ["rifle"],
		"no rampage sound plays while it loads, then they do: %s then %s" % [early, sfx.played]
	)
	sfx.queue_free()


## A PC that never holds smooth frames (under 20 fps, e.g. a weak GPU at 4K) still hears the
## rampage: the gate opens anyway after tuning "sfx" "start_gate" max_wait_s.
static func gate_timeout(root: Node, check: Callable) -> void:
	var sfx := Sfx.new(Seeds.make("sfx", 0))
	root.add_child(sfx)
	var gate: SfxGate = null
	for child: Node in sfx.get_children():
		if child is SfxGate:
			gate = child as SfxGate
	gate.set_process(false)  # stepped by hand with slow frames
	var steps := 0
	while not sfx.live and steps < 100:
		gate._process(0.1)  # 10 fps: never a smooth frame
		steps += 1
	check.call(
		sfx.live and steps <= 40,
		"slow frames (10 fps) still open the sound gate within seconds: %.1f s" % (steps * 0.1)
	)
	sfx.queue_free()
