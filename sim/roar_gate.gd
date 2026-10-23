class_name RoarGate
extends RefCounted
## When the kaiju roars on the move (D-145: "should roar more often, perhaps when he uses his
## ultimate power and/or a dash"): on every dash and every ultimate, at most once in the sfx
## roar_cooldown seconds of the run, so dash spam never stacks them. The one rule: the sim marks
## each event it roars on ("roar": true); RoarCue sounds the marked ones and a heavy body's clip
## clock plays its roar on a marked ultimate (HeavyContact). Part of BodyContact; pure.

var _at := INF  # the run clock (sim.time_left) at the last roar
var _gap := 0.0


func _init() -> void:
	_gap = Num.f(Content.section("sfx")["roar_cooldown"])


## Marks the dash and ultimate events of a step the kaiju roars on, at run clock `left`.
func mark(events: Array[Dictionary], left: float) -> void:
	for event: Dictionary in events:
		var kind := str(event["type"])
		if (kind == "dash" or kind == "ultimate") and not _at - left < _gap:
			_at = left
			event["roar"] = true
