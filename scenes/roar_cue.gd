class_name RoarCue
extends RefCounted
## The kaiju roars on the dashes and ultimates the sim roars on (D-145: "should roar more often,
## perhaps when he uses his ultimate power and/or a dash"; the sim's RoarGate marks them, at most
## one in the sfx "roar_cooldown" seconds of the run): the croc's roar sound (Sfx.roar), and on an
## ultimate its roar pose too (not in a dash: the roar clip would hold a charging body still).
## Presentation only: it reads the sim's events and decides nothing. Part of PowersView.

## Roars made, for the flow suite.
var roars := 0


## An event of the sim; the sound is added under `parent`, the pose asked of `kaiju` (a model with
## a roar() method).
func on_event(event: Dictionary, parent: Node, kaiju: Node3D) -> void:
	if event.get("roar", false) != true:
		return
	var kind := str(event["type"])
	roars += 1
	if kind == "ultimate" and kaiju.has_method("roar"):
		kaiju.call("roar")
	var player := Sfx.roar(parent)
	player.finished.connect(player.queue_free)
