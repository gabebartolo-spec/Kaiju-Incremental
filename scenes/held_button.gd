class_name HeldButton
extends RefCounted
## A held move's button (D-259 "Hold or toggle for held moves"): with Settings > ACCESSIBILITY >
## Held moves on HOLD the move lasts while the button is down; on TOGGLE one press holds it on and
## the next press lets it go, so nobody has to keep a finger down. Rampage reads the signature
## button's hold through it (the glide today; every held move reads RampageSim.HELD).

var _latched := false


## Whether the move is held this frame: `down` the button is down now, `pressed` it went down this
## frame.
func read(down: bool, pressed: bool) -> bool:
	if not PlayerSettings.hold_toggle:
		_latched = false
		return down
	if pressed:
		_latched = not _latched
	return _latched
