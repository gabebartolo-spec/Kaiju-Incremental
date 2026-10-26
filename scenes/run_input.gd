class_name RunInput
extends RefCounted
## One physics frame's input for Rampage (moved out of it, unchanged): the player's actions, or a
## capture's scripted input, or autoplay's walk; then the InputLatch, which keeps a tap made while
## the rise from the river holds the sim back for its first live tick. Returns {"move",
## "signature", "held", "ultimate", "dash"}.

## Autoplay holds the signature for AUTOPLAY_GLIDE_HELD of every AUTOPLAY_GLIDE_CYCLE steps.
const AUTOPLAY_GLIDE_CYCLE := 90
const AUTOPLAY_GLIDE_HELD := 50

var autoplay := false
var _walk := AutoWalk.new()
var _held := HeldButton.new()  # the held move: hold or toggle (D-259)
## Presses made while the rise from the river holds the sim back, kept for its first live tick.
var _latch := InputLatch.new(Num.f(Content.section("emerge")["input_latch_seconds"]))


## For `run` (its sim, capture hook and autoplay_signature); steps: physics steps run so far.
func read(run: Rampage, steps: int, delta: float) -> Dictionary:
	var sim := run.sim
	var scripted := run.scripted
	var signature_on := run.autoplay_signature
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var signature := Input.is_action_just_pressed("signature")
	var held := _held.read(Input.is_action_pressed("signature"), signature)
	var ultimate := Input.is_action_just_pressed("ultimate")
	var dash := Input.is_action_just_pressed("dash")
	if scripted.is_valid():  # captures: {"move", "signature", "held", "ultimate", "dash"}
		var input: Dictionary = scripted.call(sim)
		dash = input.get("dash", false)
		move = input.get("move", Vector2.ZERO)
		signature = input.get("signature", false)
		held = input.get("held", false)
		ultimate = input.get("ultimate", false)
	elif autoplay:
		move = _walk.move(sim, steps)
		signature = signature_on and sim.ability_ready_in <= 0.0
		held = signature_on and steps % AUTOPLAY_GLIDE_CYCLE < AUTOPLAY_GLIDE_HELD
		ultimate = signature_on
	# The sim ignores input while it rises from the river: a tap before the handover is kept.
	var now := {"signature": signature, "ultimate": ultimate, "dash": dash}
	now = _latch.through(sim.emerge.active, now, delta)
	now["move"] = move
	now["held"] = held
	return now


## The sim's button bits (Dash.BUTTON, RampageSim.HELD, RampageSim.ULTIMATE) for read's presses.
static func buttons(now: Dictionary) -> int:
	var dash: bool = now["dash"]
	var held: bool = now["held"]
	var ultimate: bool = now["ultimate"]
	var out := Dash.BUTTON if dash else 0
	out |= RampageSim.HELD if held else 0
	return out | (RampageSim.ULTIMATE if ultimate else 0)
