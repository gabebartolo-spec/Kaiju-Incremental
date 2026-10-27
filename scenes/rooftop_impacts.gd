class_name RooftopImpacts
extends RefCounted
## Rooftop rounds on their way to the kaiju's hide (D-245), split out of RooftopView. Each round
## waits the frames its flight takes, then lands the same on-surface hit as a tank shell or a
## helicopter's gun (HideHit): on the real cube along its line, depth-tested, no glow, a tiny red
## blood mist, a wound the hide keeps. Presentation only.

const MAX := 48

## The worst time landing one round took, in microseconds (the capture gate reads it).
var worst_usec := 0
## Rounds on their way: {"hit": strike, "from": muzzle, "wait": frames till it lands}.
var _waiting: Array[Dictionary] = []


## A round from `from` (its muzzle) that reaches strike `hit` on the hide after `wait` frames.
func add(hit: Dictionary, from: Vector3, wait: int) -> void:
	if _waiting.size() < MAX:
		_waiting.append({"hit": hit, "from": from, "wait": wait})


## Lands each round whose wait is over on `body`'s hide; appends {"at": the point on the hide,
## "frame": frame} to `landed` for each (the capture tool measures them).
func land(fx: Fx, body: Node3D, frame: int, landed: Array[Dictionary]) -> void:
	for round_in: Dictionary in _waiting.duplicate():
		if Num.i(round_in["wait"]) > 0:  # the round has not arrived yet
			round_in["wait"] = Num.i(round_in["wait"]) - 1
			continue
		_waiting.erase(round_in)
		var struck: Dictionary = round_in["hit"]
		var aim := RooftopAim.at(struck)
		if aim == Vector3.INF or body == null:  # the bone it struck is gone (a stage change)
			continue
		var from: Vector3 = round_in["from"]
		var t0 := Time.get_ticks_usec()
		var hit := HideHit.land(fx, body, from, aim)
		worst_usec = maxi(worst_usec, Time.get_ticks_usec() - t0)
		var where: Vector3 = hit["point"]
		landed.append({"at": where, "frame": frame})
