class_name RoarCue
extends RefCounted
## The kaiju roars on every ultimate and every dash (D-145: "should roar more often, perhaps when
## he uses his ultimate power and/or a dash"): the croc's roar sound (Sfx.roar), and on an ultimate
## its roar pose too (not in a dash: the roar clip would hold a charging body still). At most one
## roar in the sfx "roar_cooldown" seconds of the run, so dash spam never stacks them. Presentation
## only: it reads the sim's events and decides nothing. Part of PowersView.

## Roars made, for the flow suite.
var roars := 0
var _at := INF  # the run clock (sim.time_left) at the last roar


## An event of the sim at run clock `left` (sim.time_left); the sound is added under `parent`,
## the pose asked of `kaiju` (a model with a roar() method).
func on_event(event: Dictionary, left: float, parent: Node, kaiju: Node3D) -> void:
	var kind := str(event["type"])
	if kind != "dash" and kind != "ultimate":
		return
	if _at - left < Num.f(Content.section("sfx")["roar_cooldown"]):
		return
	_at = left
	roars += 1
	if kind == "ultimate" and kaiju.has_method("roar"):
		kaiju.call("roar")
	var player := Sfx.roar(parent)
	player.finished.connect(player.queue_free)
