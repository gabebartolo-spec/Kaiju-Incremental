class_name ClipChoice
extends RefCounted
## Which clip the ClipGait plays next: roar, keyed stomp, slam stop, turn in
## place, walk start, walk or idle (its clock
## stays there).


## The clip to play now: a queued roar, a roar or turn played out, else walk, or idle with a turn
## in place when the body is off the heading.
static func pick(g: ClipGait) -> void:
	var moving := g.speed >= ClipGait.STAND_SPEED * g.hip_height * g.s
	if g._roar_queued:
		g._roar_queued = false
		g._go("roar", 0.0)
	elif g.state == "roar" and _sets_off(g, moving):  # he walks out of it (ClipTakes.roar_over)
		g.takes.roar_time = g.clip_time
		_set_off(g)
	elif g.state == "walk_start":
		_walk_start(g, moving)
	elif g._stomp.holds(g.state) or g.state.begins_with("turn") or g.state == "slam_stop":
		_from_held(g, moving)
	elif moving:
		_moving(g)
	else:
		_stand_or_turn(g)


## A roar, keyed stomp, turn or slam stop that has played out: the keyed start if he stood
## (never out of a slam stop), else straight into the walk or idle.
static func _from_held(g: ClipGait, moving: bool) -> void:
	if not _played_out(g, moving):
		return
	if moving and g.state != "slam_stop":
		_set_off(g)
	else:
		g._go("walk" if moving else "idle", g._walk_start() if moving else 0.0)


## Moving: from standing the keyed start, else the walk (a walk already running stays).
static func _moving(g: ClipGait) -> void:
	if g.state == "idle":
		_set_off(g)
	elif g.state != "walk":
		g._go("walk", g._walk_start())


## Whether the sim has set him walking: its step clock has started (the rise's drift keeps it at 0).
static func _sets_off(g: ClipGait, moving: bool) -> bool:
	return moving and not g._leap.on and g.step_phase > 0.0 and g.step_phase != INF


## Moving from a standing clip: the keyed walk start, else straight into the walk.
static func _set_off(g: ClipGait) -> void:
	if g.takes.has_walk_start():
		g._go("walk_start", ClipTakes.WALK_START_FROM)
	else:
		g._go("walk", g._walk_start())


## The walk start: back to idle if he stops, into the walk loop once its share has played.
static func _walk_start(g: ClipGait, moving: bool) -> void:
	if not moving:
		g._go("idle", 0.0)
	elif g.takes.walk_started(g.clip_time):
		g._go("walk", g._walk_start())


## A roar or keyed stomp plays to its last frame; a turn until he moves or it has settled past its
## span.
static func _played_out(g: ClipGait, moving: bool) -> bool:
	if not g.state.begins_with("turn"):
		return _ended(g)
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
	elif g._stomp.leaves(g.state, _ended(g)):  # a landed keyed stomp plays out its tail
		g._go("idle", 0.0)


## The clip has reached its last frame (never, for a loop).
static func _ended(g: ClipGait) -> bool:
	return not g.clips.loops(g.state) and g.clip_time >= g.clips.frames_of(g.state) - 1
