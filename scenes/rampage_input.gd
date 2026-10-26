class_name RampageInput
extends RefCounted
## One rampage tick's input: the player's (keyboard and mouse, or pad), a capture's script or the
## autoplay; {"move", "signature", "held", "ultimate", "dash", "stomp"}. The sim ignores input
## while the kaiju rises from the river: a tap before the handover is kept (InputLatch).

## Autoplay holds the signature for GLIDE_HELD of every GLIDE_CYCLE steps.
const GLIDE_CYCLE := 90
const GLIDE_HELD := 50

var autoplay := false  # the test walker steers (Rampage.set_autoplay)
var fire := true  # and fires the signature (Rampage.autoplay_signature)
var held := HeldButton.new()  # the held move: hold or toggle (D-259)
var _walk := AutoWalk.new()
var _latch := InputLatch.new(Num.f(Content.section("emerge")["input_latch_seconds"]))


## `scripted`: a capture's hook (any key above, the rest false).
func read(sim: RampageSim, scripted: Callable, steps: int, delta: float) -> Dictionary:
	var tap := Input.is_action_just_pressed("signature")
	var out := {
		"move": Input.get_vector("move_left", "move_right", "move_up", "move_down"),
		"signature": tap,
		"held": held.read(Input.is_action_pressed("signature"), tap),
		"ultimate": Input.is_action_just_pressed("ultimate"),
		"dash": Input.is_action_just_pressed("dash"),
		"stomp": Input.is_action_pressed("stomp"),  # held, it stomps once per interval
	}
	if scripted.is_valid():
		var script: Dictionary = scripted.call(sim)
		for key: String in out:
			out[key] = script.get(key, Vector2.ZERO if key == "move" else false)
	elif autoplay:
		out["move"] = _walk.move(sim, steps)
		out["signature"] = fire and sim.ability_ready_in <= 0.0
		out["held"] = fire and steps % GLIDE_CYCLE < GLIDE_HELD
		out["ultimate"] = fire
		out["stomp"] = true  # stomps whenever the button is ready
	var taps := {}
	for key: String in ["signature", "ultimate", "dash", "stomp"]:
		taps[key] = out[key]
	out.merge(_latch.through(sim.emerge.active, taps, delta), true)
	return out
