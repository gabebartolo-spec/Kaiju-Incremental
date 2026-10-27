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
var held_button := HeldButton.new()  # the held move: hold or toggle (D-259)
var _walk := AutoWalk.new()
## Presses made while the rise from the river holds the sim back, kept for its first live tick.
var _latch := InputLatch.new(Num.f(Content.section("emerge")["input_latch_seconds"]))


## For `run` (its sim, capture hook and autoplay_signature); steps: physics steps run so far.
func read(run: Rampage, steps: int, delta: float) -> Dictionary:
	var sim := run.sim
	var scripted := run.scripted
	var signature_on := run.autoplay_signature
	# The player's stick is read from the camera's side; a capture's scripted move and autoplay's
	# walk are world vectors (below).
	var move := stick(sim.body.view.turn)
	var signature := Input.is_action_just_pressed("signature")
	var held := held_button.read(Input.is_action_pressed("signature"), signature)
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


## The player's stick as a world direction, read from the camera's side (D-330: it stands at his
## back and swings with him, `turn` radians from its rest side): up walks away from the camera.
static func stick(turn: float) -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down").rotated(turn)


## The sim's button bits (Dash.BUTTON, RampageSim.HELD, RampageSim.ULTIMATE) for read's presses.
static func buttons(now: Dictionary) -> int:
	var dash: bool = now["dash"]
	var held: bool = now["held"]
	var ultimate: bool = now["ultimate"]
	var out := Dash.BUTTON if dash else 0
	out |= RampageSim.HELD if held else 0
	return out | (RampageSim.ULTIMATE if ultimate else 0)
