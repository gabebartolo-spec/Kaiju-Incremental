class_name ClipChoice
extends RefCounted
## Which clip the ClipGait plays next: roar, turn in place, walk or idle (its clock stays there).


## The clip to play now: a queued roar, a roar or turn played out, else walk, or idle with a turn
## in place when the body is off the heading.
static func pick(g: ClipGait) -> void:
	var moving := g.speed >= ClipGait.STAND_SPEED * g.hip_height * g.s
	if g._roar_queued:
		g._roar_queued = false
		g._go("roar", 0.0)
	elif g.state == "roar" or g.state.begins_with("turn"):
		if _played_out(g, moving):
			g._go("walk" if moving else "idle", g._walk_start() if moving else 0.0)
	elif moving:
		if g.state != "walk":
			g._go("walk", g._walk_start())
	else:
		_stand_or_turn(g)


## A roar plays to its last frame; a turn until he moves or it has settled past its span.
static func _played_out(g: ClipGait, moving: bool) -> bool:
	if g.state == "roar":
		return not g.clips.loops(g.state) and g.clip_time >= g.clips.frames_of(g.state) - 1
	var span: Vector2 = g._turn_span[g.state]
	return moving or g.clip_time >= span.y + ClipGait.TURN_SETTLE


## Standing: off the heading by more than ClipGait.TURN_TRIGGER, a turn in place; else idle.
static func _stand_or_turn(g: ClipGait) -> void:
	var err := wrapf(g.model_yaw - g.body_yaw, -PI, PI)
	if absf(err) > ClipGait.TURN_TRIGGER:
		var turn := "turn_left" if err > 0.0 else "turn_right"
		var span: Vector2 = g._turn_span[turn]
		g._turn_from = g.body_yaw
		g._go(turn, maxf(0.0, span.x - ClipGait.TURN_PAD))
	elif g.state != "idle":
		g._go("idle", 0.0)
