class_name InputLatch
extends RefCounted
## Presses the sim cannot take yet, kept for its first live tick (research 20.3): while the kaiju
## rises from the river the sim ignores input, so a dash, signature or ultimate tapped just before
## control returns would be lost. The latch holds each just-pressed button for a short window
## (data/tuning.json "emerge" "input_latch_seconds") and hands what is still fresh to the first
## live tick as ordinary input, so a replay of the same presses on the same ticks is identical.
## Pure input plumbing: no clock (ages advance by the tick's own dt), no RNG.

## Seconds a press stays fresh after it was made.
var window: float
var _age: Dictionary = {}  # button name -> seconds since it was pressed


func _init(p_window: float) -> void:
	window = p_window


## One tick's presses (name -> bool): while `held_back` (the sim is not taking input) they are
## kept and returned as made; on the first live tick the fresh ones are added to that tick's own.
func through(held_back: bool, pressed: Dictionary, dt: float) -> Dictionary:
	if held_back:
		hold(pressed, dt)
		return pressed
	var out := pressed.duplicate()
	for key: String in take():
		out[key] = true
	return out


## One held-back tick: ages what is latched, then latches every button in `pressed`
## (name -> true) as fresh.
func hold(pressed: Dictionary, dt: float) -> void:
	for key: String in _age:
		_age[key] = Num.f(_age[key]) + dt
	for key: String in pressed:
		if pressed[key] == true:
			_age[key] = 0.0


## The buttons still fresh (name -> true), and forgets everything: the first live tick takes them.
func take() -> Dictionary:
	var out := {}
	for key: String in _age:
		if Num.f(_age[key]) <= window + 1.0e-6:
			out[key] = true
	_age.clear()
	return out
